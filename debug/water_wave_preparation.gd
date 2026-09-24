extends SceneTree
## Offline preparation phase audit only. Not a runtime or phone gate.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var course := WaterCourse.new()
	root.add_child(course)
	for round in 3:
		var data := WaterWaveMesh.new()
		if not data.build(course.pool_water_faces, course.pool_floor_faces, course.pool_water_colors, null, true):
			push_error(data.error)
			quit(1)
			return
		print("wave preparation ", JSON.stringify({"round": round + 1, "body": "shared_deep", "phases": data.build_phases,
			"vertices": data.vertices.size(), "triangles": data.indices.size() / 3}))
		for index in WaterCourse.BAY_STARTS.size():
			var rows := WaterCourse._shallow_bay_rows(index)
			var source := WaterCourse._water_data(rows, 3.8, 4.0, WaterCourse.SHALLOW_LEVEL, WaterCourse.SHALLOW_LEVEL, true)
			var bay := WaterWaveMesh.new()
			if not bay.build(source.faces, course.shallow_floor_faces, source.colors, null, true):
				push_error(bay.error)
				quit(1)
				return
			print("wave preparation ", JSON.stringify({"round": round + 1, "body": "bay_%d" % index, "phases": bay.build_phases,
				"vertices": bay.vertices.size(), "triangles": bay.indices.size() / 3}))
	course.queue_free()
	await process_frame
	quit()
