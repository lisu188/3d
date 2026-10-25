extends Node2D

const Orbits = preload("res://scripts/orbital_data.gd")
const Projection = preload("res://scripts/leo_projection.gd")
const STAR_SHADER = preload("res://shaders/stars.gdshader")
const EARTH_SHADER = preload("res://shaders/earth.gdshader")
const ATMOSPHERE_SHADER = preload("res://shaders/atmosphere.gdshader")
const MOON_SHADER = preload("res://shaders/moon.gdshader")
const DURATION_SECONDS: float = 80.0
const EARTH_SCENE_RADIUS: float = Projection.EARTH_RADIUS_KM / 1000.0
const EARTH_CAMERA_DISTANCE: float = (Projection.EARTH_RADIUS_KM + Projection.CAMERA_ALTITUDE_KM) / 1000.0
const RENDER_MAGNIFICATION: float = 8.0
const BLACK_HOLE_SHADOW_MAGNIFICATION: float = 18000.0
const BLACK_HOLE_LENS_MAGNIFICATION: float = 5.0

var orbits = Orbits.new()
var state: PackedFloat64Array
var current_frame: Dictionary = {}
var projections: Dictionary = {}
var playhead: float = 0.0
var playing: bool = true
var dragging: bool = false
var capturing: bool = false
var font: Font
var stars: ColorRect
var sky_material: ShaderMaterial
var planet_viewport: SubViewport
var planet_image: TextureRect
var planet: MeshInstance3D
var atmosphere: MeshInstance3D
var earth_material: ShaderMaterial
var atmosphere_material: ShaderMaterial
var moon: Sprite2D
var moon_material: ShaderMaterial
var show_help: bool = true

func _ready() -> void:
	font = ThemeDB.fallback_font
	if not orbits.load_data():
		push_error(orbits.last_error)
		get_tree().quit(4)
		return
	var dimensions: Vector2 = get_viewport_rect().size
	_setup_space_scene(dimensions)
	get_viewport().size_changed.connect(_resize)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			playhead = clampf(float(argument.trim_prefix("--at=")), 0.0, DURATION_SECONDS)
			playing = false
		elif argument.begins_with("--capture-dir="):
			capturing = true
			playing = false
	_refresh()
	queue_redraw()
	if capturing:
		call_deferred("_capture")

func _setup_space_scene(dimensions: Vector2) -> void:
	stars = ColorRect.new()
	stars.name = "StarfieldAndGravitationalLensing"
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.show_behind_parent = true
	stars.size = dimensions
	sky_material = ShaderMaterial.new()
	sky_material.shader = STAR_SHADER
	stars.material = sky_material
	add_child(stars)
	planet_viewport = SubViewport.new()
	planet_viewport.name = "EarthPhysicalCamera3D"
	planet_viewport.size = Vector2i(dimensions)
	planet_viewport.transparent_bg = true
	planet_viewport.own_world_3d = true
	planet_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(planet_viewport)
	var world: Node3D = Node3D.new()
	planet_viewport.add_child(world)
	var camera: Camera3D = Camera3D.new()
	camera.name = "Observer420km"
	camera.near = 0.015
	camera.far = 80.0
	camera.fov = Projection.CAMERA_FOV_DEG
	camera.current = true
	world.add_child(camera)
	planet = MeshInstance3D.new()
	planet.name = "NASA_BlueMarble_Earth"
	var earth_mesh: SphereMesh = SphereMesh.new()
	earth_mesh.radius = EARTH_SCENE_RADIUS
	earth_mesh.height = 2.0 * EARTH_SCENE_RADIUS
	earth_mesh.radial_segments = 160
	earth_mesh.rings = 100
	planet.mesh = earth_mesh
	earth_material = ShaderMaterial.new()
	earth_material.shader = EARTH_SHADER
	earth_material.set_shader_parameter("day_map", load("res://assets/earth-day-2048.jpg"))
	earth_material.set_shader_parameter("night_map", load("res://assets/earth-night-2048.jpg"))
	earth_material.set_shader_parameter("clouds_map", load("res://assets/earth-clouds-2048.jpg"))
	planet.material_override = earth_material
	world.add_child(planet)
	atmosphere = MeshInstance3D.new()
	atmosphere.name = "AtmosphericLimb"
	var atmospheric_mesh: SphereMesh = SphereMesh.new()
	atmospheric_mesh.radius = EARTH_SCENE_RADIUS + 0.045
	atmospheric_mesh.height = 2.0 * (EARTH_SCENE_RADIUS + 0.045)
	atmospheric_mesh.radial_segments = 160
	atmospheric_mesh.rings = 100
	atmosphere.mesh = atmospheric_mesh
	atmosphere_material = ShaderMaterial.new()
	atmosphere_material.shader = ATMOSPHERE_SHADER
	atmosphere.material_override = atmosphere_material
	world.add_child(atmosphere)
	var radial_y: float = cos(Projection.CAMERA_TILT_RAD)
	var forward_z: float = sin(Projection.CAMERA_TILT_RAD)
	planet.position = Vector3(0.0, -EARTH_CAMERA_DISTANCE * radial_y, -EARTH_CAMERA_DISTANCE * forward_z)
	atmosphere.position = planet.position
	planet_image = TextureRect.new()
	planet_image.name = "EarthOverDeepSpace"
	planet_image.texture = planet_viewport.get_texture()
	planet_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	planet_image.stretch_mode = TextureRect.STRETCH_SCALE
	planet_image.size = dimensions
	planet_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet_image.show_behind_parent = true
	add_child(planet_image)
	moon = Sprite2D.new()
	moon.name = "MoonFromNbodyVectors"
	moon.texture = load("res://assets/moon-disk.png")
	moon.centered = true
	moon.show_behind_parent = true
	moon_material = ShaderMaterial.new()
	moon_material.shader = MOON_SHADER
	moon.material = moon_material
	add_child(moon)

func _resize() -> void:
	var dimensions: Vector2 = get_viewport_rect().size
	stars.size = dimensions
	planet_viewport.size = Vector2i(dimensions)
	planet_image.size = dimensions
	_refresh()
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or capturing or orbits.rows.is_empty():
		return
	playhead = minf(playhead + delta, DURATION_SECONDS)
	if playhead >= DURATION_SECONDS:
		playing = false
	_refresh()
	queue_redraw()

func _refresh() -> void:
	if orbits.rows.is_empty() or sky_material == null:
		return
	var dimensions: Vector2 = get_viewport_rect().size
	var day: float = playhead * orbits.duration_days / DURATION_SECONDS
	state = orbits.sample_at_day(day)
	current_frame = Projection.orientation(state)
	projections.clear()
	for index in [0, 2, 3]:
		projections[index] = Projection.project(state, current_frame, index, dimensions)
	var bh: Dictionary = projections[3]
	var screen_focal: float = 0.5 / tan(deg_to_rad(Projection.CAMERA_FOV_DEG) * 0.5)
	var bh_distance_km: float = bh["distance_km"]
	var shadow_radius_rad: float = deg_to_rad(bh["angular_radius_deg"])
	var r_einstein: float = sqrt(4.0 * Projection.SOLAR_GM * 10.0 / (Projection.LIGHT_SPEED_M_S * Projection.LIGHT_SPEED_M_S * bh_distance_km * 1000.0))
	var hole_uv: Vector2 = bh["uv"] if bh["front"] and not bh["occluded"] else Vector2(-8.0, -8.0)
	sky_material.set_shader_parameter("black_hole_uv", hole_uv)
	sky_material.set_shader_parameter("aspect", dimensions.x / dimensions.y)
	sky_material.set_shader_parameter("black_hole_shadow_radius", minf(0.16, tan(shadow_radius_rad) * screen_focal * BLACK_HOLE_SHADOW_MAGNIFICATION))
	sky_material.set_shader_parameter("black_hole_lens_radius", minf(0.19, r_einstein * screen_focal * BLACK_HOLE_LENS_MAGNIFICATION))
	sky_material.set_shader_parameter("sky_rotation", atan2(current_frame["forward"].y, current_frame["forward"].x))
	var sun_local: Vector3 = Projection.sun_direction_local(state, current_frame)
	earth_material.set_shader_parameter("sun_direction", sun_local)
	earth_material.set_shader_parameter("elapsed_days", day)
	atmosphere_material.set_shader_parameter("sun_direction", sun_local)
	planet.rotation.y = fposmod(day * 86400.0 / 86164.0905, 1.0) * TAU
	moon.visible = projections[2]["on_screen"]
	if moon.visible:
		var moon_view: Dictionary = projections[2]
		moon.position = moon_view["position"]
		var diameter: float = minf(96.0, 2.0 * dimensions.y * screen_focal * tan(deg_to_rad(moon_view["angular_radius_deg"])) * RENDER_MAGNIFICATION)
		moon.scale = Vector2.ONE * maxf(diameter, 4.0) / 512.0
		var moon_to_sun: Vector3 = (Projection.body_relative_earth(state, 0) - Projection.body_relative_earth(state, 2)).normalized()
		var local_lighting: Vector3 = Vector3(moon_to_sun.dot(current_frame["right"]), -moon_to_sun.dot(current_frame["up"]), -moon_to_sun.dot(current_frame["forward"]))
		moon_material.set_shader_parameter("sunlight", local_lighting)

func _draw() -> void:
	if state.is_empty():
		return
	var dimensions: Vector2 = get_viewport_rect().size
	_draw_sun()
	_draw_header(dimensions)
	_draw_sky_compass(dimensions)
	_draw_bottom(dimensions)

func _draw_sun() -> void:
	var sun: Dictionary = projections[0]
	if not sun["on_screen"]:
		return
	var center: Vector2 = sun["position"]
	var focal: float = 0.5 / tan(deg_to_rad(Projection.CAMERA_FOV_DEG) * 0.5)
	var visual_radius: float = maxf(4.0, minf(44.0, get_viewport_rect().size.y * focal * tan(deg_to_rad(sun["angular_radius_deg"])) * RENDER_MAGNIFICATION))
	for layer in range(10, 0, -1):
		var spread: float = visual_radius * (1.0 + float(layer) * 0.60)
		draw_circle(center, spread, Color(1.0, 0.53, 0.13, 0.012 + 0.006 * float(10 - layer)))
	for ray in range(20):
		var angle: float = TAU * float(ray) / 20.0
		var direction: Vector2 = Vector2.from_angle(angle)
		draw_line(center + direction * visual_radius * 1.10, center + direction * visual_radius * (1.9 + float(ray % 5) * 0.31), Color(1.0, 0.70, 0.31, 0.52), 1.4)
	draw_circle(center, visual_radius * 1.2, Color(1.0, 0.72, 0.41, 0.35))
	draw_circle(center, visual_radius, Color(1.0, 0.91, 0.68))
	draw_circle(center, visual_radius * 0.70, Color(1.0, 1.0, 0.95))

func _text(content: String, at: Vector2, size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _draw_header(dimensions: Vector2) -> void:
	var left_panel: Rect2 = Rect2(30.0, 28.0, 380.0, 407.0)
	draw_rect(left_panel, Color(0.006, 0.012, 0.028, 0.89))
	draw_rect(Rect2(30, 28, 3.0, 407.0), Color(0.27, 0.77, 1.0))
	_text("CZARNA DZIURA", Vector2(52, 76), 30)
	_text("NAD ZIEMIĄ", Vector2(52, 117), 32, Color(0.58, 0.83, 1.0))
	_text("4 CIAŁA · 10 M☉ · V∞ 200 KM/S", Vector2(53, 147), 15, Color(0.72, 0.80, 0.91))
	draw_line(Vector2(53, 169), Vector2(391, 169), Color(0.20, 0.35, 0.47), 1.0)
	_text("CZARNA DZIURA OD ZIEMI", Vector2(54, 193), 14, Color(0.62, 0.77, 0.90))
	_text("%.3f mln km" % (projections[3]["distance_km"] / 1.0e6), Vector2(53, 224), 25)
	_text("ODLEGŁOŚĆ KSIĘŻYCA", Vector2(54, 250), 14, Color(0.62, 0.77, 0.90))
	_text("%.0f tys. km" % (projections[2]["distance_km"] / 1000.0), Vector2(53, 279), 24)
	_text("ODLEGŁOŚĆ SŁOŃCA", Vector2(54, 305), 14, Color(0.62, 0.77, 0.90))
	_text("%.4f AU" % (projections[0]["distance_km"] / Projection.AU_KM), Vector2(53, 334), 24)
	_text("PRZYSPIESZENIE PŁYWOWE Δg", Vector2(54, 360), 14, Color(0.62, 0.77, 0.90))
	_text("%.3e × g" % orbits.earth_tide_g(state), Vector2(53, 390), 22, Color(1.0, 0.77, 0.57))
	_text("CZAS: %.3f / 15.000 DNI", Vector2(53, 419), 14, Color(0.67, 0.83, 0.99))
	var right_x: float = dimensions.x - 276.0
	draw_rect(Rect2(right_x, 26, 250, 99), Color(0.006, 0.012, 0.028, 0.87))
	_text("GODOT 4 · N-BODY", Vector2(right_x + 14, 55), 18)
	_text("KAMERA LEO · 420 km", Vector2(right_x + 14, 79), 15, Color(0.58, 0.83, 1.0))
	_text("ŚRODEK NA CZARNEJ DZIURZE", Vector2(right_x + 14, 101), 12, Color(0.77, 0.83, 0.93))

func _draw_sky_compass(dimensions: Vector2) -> void:
	var x: float = dimensions.x - 324.0
	var y: float = 145.0
	draw_rect(Rect2(x, y, 296, 115), Color(0.008, 0.018, 0.034, 0.79))
	_text("POŁOŻENIE NA NIEBIE 360°", Vector2(x + 12, y + 22), 14, Color(0.78, 0.87, 1.0))
	draw_line(Vector2(x + 12, y + 53), Vector2(x + 284, y + 53), Color(0.35, 0.46, 0.63, 0.74), 1.0)
	var names: Array[String] = ["SŁOŃCE", "KSIĘŻYC", "BH"]
	var colors: Array[Color] = [Color(1.0, 0.78, 0.39), Color(0.78, 0.83, 0.96), Color(0.39, 0.71, 1.0)]
	for j in range(3):
		var body: int = [0, 2, 3][j]
		var place: Dictionary = projections[body]
		var camera_vector: Vector3 = place["local"]
		var bearing: float = rad_to_deg(atan2(camera_vector.x, camera_vector.z))
		var marker_x: float = x + 12.0 + (bearing + 180.0) / 360.0 * 272.0
		draw_circle(Vector2(marker_x, y + 53), 4.0, colors[j])
		var status: String = "W KADRZE" if place["on_screen"] else ("ZA ZIEMIĄ" if place["occluded"] else "POZA KADREM")
		_text("%s: %.1f° · %s" % [names[j], place["off_axis_deg"], status], Vector2(x + 12.0, y + 73.0 + j * 15.0), 12, colors[j])

func _draw_bottom(dimensions: Vector2) -> void:
	var width: float = dimensions.x
	var height: float = dimensions.y
	draw_rect(Rect2(30, height - 139, width - 60, 62), Color(0.005, 0.012, 0.025, 0.87))
	_text("WIDOK Z LEO · POZYCJE CIAŁ Z INTEGRACJI DOP853", Vector2(49, height - 112), 17, Color(0.74, 0.88, 1.0))
	var caption: String = "Słońce i Księżyc mogą być poza kadrem lub za Ziemią: to wynik geometrii."
	if orbits.lunar_specific_energy(state) >= 0:
		caption = "Księżyc: dodatnia chwilowa energia względem Ziemi; nie dowodzi trwałej ucieczki."
	_text(caption, Vector2(49, height - 90), 13, Color(0.73, 0.82, 0.91))
	draw_rect(Rect2(30, height - 66, width - 60, 63), Color(0.006, 0.012, 0.028, 0.89))
	var timeline_y: float = height - 31.0
	draw_rect(Rect2(50, timeline_y, width - 100, 5.0), Color(0.23, 0.30, 0.40))
	draw_rect(Rect2(50, timeline_y, (width - 100) * playhead / DURATION_SECONDS, 5.0), Color(0.31, 0.76, 1.0))
	draw_circle(Vector2(50.0 + (width - 100) * playhead / DURATION_SECONDS, timeline_y + 2.5), 8.0, Color(0.95, 0.97, 1.0))
	_text("%02d:%02d / 01:20" % [int(playhead / 60.0), int(playhead) % 60], Vector2(51, height - 46), 14)
	_text("SPACJA PAUZA  ·  ← → CZAS  ·  1–5 ETAPY  ·  R RESET", Vector2(width - 603, height - 46), 13, Color(0.73, 0.84, 0.94))
	_text("Powiększenie optyczne: Słońce i Księżyc ×8, cień BH ×18000, soczewka ×5 · ilustracyjne", Vector2(48, height - 151), 12, Color(0.68, 0.74, 0.84))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				playing = not playing
			KEY_R:
				playhead = 0.0
				playing = true
			KEY_LEFT:
				playhead = maxf(0.0, playhead - 3.0)
			KEY_RIGHT:
				playhead = minf(DURATION_SECONDS, playhead + 3.0)
			KEY_HOME:
				playhead = 0.0
			KEY_END:
				playhead = DURATION_SECONDS
				playing = false
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				playhead = [0.025, 0.225, 0.488, 0.725, 0.95][event.keycode - KEY_1] * DURATION_SECONDS
				playing = false
		_refresh()
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y > get_viewport_rect().size.y - 68.0:
			dragging = true
			playing = false
			_seek(event.position.x)
		elif not event.pressed:
			dragging = false
	if event is InputEventMouseMotion and dragging:
		_seek(event.position.x)

func _seek(mouse_x: float) -> void:
	var width: float = get_viewport_rect().size.x
	playhead = clampf((mouse_x - 50.0) / (width - 100.0), 0.0, 1.0) * DURATION_SECONDS
	_refresh()
	queue_redraw()

func _capture() -> void:
	var folder: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=")
	if folder.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var captures: Array = [[2.0, "01_departure.png"], [18.0, "02_initial_deflection.png"], [39.0, "03_encounter.png"], [58.0, "04_sun_entry.png"], [74.0, "05_late_orbit.png"]]
	for record in captures:
		playhead = float(record[0])
		_refresh()
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output_file: String = folder.path_join(str(record[1]))
		var result: int = get_viewport().get_texture().get_image().save_png(output_file)
		if result != OK:
			push_error("Could not capture %s (error %d)" % [output_file, result])
			get_tree().quit(5)
			return
		print("CAPTURED " + output_file)
	get_tree().quit(0)
