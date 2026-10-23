extends Node2D

const Orbits = preload("res://scripts/orbital_data.gd")
const Physics = preload("res://scripts/physics.gd")
const SKY_SHADER = preload("res://shaders/sky.gdshader")
const EARTH_SHADER = preload("res://shaders/earth.gdshader")
const DURATION: float = 80.0
const PROJECT_SAMPLES: int = 5
const SOLAR_COLORS: Array[Color] = [Color(1.0, 0.80, 0.36), Color(0.39, 0.73, 1.0), Color(0.90, 0.90, 0.90), Color(0.99, 0.47, 0.68)]

var orbits = Orbits.new()
var state: PackedFloat64Array = PackedFloat64Array()
var first: PackedFloat64Array = PackedFloat64Array()
var playhead: float = 0.0
var playing: bool = true
var dragging: bool = false
var capturing: bool = false
var sun_axis: Vector2 = Vector2.RIGHT
var tangent_axis: Vector2 = Vector2.DOWN
var axes_r: Vector3 = Vector3.RIGHT
var axes_t: Vector3 = Vector3.UP
var solar_min: Vector2 = Vector2.ZERO
var solar_max: Vector2 = Vector2.ONE
var lunar_max: float = 0.012
var sky: ColorRect
var sky_material: ShaderMaterial
var earth: ColorRect
var earth_material: ShaderMaterial
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	if not orbits.load_data():
		push_error(orbits.last_error)
		return
	first = orbits.rows[0]
	var radial: Vector3 = Vector3(float(first[7] - first[1]), float(first[8] - first[2]), float(first[9] - first[3])).normalized()
	var velocity: Vector3 = Vector3(float(first[10] - first[4]), float(first[11] - first[5]), float(first[12] - first[6]))
	axes_r = radial
	axes_t = (velocity - radial * velocity.dot(radial)).normalized()
	_calculate_bounds()
	sky = ColorRect.new()
	sky.name = "GravitationalLensingBackdrop"
	sky.show_behind_parent = true
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.material = sky_material
	add_child(sky)
	earth = ColorRect.new()
	earth.name = "EarthFromLowOrbit"
	earth.show_behind_parent = true
	earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	earth_material = ShaderMaterial.new()
	earth_material.shader = EARTH_SHADER
	earth.material = earth_material
	add_child(earth)
	get_viewport().size_changed.connect(_resize)
	_resize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			playhead = clampf(float(arg.trim_prefix("--at=")), 0.0, DURATION)
			playing = false
		if arg.begins_with("--capture-dir="):
			capturing = true
			playing = false
	_refresh()
	if capturing:
		call_deferred("_capture")

func _resize() -> void:
	if sky == null or earth == null:
		return
	var size: Vector2 = get_viewport_rect().size
	sky.size = size
	earth.size = size
	_refresh()
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or capturing or orbits.rows.is_empty():
		return
	playhead = minf(playhead + delta, DURATION)
	if playhead >= DURATION:
		playing = false
	_refresh()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				playing = not playing
			KEY_R:
				playhead = 0.0
				playing = true
			KEY_LEFT:
				playhead = maxf(playhead - 3.0, 0.0)
			KEY_RIGHT:
				playhead = minf(playhead + 3.0, DURATION)
			KEY_HOME:
				playhead = 0.0
			KEY_END:
				playhead = DURATION
				playing = false
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				playhead = [0.0, 0.25, 0.40, 0.65, 0.95][event.keycode - KEY_1] * DURATION
				playing = false
		_refresh()
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y > get_viewport_rect().size.y - 90.0:
			dragging = true
			playing = false
			_seek(event.position.x)
		elif not event.pressed:
			dragging = false
	if event is InputEventMouseMotion and dragging:
		_seek(event.position.x)

func _seek(mouse_x: float) -> void:
	var w: float = get_viewport_rect().size.x
	playhead = clampf((mouse_x - 62.0) / (w - 124.0), 0.0, 1.0) * DURATION
	_refresh()
	queue_redraw()

func _refresh() -> void:
	if orbits.rows.is_empty():
		return
	state = orbits.sample_at_day(playhead / DURATION * orbits.duration_days)
	if sky_material == null or earth_material == null:
		return
	var size: Vector2 = get_viewport_rect().size
	var d: float = orbits.separation_au(state, 1, 3) * Orbits.AU_M
	var fov: float = deg_to_rad(42.0)
	sky_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	sky_material.set_shader_parameter("hole_position", Vector2(0.618, 0.37))
	sky_material.set_shader_parameter("einstein_radius_screen", minf(Physics.einstein_angle(d) / fov * 8.0, 0.34))
	sky_material.set_shader_parameter("shadow_radius_screen", clampf(Physics.shadow_angle(d) / fov * 550.0, 0.007, 0.16))
	sky_material.set_shader_parameter("disruption", 0.0)
	sky_material.set_shader_parameter("elapsed_time", playhead)
	earth_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	earth_material.set_shader_parameter("disruption", 0.0)
	earth_material.set_shader_parameter("elapsed_time", playhead)

func _project(row: PackedFloat64Array, body: int, relative: int = -1) -> Vector2:
	var base: int = 1 + body * 6
	var xx: float = row[base]
	var yy: float = row[base + 1]
	var zz: float = row[base + 2]
	if relative >= 0:
		var ref: int = 1 + relative * 6
		xx -= row[ref]
		yy -= row[ref + 1]
		zz -= row[ref + 2]
	return Vector2(float(xx * axes_r.x + yy * axes_r.y + zz * axes_r.z), float(xx * axes_t.x + yy * axes_t.y + zz * axes_t.z))

func _calculate_bounds() -> void:
	solar_min = Vector2(INF, INF)
	solar_max = Vector2(-INF, -INF)
	lunar_max = 0.003
	for row in orbits.rows:
		for index in [0, 1, 3]:
			var p: Vector2 = _project(row, index)
			solar_min = solar_min.min(p)
			solar_max = solar_max.max(p)
		lunar_max = maxf(lunar_max, _project(row, 2, 1).length())
	var span: Vector2 = solar_max - solar_min
	solar_min -= span * 0.07
	solar_max += span * 0.07
	lunar_max *= 1.15

func _in_plot(p: Vector2, rect: Rect2, minimum: Vector2, maximum: Vector2) -> Vector2:
	var span: Vector2 = maximum - minimum
	var scale: float = minf((rect.size.x - 28.0) / maxf(span.x, 0.0001), (rect.size.y - 42.0) / maxf(span.y, 0.0001))
	var center: Vector2 = (minimum + maximum) * 0.5
	return rect.position + rect.size * 0.5 + Vector2((p.x - center.x) * scale, -(p.y - center.y) * scale + 10.0)

func _trail(body: int, rect: Rect2, minimum: Vector2, maximum: Vector2, relative: int = -1) -> void:
	var before: PackedVector2Array = PackedVector2Array()
	var after: PackedVector2Array = PackedVector2Array()
	var now: float = state[0]
	for i in range(0, orbits.rows.size(), PROJECT_SAMPLES):
		var row: PackedFloat64Array = orbits.rows[i]
		var p: Vector2 = _in_plot(_project(row, body, relative), rect, minimum, maximum)
		if row[0] <= now:
			before.append(p)
		else:
			after.append(p)
	var current: Vector2 = _in_plot(_project(state, body, relative), rect, minimum, maximum)
	before.append(current)
	after.insert(0, current)
	if after.size() > 1:
		draw_polyline(after, Color(SOLAR_COLORS[body], 0.12), 1.0, true)
	if before.size() > 1:
		draw_polyline(before, Color(SOLAR_COLORS[body], 0.90), 2.0, true)
	draw_circle(current, 4.8 if body != 3 else 6.0, SOLAR_COLORS[body])

func _text(t: String, p: Vector2, size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _sun(size: Vector2) -> void:
	var center: Vector2 = Vector2(size.x * 0.920, size.y * 0.290)
	for j in range(7, 0, -1):
		draw_circle(center, 20.0 + 11.0 * float(j), Color(1.0, 0.65, 0.27, 0.012))
	for j in range(12):
		var v: Vector2 = Vector2.from_angle(float(j) * TAU / 12.0)
		draw_line(center + v * 23.0, center + v * 48.0, Color(1.0, 0.78, 0.35, 0.39), 1.5)
	draw_circle(center, 20.0, Color(1.0, 0.94, 0.73))
	draw_circle(center, 12.0, Color(1.0, 1.0, 0.95))

func _moon(size: Vector2) -> void:
	var center: Vector2 = Vector2(size.x * 0.413, size.y * 0.365)
	draw_circle(center, 27.0, Color(0.40, 0.44, 0.52))
	for j in range(12):
		var a: float = float(j) * 2.399963
		var offset: float = 23.0 * sqrt(float(j + 1) / 14.0)
		draw_circle(center + Vector2(cos(a), sin(a)) * offset, 1.0 + float(j % 3) * 1.4, Color(0.19, 0.24, 0.31, 0.63))
	draw_arc(center, 26.6, 0.0, TAU, 48, Color(0.74, 0.78, 0.88, 0.50), 1.0)

func _maps(size: Vector2) -> void:
	var outer: Rect2 = Rect2(468, size.y - 371.0, (size.x - 496.0) * 0.49, 212.0)
	var inner: Rect2 = Rect2(outer.end.x + 10.0, outer.position.y, size.x - outer.end.x - 29.0, 212.0)
	for rect in [outer, inner]:
		draw_rect(rect, Color(0.012, 0.022, 0.044, 0.88))
		draw_rect(rect, Color(0.26, 0.40, 0.52, 0.48), false, 1.0)
	_text("UKŁAD INERCJALNY · AU", outer.position + Vector2(11, 22), 14, Color(0.77, 0.86, 0.99))
	_text("ZIEMIA–KSIĘŻYC · km", inner.position + Vector2(11, 22), 14, Color(0.77, 0.86, 0.99))
	var center: Vector2 = _in_plot(Vector2.ZERO, outer, solar_min, solar_max)
	draw_line(Vector2(outer.position.x + 10, center.y), Vector2(outer.end.x - 10, center.y), Color(0.45, 0.54, 0.69, 0.18), 1.0)
	for body in [0, 1, 3]:
		_trail(body, outer, solar_min, solar_max)
	var m_min: Vector2 = Vector2(-lunar_max, -lunar_max)
	var m_max: Vector2 = -m_min
	var e: Vector2 = _in_plot(Vector2.ZERO, inner, m_min, m_max)
	var r_point: Vector2 = _in_plot(Vector2(384400000.0 / Orbits.AU_M, 0.0), inner, m_min, m_max)
	draw_arc(e, absf(r_point.x - e.x), 0.0, TAU, 64, Color(0.25, 0.47, 0.77, 0.30), 1.0)
	draw_circle(e, 5.5, Color(0.35, 0.67, 1.0))
	_trail(2, inner, m_min, m_max, 1)
	_text("SŁOŃCE  ·  ZIEMIA  ·  CZARNA DZIURA", outer.position + Vector2(11, outer.size.y - 9.0), 12, Color(0.78, 0.82, 0.90))
	var lunar_d: float = orbits.separation_km(state, 1, 2)
	var suffix: String = "  ·  KSIĘŻYC UWOLNIONY*" if orbits.lunar_specific_energy(state) >= 0.0 else "  ·  KSIĘŻYC ZWIĄZANY*"
	_text("%.0f km%s" % [lunar_d, suffix], inner.position + Vector2(11, inner.size.y - 9.0), 12, Color(0.79, 0.85, 0.92))

func _draw() -> void:
	if state.is_empty():
		return
	var size: Vector2 = get_viewport_rect().size
	_sun(size)
	_moon(size)
	_maps(size)
	_overlay(size)

func _overlay(size: Vector2) -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, 7), Color(0.32, 0.59, 0.83, 0.85))
	draw_rect(Rect2(38, 30, 416, 432), Color(0.011, 0.022, 0.042, 0.90))
	draw_rect(Rect2(38, 30, 3, 432), Color(0.36, 0.77, 1.0))
	_text("CZARNA DZIURA", Vector2(57, 80), 29)
	_text("ZABURZENIA ORBIT", Vector2(57, 118), 30, Color(0.65, 0.84, 1.0))
	_text("10 M☉ · 200 km/s na początku", Vector2(58, 148), 15, Color(0.71, 0.80, 0.89))
	draw_line(Vector2(58, 173), Vector2(432, 173), Color(0.20, 0.34, 0.45, 0.9), 1.0)
	var bh_km: float = orbits.separation_km(state, 1, 3)
	var moon_km: float = orbits.separation_km(state, 1, 2)
	var sun_au: float = orbits.separation_au(state, 0, 1)
	_text("CZARNA DZIURA – ZIEMIA", Vector2(59, 201), 13, Color(0.57, 0.73, 0.86))
	_text("%.2f mln km" % (bh_km / 1.0e6), Vector2(59, 236), 26)
	_text("KSIĘŻYC – ZIEMIA", Vector2(59, 261), 13, Color(0.57, 0.73, 0.86))
	_text("%.0f tys. km" % (moon_km / 1000.0), Vector2(59, 294), 24)
	_text("SŁOŃCE – ZIEMIA", Vector2(59, 319), 13, Color(0.57, 0.73, 0.86))
	_text("%.5f AU" % sun_au, Vector2(59, 352), 25)
	_text("SIŁY PŁYWOWE CZARNEJ DZIURY", Vector2(59, 378), 13, Color(0.57, 0.73, 0.86))
	_text("%.3e g" % orbits.earth_tide_g(state), Vector2(59, 410), 24, Color(1.0, 0.81, 0.66))
	_text("T = %.2f / %.0f dni" % [state[0], orbits.duration_days], Vector2(59, 444), 15, Color(0.69, 0.83, 0.99))
	draw_rect(Rect2(w - 272.0, 28, 244, 82), Color(0.011, 0.022, 0.042, 0.82))
	_text("GODOT 4 · DOP853", Vector2(w - 257.0, 57), 17)
	_text("4 ciała · masa punktowa", Vector2(w - 257.0, 80), 13, Color(0.76, 0.85, 0.94))
	_text("Orbity numeryczne", Vector2(w - 257.0, 99), 12, Color(0.65, 0.81, 0.99))
	var caption: String = "KSIĘŻYC MA DODATNIĄ ENERGIĘ WZGLĘDEM ZIEMI*" if orbits.lunar_specific_energy(state) >= 0.0 else "KSIĘŻYC POZOSTAJE ZWIĄZANY GRAWITACYJNIE*"
	draw_rect(Rect2(38, h - 151, w - 76.0, 63.0), Color(0.010, 0.020, 0.039, 0.92))
	_text(caption, Vector2(57, h - 125), 16, Color(0.95, 0.69, 0.53) if orbits.lunar_specific_energy(state) >= 0 else Color(0.72, 0.91, 1.0))
	_text("*Kryterium chwilowe. Obraz nieba umowny; trajektorie z integracji. Bez hydrodynamiki i GR.", Vector2(57, h - 103), 13, Color(0.75, 0.82, 0.89))
	var line_y: float = h - 38.0
	draw_rect(Rect2(62, line_y - 3, w - 124, 6), Color(0.22, 0.27, 0.37))
	draw_rect(Rect2(62, line_y - 3, (w - 124) * (playhead / DURATION), 6), Color(0.44, 0.76, 0.98))
	for tick in [0.25, 0.4, 0.65, 0.95]:
		var x: float = 62 + (w - 124) * tick
		draw_line(Vector2(x, line_y - 8), Vector2(x, line_y + 8), Color(0.72, 0.84, 1.0, 0.52), 1.0)
	draw_circle(Vector2(62 + (w - 124) * playhead / DURATION, line_y), 8, Color(0.96, 0.97, 1.0))
	_text("%02d:%02d / 01:20" % [int(playhead / 60.0), int(playhead) % 60], Vector2(62, h - 55), 15)
	_text("SPACJA: PAUZA · ← →: CZAS · 1–5: ETAPY · R: RESET", Vector2(w - 686, h - 55), 13, Color(0.75, 0.83, 0.93))

func _capture() -> void:
	var folder: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			folder = arg.trim_prefix("--capture-dir=")
	if folder.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var shots: Array = [[0.05, "01_distant.png"], [0.35, "02_lensing.png"], [0.50, "03_tides.png"], [0.90, "04_disruption.png"]]
	for shot in shots:
		playhead = float(shot[0]) * DURATION
		_refresh()
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output: String = folder.path_join(str(shot[1]))
		if get_viewport().get_texture().get_image().save_png(output) != OK:
			push_error("Screenshot creation failed at %s" % output)
			get_tree().quit(3)
			return
		print("CAPTURED " + output)
	get_tree().quit(0)