extends RefCounted

const BODIES: int = 4
const COMPONENTS: int = 6
const DAY_S: float = 86400.0
const AU_M: float = 149597870700.0
const GMS: Array[float] = [1.32712440041279419e20, 398600.435507e9, 4902.800118e9, 1.32712440041279419e21]

var rows: Array[PackedFloat64Array] = []
var duration_days: float = 15.0
var last_error: String = ""
var details: Dictionary = {}

func load_data(path: String = "res://data/four_body.csv") -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "No N-body data. Run python scripts/generate_orbits.py to generate data/four_body.csv"
		return false
	rows.clear()
	var header: String = file.get_line()
	if not header.begins_with("days,Sun.x_au"):
		last_error = "Unexpected data header"
		return false
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges().is_empty():
			continue
		var pieces: PackedStringArray = line.split(",", false)
		if pieces.size() != 25:
			last_error = "Invalid 4-body sample: expected 25 columns, received %d" % pieces.size()
			return false
		var sample: PackedFloat64Array = PackedFloat64Array()
		sample.resize(25)
		for i in range(25):
			sample[i] = float(pieces[i])
		rows.append(sample)
	if rows.size() < 2:
		last_error = "Insufficient N-body samples"
		return false
	duration_days = rows[-1][0]
	var report: FileAccess = FileAccess.open(path.get_basename() + ".json", FileAccess.READ)
	if report != null:
		var parsed: Variant = JSON.parse_string(report.get_as_text())
		if parsed is Dictionary:
			details = parsed
	return true

func sample_at_day(day: float) -> PackedFloat64Array:
	if rows.is_empty():
		return PackedFloat64Array()
	if day <= rows[0][0]:
		return rows[0]
	if day >= rows[-1][0]:
		return rows[-1]
	var guess: int = clampi(int(day / duration_days * float(rows.size() - 1)), 0, rows.size() - 2)
	while guess < rows.size() - 2 and rows[guess + 1][0] < day:
		guess += 1
	while guess > 0 and rows[guess][0] > day:
		guess -= 1
	var a: PackedFloat64Array = rows[guess]
	var b: PackedFloat64Array = rows[guess + 1]
	var dt: float = b[0] - a[0]
	var u: float = (day - a[0]) / dt
	var u2: float = u * u
	var u3: float = u2 * u
	var h00: float = 2.0 * u3 - 3.0 * u2 + 1.0
	var h10: float = u3 - 2.0 * u2 + u
	var h01: float = -2.0 * u3 + 3.0 * u2
	var h11: float = u3 - u2
	var result: PackedFloat64Array = PackedFloat64Array()
	result.resize(25)
	result[0] = day
	for body in range(BODIES):
		var offset: int = 1 + body * COMPONENTS
		for axis in range(3):
			var p: int = offset + axis
			var v: int = p + 3
			result[p] = h00 * a[p] + h10 * dt * a[v] + h01 * b[p] + h11 * dt * b[v]
			result[v] = (((6.0 * u2 - 6.0 * u) * a[p] + (-6.0 * u2 + 6.0 * u) * b[p]) / dt + (3.0 * u2 - 4.0 * u + 1.0) * a[v] + (3.0 * u2 - 2.0 * u) * b[v])
	return result

func separation_au(row: PackedFloat64Array, first: int, second: int) -> float:
	var dx: float = row[1 + first * 6] - row[1 + second * 6]
	var dy: float = row[2 + first * 6] - row[2 + second * 6]
	var dz: float = row[3 + first * 6] - row[3 + second * 6]
	return sqrt(dx * dx + dy * dy + dz * dz)

func separation_km(row: PackedFloat64Array, first: int, second: int) -> float:
	return separation_au(row, first, second) * AU_M / 1000.0

func lunar_specific_energy(row: PackedFloat64Array) -> float:
	var sq: float = 0.0
	for k in range(3):
		var v: float = row[17 + k] - row[11 + k]
		sq += v * v
	var speed_scale: float = AU_M / DAY_S
	return 0.5 * sq * speed_scale * speed_scale - (GMS[1] + GMS[2]) / (separation_au(row, 1, 2) * AU_M)

func earth_tide_g(row: PackedFloat64Array) -> float:
	var r: float = separation_au(row, 1, 3) * AU_M
	return (2.0 * GMS[3] * 6371008.4 / (r * r * r)) / 9.80665