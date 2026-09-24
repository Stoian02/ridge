class_name WaterWaveCourseCache
extends RefCounted
## Explicit opt-in only. One deep topology shared by calm/current, four distinct
## shallow masks. No normal-course hook, background build or global cache lifetime.

const DIRECTORY := "res://water/waves/baked/"
var tops: Array[WaterWaveMesh] = []
var preparation_usec := 0
var phases: Dictionary = {}
var error := ""


func prepare(course: WaterCourse, settings: WaterWaveProfile = null) -> bool:
	var started := Time.get_ticks_usec()
	preparation_usec = 0
	tops.clear()
	phases.clear()
	error = ""
	var profile := settings if settings != null else WaterWaveProfile.new()
	if not profile.is_valid():
		error = "Invalid wave profile"
		return false
	var source_faces: Array[PackedVector3Array] = [course.pool_water_faces]
	var source_colors: Array[PackedColorArray] = [course.pool_water_colors]
	for index in WaterCourse.BAY_STARTS.size():
		var rows := WaterCourse._shallow_bay_rows(index)
		var source := WaterCourse._water_data(rows, 3.8, 4.0, WaterCourse.SHALLOW_LEVEL, WaterCourse.SHALLOW_LEVEL, true)
		source_faces.append(source.faces)
		source_colors.append(source.colors)
	phases["source_usec"] = Time.get_ticks_usec() - started
	var validation_usec := 0
	var loading_usec := 0
	var adoption_usec := 0
	for index in source_faces.size():
		var mark := Time.get_ticks_usec()
		var bed := course.pool_floor_faces if index == 0 else course.shallow_floor_faces
		var fingerprint := WaterWaveBake.fingerprint(source_faces[index], bed, source_colors[index], profile)
		validation_usec += Time.get_ticks_usec() - mark
		var name := "deep" if index == 0 else "bay_%d" % (index - 1)
		mark = Time.get_ticks_usec()
		var bake := load(DIRECTORY + name + ".res") as WaterWaveBake
		loading_usec += Time.get_ticks_usec() - mark
		mark = Time.get_ticks_usec()
		var data := WaterWaveMesh.new()
		if not data.use_bake(bake, fingerprint):
			error = name + ": " + data.error
			tops.clear()
			return false
		tops.append(data)
		adoption_usec += Time.get_ticks_usec() - mark
	phases["fingerprint_usec"] = validation_usec
	phases["resource_load_usec"] = loading_usec
	phases["adopt_usec"] = adoption_usec
	preparation_usec = Time.get_ticks_usec() - started
	phases["total_usec"] = preparation_usec
	return true
