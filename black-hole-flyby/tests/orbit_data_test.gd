extends SceneTree

const Orbits = preload("res://scripts/orbital_data.gd")

func _initialize() -> void:
	var orbits = Orbits.new()
	assert(orbits.load_data(), orbits.last_error)
	assert(orbits.rows.size() == 1201)
	assert(absf(orbits.duration_days - 15.0) < 1.0e-9)
	var start: PackedFloat64Array = orbits.rows[0]
	var finish: PackedFloat64Array = orbits.rows[-1]
	assert(orbits.separation_km(start, 0, 1) > 140000000.0)
	assert(orbits.separation_km(start, 0, 1) < 160000000.0)
	assert(orbits.separation_km(start, 1, 2) > 340000.0)
	assert(orbits.separation_km(start, 1, 2) < 430000.0)
	assert(orbits.separation_km(start, 1, 3) > 1.0e8)
	assert(orbits.separation_km(finish, 1, 3) > 0.0)
	var mid: PackedFloat64Array = orbits.sample_at_day(7.5001)
	assert(mid.size() == 25)
	assert(absf(mid[0] - 7.5001) < 1.0e-9)
	assert(is_finite(orbits.lunar_specific_energy(mid)))
	assert(orbits.earth_tide_g(mid) > 0.0)
	assert(orbits.details.has("relative_energy_drift"))
	assert(float(orbits.details["relative_energy_drift"]) < 3.0e-9)
	assert(float(orbits.details["closest_earth_moon_km"]) > 8108.4)
	print("FOUR-BODY DATA AND INTEGRATOR DIAGNOSTICS PASS")
	quit(0)