extends RefCounted

const AU_KM: float = 149597870.7
const EARTH_RADIUS_KM: float = 6371.0084
const MOON_RADIUS_KM: float = 1737.4
const SUN_RADIUS_KM: float = 695700.0
const BLACK_HOLE_MASS_SOLAR: float = 10.0
const GRAVITATIONAL_CONSTANT: float = 6.67430e-11
const LIGHT_SPEED_M_S: float = 299792458.0
const SOLAR_GM: float = 1.32712440041279419e20
const CAMERA_ALTITUDE_KM: float = 420.0
const CAMERA_TILT_RAD: float = 0.19
const CAMERA_FOV_DEG: float = 72.0

static func body_relative_earth(row: PackedFloat64Array, body: int) -> Vector3:
	var index: int = 1 + body * 6
	return Vector3(float(row[index] - row[7]), float(row[index + 1] - row[8]), float(row[index + 2] - row[9]))

static func orientation(row: PackedFloat64Array) -> Dictionary:
	var bh: Vector3 = body_relative_earth(row, 3)
	var forward: Vector3 = bh.normalized()
	var north: Vector3 = Vector3(0.0, 0.0, 1.0)
	if absf(forward.dot(north)) > 0.97:
		north = Vector3(0.0, 1.0, 0.0)
	var up: Vector3 = (north - forward * forward.dot(north)).normalized()
	var right: Vector3 = forward.cross(up).normalized()
	var radial: Vector3 = (up * cos(CAMERA_TILT_RAD) - forward * sin(CAMERA_TILT_RAD)).normalized()
	var offset_au: Vector3 = radial * ((EARTH_RADIUS_KM + CAMERA_ALTITUDE_KM) / AU_KM)
	return {"forward": forward, "up": up, "right": right, "radial": radial, "offset": offset_au}

static func unit_direction(row: PackedFloat64Array, frame: Dictionary, body: int) -> Vector3:
	return (body_relative_earth(row, body) - frame["offset"]).normalized()

static func camera_direction(row: PackedFloat64Array, frame: Dictionary, body: int) -> Vector3:
	var direction: Vector3 = unit_direction(row, frame, body)
	return Vector3(direction.dot(frame["right"]), direction.dot(frame["up"]), direction.dot(frame["forward"]))

static func angular_radius_deg(row: PackedFloat64Array, frame: Dictionary, body: int) -> float:
	var radius_km: float = SUN_RADIUS_KM if body == 0 else MOON_RADIUS_KM
	if body == 3:
		radius_km = 3.0 * SOLAR_GM * BLACK_HOLE_MASS_SOLAR / (LIGHT_SPEED_M_S * LIGHT_SPEED_M_S) / 1000.0
	var separation_km: float = (body_relative_earth(row, body) - frame["offset"]).length() * AU_KM
	return rad_to_deg(atan2(radius_km, maxf(separation_km, 0.1)))

static func earth_occults(direction: Vector3, frame: Dictionary) -> bool:
	var earth_center: Vector3 = -frame["radial"]
	var cos_angle: float = clampf(direction.dot(earth_center), -1.0, 1.0)
	var horizon_angle: float = asin(EARTH_RADIUS_KM / (EARTH_RADIUS_KM + CAMERA_ALTITUDE_KM))
	return acos(cos_angle) < horizon_angle

static func project(row: PackedFloat64Array, frame: Dictionary, body: int, screen: Vector2) -> Dictionary:
	var local: Vector3 = camera_direction(row, frame, body)
	var f: float = 0.5 / tan(deg_to_rad(CAMERA_FOV_DEG) * 0.5)
	var aspect: float = screen.x / screen.y
	var uv: Vector2 = Vector2(-10.0, -10.0)
	if local.z > 0.000001:
		uv = Vector2(0.5 + local.x / local.z * f / aspect, 0.5 - local.y / local.z * f)
	var direction: Vector3 = unit_direction(row, frame, body)
	var blocked: bool = earth_occults(direction, frame)
	return {
		"uv": uv,
		"position": uv * screen,
		"front": local.z > 0.0,
		"on_screen": local.z > 0.0 and uv.x > 0.0 and uv.x < 1.0 and uv.y > 0.0 and uv.y < 1.0 and not blocked,
		"occluded": blocked,
		"off_axis_deg": rad_to_deg(acos(clampf(local.z, -1.0, 1.0))),
		"angular_radius_deg": angular_radius_deg(row, frame, body),
		"distance_km": (body_relative_earth(row, body) - frame["offset"]).length() * AU_KM,
		"local": local
	}

static func sun_direction_local(row: PackedFloat64Array, frame: Dictionary) -> Vector3:
	var direction: Vector3 = body_relative_earth(row, 0).normalized()
	return Vector3(direction.dot(frame["right"]), direction.dot(frame["up"]), -direction.dot(frame["forward"]))

static func moon_phase_direction(row: PackedFloat64Array, frame: Dictionary) -> Vector2:
	var moon_sun: Vector3 = body_relative_earth(row, 0) - body_relative_earth(row, 2)
	var sun_ray: Vector3 = moon_sun.normalized()
	var projected: Vector2 = Vector2(sun_ray.dot(frame["right"]), -sun_ray.dot(frame["up"]))
	return projected.normalized() if projected.length_squared() > 1e-10 else Vector2.RIGHT
