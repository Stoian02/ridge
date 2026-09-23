extends GutTest
## Captured on the unchanged dry implementation, before M6A adapter edits.

const RECORDER := preload("res://tools/record_water_geometry.gd")
const EXPECTED := {
	"rally_road": {"creek": 4015227954, "ruts": 4015227954, "fords": 4100093049},
	"muddy_valley": {"creek": 3401799410, "ruts": 4015227954, "fords": 4100093049},
	"frozen_pass": {"creek": 4015227954, "ruts": 4015227954, "fords": 4100093049},
	"rock_canyon": {"creek": 4015227954, "ruts": 2601197774, "fords": 606759587},
}


func test_existing_water_mesh_arrays_have_not_moved() -> void:
	for id: String in EXPECTED:
		assert_eq(RECORDER.fingerprint(self, id), EXPECTED[id], id)
