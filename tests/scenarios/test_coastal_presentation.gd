extends GutTest
## Reserved scatter spaces and scenery/ambience build/exit cleanup.

const LEVEL := preload("res://levels/coastal_highway/coastal_highway.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func test_scenery_reservations_rebuild_audio_and_dry_world() -> void:
	var level: RunLevel = LEVEL.instantiate()
	add_child_autofree(level)
	level.rig.car.freeze = true
	await wait_physics_frames(2)
	var trail := level.trail
	var placements: Array[Vector3] = trail.scatter_builder.get_meta(&"coastal_placements")
	var counts: Dictionary = trail.scatter_builder.get_meta(&"coastal_counts")
	assert_gt(counts.scrub, 20)
	assert_gt(counts.rocks, 5)
	assert_gt(counts.trees, 0)
	for p: Vector3 in placements:
		assert_gte(trail.field.edge_distance_at(p.x, p.z), trail.scatter.road_clearance)
		assert_gt(p.y, 0.4, "no scenery on the future sea floor")
		for area: Rect2 in trail.scatter.coastal_exclusions:
			assert_false(area.has_point(Vector2(p.x, p.z)), "reserved water/shortcut/sightline area")
	assert_true(trail.water_world.bodies.is_empty())
	assert_eq(trail.water_world.wave_binding_count(), 0)
	var old: WeakRef = weakref(trail.get_node("Generated"))
	trail.build()
	await wait_process_frames(3)
	assert_null(old.get_ref(), "old terrain/barriers/scenery are freed on rebuild")
	assert_eq(trail.scatter_builder.get_meta(&"coastal_placements"), placements, "deterministic rebuild")
	var ambience: LevelAmbience = level.get_node("Ambience")
	assert_true(ambience.wind.playing)
	assert_false(ambience.birds)
	assert_eq((level.get_node("ClearingWeather") as GoldenHourMood).sun_azimuth_deg,
		(level.get_node("Rainbow") as CoastalRainbow).sun_azimuth_deg)
	assert_eq(level.rig.camera.far, 4000.0, "far arc does not get sliced by the shared 1500 m default")
	level.remove_child(ambience)
	assert_false(ambience.wind.playing, "existing audio lifecycle stops the loop")
	assert_false(ambience.bird.playing)
	ambience.free()
