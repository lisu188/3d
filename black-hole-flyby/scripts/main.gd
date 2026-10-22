extends Node2D

const Physics = preload("res://scripts/physics.gd")
const SKY_SHADER = preload("res://shaders/sky.gdshader")
const DURATION: float = 80.0
const HOLE_UV: Vector2 = Vector2(0.618, 0.370)
const KEYFRAMES: Array = [
	[0.0, 1.5e11],
	[0.16, 5.0e10],
	[0.36, 1.5e10],
	[0.58, 5.0e9],
	[0.72, 2.0e9],
	[0.82, 1.2e9],
	[0.90, 6.0e8],
	[1.0, 8.0e7]
]

var playhead: float = 0.0
var running: bool = true
var dragging: bool = false
var capturing: bool = false
var sky: ColorRect
var sky_material: ShaderMaterial
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	sky = ColorRect.new()
	sky.name = "GravitationalLensingSky"
	sky.show_behind_parent = true
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.material = sky_material
	add_child(sky)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in user_args:
		if arg.begins_with("--at="):
			playhead = clamp(float(arg.trim_prefix("--at=")), 0.0, DURATION)
			running = false
		if arg.begins_with("--capture-dir="):
			capturing = true
			running = false
	_update_sky()
	if capturing:
		call_deferred("_capture_sequence")

func _on_resize() -> void:
	sky.size = get_viewport_rect().size
	_update_sky()
	queue_redraw()

func _process(delta: float) -> void:
	if running and not dragging and not capturing:
		playhead = min(playhead + delta, DURATION)
		if playhead >= DURATION:
			running = false
	_update_sky()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				running = not running
			KEY_R:
				playhead = 0.0
				running = true
			KEY_LEFT:
				playhead = max(0.0, playhead - 3.0)
			KEY_RIGHT:
				playhead = min(DURATION, playhead + 3.0)
			KEY_HOME:
				playhead = 0.0
			KEY_END:
				playhead = DURATION
				if running:
					running = false
			KEY_F:
					var mode: int = DisplayServer.window_get_mode()
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				var index: int = event.keycode - KEY_1
				playhead = [0.0, 0.36, 0.58, 0.72, 0.82][index] * DURATION
				running = false
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var size: Vector2 = get_viewport_rect().size
			if event.position.y >= size.y - 82.0 and event.position.y <= size.y - 17.0:
				dragging = true
				running = false
				_seek_at(event.position.x)
		else:
			dragging = false
	if event is InputEventMouseMotion and dragging:
		_seek_at(event.position.x)

func _seek_at(mouse_x: float) -> void:
	var width: float = get_viewport_rect().size.x
	playhead = clamp((mouse_x - 62.0) / (width - 124.0), 0.0, 1.0) * DURATION
	_update_sky()
	queue_redraw()

func _distance_at(normalized_time: float) -> float:
	for i in range(KEYFRAMES.size() - 1):
		var a: Array = KEYFRAMES[i]
		var b: Array = KEYFRAMES[i + 1]
		if normalized_time <= float(b[0]):
			var fraction: float = clamp((normalized_time - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			fraction = fraction * fraction * (3.0 - 2.0 * fraction)
			return exp(lerp(log(float(a[1])), log(float(b[1])), fraction))
	return float(KEYFRAMES[-1][1])

func _distance() -> float:
	return _distance_at(playhead / DURATION)

func _disruption(distance_m: float) -> float:
	return 1.0 - smoothstep(6.0e8, 3.0e9, distance_m)

func _update_sky() -> void:
	if sky_material == null:
		return
	var size: Vector2 = get_viewport_rect().size
	var radius: float = _distance()
	var vertical_fov: float = deg_to_rad(42.0)
	var lens: float = Physics.einstein_angle(radius) / vertical_fov * 8.0
	var shadow: float = Physics.shadow_angle(radius) / vertical_fov * 550.0
	sky_material.set_shader_parameter("aspect", size.x / max(size.y, 1.0))
	sky_material.set_shader_parameter("hole_position", HOLE_UV)
	sky_material.set_shader_parameter("einstein_radius_screen", min(lens, 0.34))
	sky_material.set_shader_parameter("shadow_radius_screen", clamp(shadow, 0.007, 0.16))
	sky_material.set_shader_parameter("disruption", _disruption(radius))
	sky_material.set_shader_parameter("elapsed_time", playhead)

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var radius: float = _distance()
	var tidal: float = Physics.tidal_gravity(radius)
	var disruption: float = _disruption(radius)
	var quake: float = clamp(disruption * 12.0, 0.0, 1.0)
	_draw_atmosphere(size, quake)
	_draw_mountains(size, quake)
	_draw_city(size, quake, disruption)
	_draw_earth_fragments(size, tidal)
	_draw_overlay(size, radius, tidal)

func _draw_atmosphere(size: Vector2, quake: float) -> void:
	var y: float = size.y * 0.745
	for i in range(9):
		var alpha: float = (float(i) / 9.0) * 0.020
		draw_rect(Rect2(0.0, y + i * 12.0, size.x, 13.0), Color(0.44, 0.13, 0.11, alpha + quake * 0.01))

func _draw_mountains(size: Vector2, quake: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var shift: float = quake * sin(playhead * 9.8) * 5.0
	var distant := PackedVector2Array()
	distant.append(Vector2(0.0, h))
	for i in range(81):
		var x: float = float(i) * w / 80.0
		var y: float = h * 0.733 + 25.0 * sin(x * 0.010) + 17.0 * sin(x * 0.027) + 6.0 * cos(x * 0.048)
		distant.append(Vector2(x, y + shift))
	distant.append(Vector2(w, h))
	draw_colored_polygon(distant, Color(0.065, 0.082, 0.12))
	var near := PackedVector2Array()
	near.append(Vector2(0.0, h))
	for i in range(81):
		var x: float = float(i) * w / 80.0
		var y: float = h * 0.81 + 14.0 * sin(x * 0.017 + 1.0) + 9.0 * sin(x * 0.035)
		near.append(Vector2(x, y - shift * 0.6))
	near.append(Vector2(w, h))
	draw_colored_polygon(near, Color(0.030, 0.041, 0.073))

func _draw_city(size: Vector2, quake: float, disruption: float) -> void:
	var w: float = size.x
	var h: float = size.y
	var ground: float = h * 0.865
	var shake_x: float = quake * sin(playhead * 25.0) * 4.5
	for i in range(19):
		var x: float = float(i) * w / 18.0 - 10.0 + shake_x * sin(float(i) * 3.0)
		var bw: float = 42.0 + 18.0 * abs(sin(float(i) * 2.4))
		var bh: float = 48.0 + 95.0 * abs(sin(float(i) * 1.73))
		var by: float = ground - bh
		draw_rect(Rect2(x, by, bw, bh + 6.0), Color(0.026, 0.037, 0.064))
		for row in range(2, 9):
			for col in range(1, 4):
				var wx: float = x + float(col) * (bw / 5.0)
				var wy: float = by + float(row) * 13.0
				if wy >= ground - 7.0 or wy < by + 8.0:
					continue
				if (i * 7 + row * 3 + col * 13) % 5 < 2:
					draw_rect(Rect2(wx, wy, 3.0, 4.0), Color(0.92, 0.63, 0.35, 0.75 - disruption * 0.3))
	var road_y: float = h * 0.895
	draw_rect(Rect2(0.0, ground, w, h - ground), Color(0.016, 0.023, 0.041))
	draw_line(Vector2(0.0, road_y), Vector2(w, road_y), Color(0.26, 0.29, 0.36), 1.2)
	for lane in range(0, 13):
		var x: float = float(lane) * w / 12.0 + 18.0
		draw_line(Vector2(x, h * 0.951), Vector2(x + 42.0, h * 0.951), Color(0.50, 0.44, 0.33, 0.42), 2.5)
	for x in [100.0, 435.0, 865.0, 1188.0]:
		var top: float = ground - 67.0
		draw_line(Vector2(x, ground), Vector2(x, top), Color(0.10, 0.14, 0.18), 4.0)
		draw_line(Vector2(x, top), Vector2(x + 25.0, top), Color(0.11, 0.15, 0.20), 3.0)
		draw_circle(Vector2(x + 25.0, top), 11.0, Color(1.0, 0.58, 0.23, 0.045))
		draw_circle(Vector2(x + 25.0, top), 3.5, Color(1.0, 0.76, 0.42, 0.8))
	if disruption > 0.02:
		for i in range(17):
			var x: float = float(i) / 16.0 * w
			var crack: float = 13.0 + 46.0 * disruption * abs(sin(i * 2.41))
			draw_line(Vector2(x, ground), Vector2(x + crack * 0.5, ground + crack), Color(0.82, 0.24, 0.13, disruption * 0.7), 1.7)

func _draw_earth_fragments(size: Vector2, tidal: float) -> void:
	var progress: float = smoothstep(0.4, 5.5, tidal)
	if progress <= 0.001:
		return
	var w: float = size.x
	var h: float = size.y
	for i in range(65):
		var seed: float = sin(float(i) * 77.471) * 43758.5453
		var fraction: float = seed - floor(seed)
		var x: float = fraction * w
		var drift: float = (sin(float(i) * 1.9) * 0.5 + 0.5) * 125.0 * progress
		var lift: float = progress * progress * (30.0 + float(i % 9) * 24.0)
		var y: float = h * (0.83 + 0.1 * abs(sin(float(i) * 0.82))) - lift
		var r: float = 2.0 + float(i % 6) * 2.8 * progress
		var shape := PackedVector2Array([Vector2(x, y), Vector2(x + r + drift * 0.16, y - r), Vector2(x - r * 0.5, y - r * 0.4)])
		draw_colored_polygon(shape, Color(0.29, 0.20, 0.17, 0.3 + progress * 0.6))

func _phase(radius: float, tidal: float) -> String:
	if tidal >= 1.0:
		return "PO UTRACIE STABILNOŚCI ZIEMI — WIDOK UMOWNY"
	if radius < 3.0e9:
		return "KATASTROFALNE SIŁY PŁYWOWE"
	if radius < 1.5e10:
		return "ZABURZENIA ORBIT I GRAWITACJI"
	if radius < 5.0e10:
		return "SOCZEWKOWANIE GRAWITACYJNE"
	return "ODLEGŁA CZARNA DZIURA — NIEWIDOCZNA GOŁYM OKIEM"

func _draw_text(text: String, position: Vector2, size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _draw_overlay(size: Vector2, radius: float, tidal: float) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, 8.0), Color(0.25, 0.52, 0.77, 0.9))
	draw_rect(Rect2(42.0, 33.0, 398.0, 382.0), Color(0.015, 0.024, 0.043, 0.82))
	draw_rect(Rect2(42.0, 33.0, 3.0, 382.0), Color(0.28, 0.69, 0.96, 0.95))
	_draw_text("CZARNA DZIURA", Vector2(62.0, 83.0), 30)
	_draw_text("NAD ZIEMIĄ", Vector2(62.0, 125.0), 34, Color(0.68, 0.84, 1.0))
	_draw_text("10 M☉   |   v∞ = 200 km/s", Vector2(64.0, 159.0), 16, Color(0.66, 0.74, 0.84))
	draw_line(Vector2(62.0, 181.0), Vector2(415.0, 181.0), Color(0.23, 0.35, 0.47, 0.80), 1.0)
	_draw_text("ODLEGŁOŚĆ", Vector2(64.0, 210.0), 13, Color(0.55, 0.70, 0.82))
	_draw_text(Physics.format_distance(radius), Vector2(64.0, 247.0), 29)
	_draw_text("RÓŻNICA PRZYSPIESZEŃ PŁYWOWYCH", Vector2(64.0, 278.0), 12, Color(0.55, 0.70, 0.82))
	var tidal_color: Color = Color(1.0, 0.54, 0.38) if tidal >= 0.1 else Color(0.91, 0.94, 1.0)
	_draw_text("%.5g × g" % tidal, Vector2(64.0, 311.0), 26, tidal_color)
	_draw_text("DO PROGU Δg ≈ 1 g", Vector2(64.0, 344.0), 12, Color(0.55, 0.70, 0.82))
	var critical: float = Physics.critical_distance()
	var remaining: float = Physics.travel_time(radius, critical)
	var countdown: String = Physics.format_duration(remaining) if remaining >= 0.0 else "PRÓG PRZEKROCZONY"
	_draw_text(countdown, Vector2(64.0, 378.0), 24, Color(1.0, 0.67, 0.48) if remaining < 0.0 else Color(0.94, 0.96, 1.0))
	draw_rect(Rect2(w - 286.0, 33.0, 244.0, 72.0), Color(0.015, 0.024, 0.043, 0.78))
	_draw_text("SYMULACJA · GODOT 4", Vector2(w - 270.0, 61.0), 17)
	_draw_text("NIE JEST NAGRANIEM", Vector2(w - 270.0, 88.0), 13, Color(0.69, 0.79, 0.86))
	var angle: float = rad_to_deg(Physics.einstein_angle(radius))
	_draw_text("Kąt Einsteina: %.3f°" % angle, Vector2(w - 252.0, 133.0), 13, Color(0.71, 0.78, 0.91))
	_draw_text("Optyka ×8 | Cień ×550", Vector2(w - 252.0, 157.0), 13, Color(0.71, 0.78, 0.91))
	var caption_y: float = h - 136.0
	draw_rect(Rect2(42.0, caption_y - 34.0, w - 84.0, 83.0), Color(0.015, 0.024, 0.043, 0.83))
	var caption_color: Color = Color(1.0, 0.58, 0.49) if tidal >= 1.0 else Color(0.72, 0.88, 1.0)
	_draw_text(_phase(radius, tidal), Vector2(62.0, caption_y - 7.0), 17, caption_color)
	_draw_text("Czas rzeczywisty jest nieliniowo skrócony. Próg 1 g nie jest dokładną granicą rozpadu.", Vector2(62.0, caption_y + 19.0), 13, Color(0.77, 0.79, 0.86))
	var timeline_y: float = h - 40.0
	draw_rect(Rect2(62.0, timeline_y - 3.0, w - 124.0, 6.0), Color(0.24, 0.29, 0.38, 0.85))
	draw_rect(Rect2(62.0, timeline_y - 3.0, (w - 124.0) * (playhead / DURATION), 6.0), Color(0.42, 0.76, 1.0))
	for mark in [0.16, 0.36, 0.58, 0.72, 0.82, 0.90]:
		var tick: float = 62.0 + (w - 124.0) * mark
		draw_line(Vector2(tick, timeline_y - 8.0), Vector2(tick, timeline_y + 8.0), Color(0.67, 0.81, 0.90, 0.6), 1.0)
	draw_circle(Vector2(62.0 + (w - 124.0) * (playhead / DURATION), timeline_y), 8.0, Color(0.91, 0.96, 1.0))
	_draw_text("%02d:%02d / 01:20" % [int(playhead / 60.0), int(playhead) % 60], Vector2(62.0, h - 60.0), 14)
	_draw_text("SPACJA: START/PAUZA     ← →: PRZEWIŃ     1–5: ETAPY     R: OD NOWA", Vector2(w - 710.0, h - 60.0), 13, Color(0.71, 0.79, 0.87))

func _capture_sequence() -> void:
	var dir: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			dir = arg.trim_prefix("--capture-dir=")
	if dir.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var shots: Array = [
		[0.06, "01_distant.png"],
		[0.47, "02_lensing.png"],
		[0.72, "03_tides.png"],
		[0.87, "04_disruption.png"]
	]
	for shot in shots:
		playhead = float(shot[0]) * DURATION
		_update_sky()
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var filename: String = dir.path_join(str(shot[1]))
		var result: int = image.save_png(filename)
		if result != OK:
			push_error("Screenshot failed: %s (%d)" % [filename, result])
			get_tree().quit(3)
			return
		print("CAPTURED " + filename)
	get_tree().quit(0)
