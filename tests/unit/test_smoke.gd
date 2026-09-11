extends GutTest
## Guards the project settings everything else depends on.


func test_uses_jolt_physics() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_runs_at_120_hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 120)


func test_worker_threads_are_capped() -> void:
	# Jolt's job system intermittently overflows with many worker threads.
	assert_eq(ProjectSettings.get_setting("threading/worker_pool/max_threads"), 4)
