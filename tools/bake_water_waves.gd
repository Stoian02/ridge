extends SceneTree
## Generates only new wave assets, never protected level/balance fixtures.
## godot --headless --path . -s tools/bake_water_waves.gd


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var course := WaterCourse.new()
	root.add_child(course)
	var profile := WaterWaveProfile.new()
	DirAccess.make_dir_recursive_absolute(WaterWaveCourseCache.DIRECTORY)
	for index in range(-1, WaterCourse.BAY_STARTS.size()):
		var top := course.pool_water_faces
		var bed := course.pool_floor_faces
		var colors := course.pool_water_colors
		var name := "deep"
		if index >= 0:
			var rows := WaterCourse._shallow_bay_rows(index)
			var source := WaterCourse._water_data(rows, 3.8, 4.0, WaterCourse.SHALLOW_LEVEL, WaterCourse.SHALLOW_LEVEL, true)
			top = source.faces
			colors = source.colors
			bed = course.shallow_floor_faces
			name = "bay_%d" % index
		var data := WaterWaveMesh.new()
		if not data.build(top, bed, colors, profile, true):
			push_error(data.error)
			quit(1)
			return
		var bake := WaterWaveBake.new()
		bake.capture(data, WaterWaveBake.fingerprint(top, bed, colors, profile))
		var path := WaterWaveCourseCache.DIRECTORY + name + ".res"
		if ResourceSaver.save(bake, path, ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Cannot write " + path)
			quit(1)
			return
		print("wave bake ", name, " ", bake.source_fingerprint, " ", data.build_phases)
	course.queue_free()
	await process_frame
	quit()
