extends RefCounted

const G: float = 6.67430e-11
const C: float = 299792458.0
const SOLAR_MASS: float = 1.98847e30
const EARTH_RADIUS: float = 6371000.0
const EARTH_G: float = 9.80665
const BLACK_HOLE_MASS: float = 10.0 * SOLAR_MASS
const INFINITY_SPEED: float = 200000.0
const GM: float = G * BLACK_HOLE_MASS

static func schwarzschild_radius() -> float:
	return 2.0 * GM / (C * C)

static func critical_distance() -> float:
	return pow(2.0 * GM * EARTH_RADIUS / EARTH_G, 1.0 / 3.0)

static func tidal_gravity(distance_m: float) -> float:
	return 2.0 * GM * EARTH_RADIUS / (distance_m * distance_m * distance_m) / EARTH_G

static func einstein_angle(distance_m: float) -> float:
	return sqrt(4.0 * GM / (C * C * distance_m))

static func shadow_angle(distance_m: float) -> float:
	return 3.0 * sqrt(3.0) * GM / (C * C * distance_m)

static func radial_speed(distance_m: float) -> float:
	return sqrt(INFINITY_SPEED * INFINITY_SPEED + 2.0 * GM / distance_m)

static func radial_time_antiderivative(distance_m: float) -> float:
	var x: float = INFINITY_SPEED * sqrt(distance_m / (2.0 * GM))
	return 2.0 * GM / pow(INFINITY_SPEED, 3.0) * (x * sqrt(1.0 + x * x) - asinh(x))

static func travel_time(from_m: float, to_m: float) -> float:
	return radial_time_antiderivative(from_m) - radial_time_antiderivative(to_m)

static func format_ratio(value: float) -> String:
	if value <= 0.0:
		return "0"
	if value < 0.0001:
		var exponent: int = int(floor(log(value) / log(10.0)))
		return "%.2f×10^%d" % [value / pow(10.0, float(exponent)), exponent]
	if value < 1.0:
		return "%.4f" % value
	if value < 1000.0:
		return "%.2f" % value
	return "%.0f" % value

static func format_distance(distance_m: float) -> String:
	var km: float = distance_m / 1000.0
	if km >= 1000000.0:
		return "%.1f mln km" % (km / 1000000.0)
	if km >= 10000.0:
		return "%.0f tys. km" % (km / 1000.0)
	return "%.0f km" % km

static func format_duration(seconds: float) -> String:
	var total: int = int(max(seconds, 0.0))
	if total >= 86400:
		return "%d d %02d h" % [int(total / 86400), int(total / 3600) % 24]
	if total >= 3600:
		return "%d h %02d min" % [int(total / 3600), int(total / 60) % 60]
	if total >= 60:
		return "%d min %02d s" % [int(total / 60), total % 60]
	return "%d s" % total
