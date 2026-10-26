extends Node3D

const OrbitData = preload("res://scripts/orbital_data.gd")
const EARTH_RADIUS_KM := 6371.0084
const CAMERA_ALTITUDE_KM := 400.0
const ORBIT_INCLINATION := deg_to_rad(51.6)
const ORBIT_PERIOD_SECONDS := 5554.0
const CAMERA_FOV_DEGREES := 78.0
const BODY_NAMES := ["Sun", "Earth", "Moon", "BlackHole"]
const RADIUS_KM := [695700.0, EARTH_RADIUS_KM, 1737.4, 29.53]
const BODY_COLORS := [Color(1.0, 0.78, 0.39), Color(0.12, 0.34, 0.8), Color(0.68, 0.73, 0.76), Color(0.01, 0.01, 0.015)]

@export var duration_seconds := 80.0
@export var visual_exaggeration := 1.0
@export var earth_exposure := 1.0
@export var playback_speed := 1.0

var data := OrbitData.new()
var camera: Camera3D
var earth: MeshInstance3D
var sun: MeshInstance3D
var moon: MeshInstance3D
var hole: MeshInstance3D
var view_label: Label
var timeline: HSlider
var elapsed := 0.0
var paused := false
var screenshot_mode := false
var screenshot_frames := [2.0, 18.0, 39.0, 58.0, 74.0]
var render_nodes: Array[MeshInstance3D] = []
var stars: MultiMeshInstance3D
var last_basis := Basis.IDENTITY

func _ready() -> void:
	if not data.load_data():
		push_error(data.last_error)
		get_tree().quit(1)
		return
	_create_environment()
	_create_earth()
	_create_bodies()
	_create_stars()
	_create_hud()
	if OS.has_feature("movie"):
		get_window().size = Vector2i(1280, 720)
	_apply_time()

func _create_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.002, 0.004, 0.013)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.12, 0.16, 0.24)
	settings.ambient_light_energy = 0.14
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV_DEGREES
	camera.near = 0.01
	camera.far = 1000000.0
	camera.current = true
	add_child(camera)
	var light := DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.96, 0.87)
	light.light_energy = 1.35
	add_child(light)
	light.name = "Sunlight"

func _sphere(name: String, radius: float, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.metallic = 0.0
	material.roughness = 0.98
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	add_child(instance)
	return instance

func _create_earth() -> void:
	earth = _sphere("Earth", 6.3710084, Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/planet_3d.gdshader")
	earth.material_override = material
	var atmosphere := _sphere("Atmosphere", 6.44, Color(0.18, 0.44, 1.0, 0.07), true)
	atmosphere.material_override = null
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.40, 1.0, 0.14)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	atmosphere.material_override = mat

func _create_bodies() -> void:
	sun = _sphere("Sun", 1.0, BODY_COLORS[0], true)
	moon = _sphere("Moon", 1.0, BODY_COLORS[2])
	hole = _sphere("BlackHole", 1.0, BODY_COLORS[3], true)
	var ring := MeshInstance3D.new()
	ring.name = "PhotonRingArtistic"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.10
	ring.mesh = torus
	var glowing := StandardMaterial3D.new()
	glowing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glowing.albedo_color = Color(0.22, 0.56, 1.0)
	glowing.emission_enabled = true
	glowing.emission = Color(0.20, 0.42, 0.9)
	torus.material = glowing
	hole.add_child(ring)
	ring.rotation.x = PI * 0.5
	render_nodes = [sun, moon, hole]

func _create_stars() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 18102026
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1700
	var pixel := SphereMesh.new()
	pixel.radius = 0.04
	pixel.height = 0.08
	pixel.radial_segments = 5
	pixel.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.89, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pixel.material = mat
	mm.mesh = pixel
	for index in range(mm.instance_count):
		var phi := random.randf_range(0.0, TAU)
		var z := random.randf_range(-1.0, 1.0)
		var r := sqrt(1.0 - z * z)
		var direction := Vector3(r * cos(phi), z, r * sin(phi))
		mm.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * random.randf_range(0.5, 1.7)), direction * 1000.0))
	stars = MultiMeshInstance3D.new()
	stars.multimesh = mm
	add_child(stars)

func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	panel.custom_minimum_size = Vector2(400, 0)
	canvas.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	view_label = Label.new()
	view_label.add_theme_font_size_override("font_size", 21)
	vbox.add_child(view_label)
	var controls := Label.new()
	controls.text = "SPACE pause | arrows seek | 1-5 stages | R restart"
	vbox.add_child(controls)
	timeline = HSlider.new()
	timeline.min_value = 0.0
	timeline.max_value = duration_seconds
	timeline.step = 0.01
	timeline.position = Vector2(35.0, 678.0)
	timeline.size = Vector2(1210.0, 24.0)
	timeline.value_changed.connect(func(value: float) -> void:
		if abs(value - elapsed) > 0.05:
			elapsed = value
			_apply_time()
	)
	canvas.add_child(timeline)

func _position(row: PackedFloat64Array, index: int) -> Vector3:
	var o := 1 + 6 * index
	return Vector3(row[o], row[o + 1], row[o + 2])

func _orbit_vector(physical_seconds: float) -> Vector3:
	var angle := TAU * physical_seconds / ORBIT_PERIOD_SECONDS
	return Vector3(cos(angle), sin(angle) * sin(ORBIT_INCLINATION), sin(angle) * cos(ORBIT_INCLINATION))

func _relative_direction(row: PackedFloat64Array, index: int) -> Vector3:
	var vector := _position(row, index) - _position(row, 1)
	return vector.normalized()

func _apply_time() -> void:
	var day := data.duration_days * (elapsed / duration_seconds)
	var row := data.sample_at_day(day)
	if row.size() != 25:
		return
	var orbit_offset := _orbit_vector(day * 86400.0)
	var camera_position := orbit_offset * (6.3710084 + 0.4)
	camera.position = camera_position
	var outward := orbit_offset.normalized()
	var bore := (Vector3.UP - outward * outward.dot(Vector3.UP)).normalized()
	if bore.length() < 0.1:
		bore = Vector3.RIGHT
	var tangent := bore.cross(outward).normalized()
	var look_direction := (outward * 0.24 + tangent * 0.97).normalized()
	camera.look_at(camera_position + look_direction, outward)
	var sun_vector := _relative_direction(row, 0)
	var km_per_au := OrbitData.AU_M * 0.001
	var names := [0, 2, 3]
	for k in range(3):
		var index: int = names[k]
		var direction := _relative_direction(row, index)
		var distance_km := data.separation_au(row, 1, index) * km_per_au
		var angular_radius := atan(RADIUS_KM[index] / max(distance_km, 1.0))
		var node := render_nodes[k]
		node.global_position = camera.global_position + direction * 500.0
		var displayed_radius := 500.0 * tan(angular_radius) * visual_exaggeration
		if index == 3:
			displayed_radius = max(displayed_radius, 0.13)
		elif index == 2:
			displayed_radius = max(displayed_radius, 0.12)
		node.scale = Vector3.ONE * displayed_radius
		if index == 3:
			node.look_at(camera.global_position, Vector3.UP)
	var sun_light := get_node("Sunlight") as DirectionalLight3D
	sun_light.look_at(sun_light.global_position - sun_vector, Vector3.UP)
	var earth_material := earth.material_override as ShaderMaterial
	earth_material.set_shader_parameter("sun_direction", sun_vector)
	earth_material.set_shader_parameter("rotation_angle", day * TAU)
	view_label.text = "LEO 400 km | day %.3f / %.1f\nBlack hole: %.0f km from Earth\nMoon: %.0f km | Sun: %.0f km\nTidal differential: %.4g g" % [day, data.duration_days, data.separation_km(row, 1, 3), data.separation_km(row, 1, 2), data.separation_km(row, 1, 0), data.earth_tide_g(row)]
	if timeline != null:
		timeline.set_value_no_signal(elapsed)

func _process(delta: float) -> void:
	if not paused:
		elapsed = fmod(elapsed + delta * playback_speed, duration_seconds)
		_apply_time()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			paused = not paused
		KEY_LEFT:
			elapsed = max(0.0, elapsed - 2.0)
			_apply_time()
		KEY_RIGHT:
			elapsed = min(duration_seconds, elapsed + 2.0)
			_apply_time()
		KEY_R:
			elapsed = 0.0
			_apply_time()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			elapsed = screenshot_frames[event.keycode - KEY_1]
			_apply_time()
