extends SceneTree

const Physics = preload("res://scripts/physics.gd")

func _initialize() -> void:
	assert(abs(Physics.schwarzschild_radius() / 1000.0 - 29.53) < 0.05)
	assert(abs(Physics.critical_distance() / 1000.0 - 1199169.47) < 20.0)
	assert(abs(Physics.tidal_gravity(Physics.critical_distance()) - 1.0) < 0.0001)
	assert(Physics.einstein_angle(1.0e9) > Physics.einstein_angle(1.0e10))
	assert(Physics.shadow_angle(1.0e9) > Physics.shadow_angle(1.0e10))
	assert(Physics.travel_time(1.5e11, Physics.critical_distance()) > 500000.0)
	assert(Physics.travel_time(5.0e9, Physics.critical_distance()) > 3900.0)
	assert(Physics.travel_time(2.0e9, Physics.critical_distance()) < 620.0)
	print("PHYSICS TESTS PASSED")
	quit(0)
