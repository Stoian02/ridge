extends GutTest

var catalog: LevelCatalog


func _level(id: StringName, scene: String) -> LevelDef:
	var level := LevelDef.new()
	level.id = id
	level.scene_path = scene
	return level


func before_each() -> void:
	catalog = LevelCatalog.new()
	catalog.levels = [_level(&"a", "res://a.tscn"), _level(&"b", "res://b.tscn"), _level(&"c", "res://c.tscn")]


func test_find_by_id_and_scene() -> void:
	assert_eq(catalog.find_by_id(&"b"), catalog.levels[1])
	assert_eq(catalog.find_by_scene("res://c.tscn"), catalog.levels[2])
	assert_null(catalog.find_by_id(&"missing"))
	assert_null(catalog.find_by_scene("res://levels/test_ground/test_ground.tscn"))


func test_next_and_previous_follow_catalog_order() -> void:
	assert_eq(catalog.next_after(catalog.levels[0]), catalog.levels[1])
	assert_null(catalog.next_after(catalog.levels[2]), "the last level has no next")
	assert_eq(catalog.previous_of(catalog.levels[1]), catalog.levels[0])
	assert_null(catalog.previous_of(catalog.levels[0]), "the first level has no previous")
	assert_null(catalog.next_after(_level(&"x", "res://x.tscn")), "unknown level")


func test_the_shipped_catalog_starts_with_rally_road() -> void:
	var shipped: LevelCatalog = load("res://levels/catalog.tres")
	assert_gt(shipped.levels.size(), 0)
	var rally: LevelDef = shipped.levels[0]
	assert_eq(rally.id, &"rally_road")
	assert_eq(rally.display_name, "Rally Road")
	assert_true(ResourceLoader.exists(rally.scene_path), "its scene exists")
	assert_gt(rally.two_star_time, rally.three_star_time, "two stars is the easier target")


func test_muddy_valley_follows_rally_road_and_unlocks_after_it() -> void:
	var shipped: LevelCatalog = load("res://levels/catalog.tres")
	assert_eq(shipped.levels.size(), 4)
	var muddy: LevelDef = shipped.levels[1]
	assert_eq(muddy.id, &"muddy_valley")
	assert_eq(muddy.display_name, "Muddy Valley")
	assert_true(ResourceLoader.exists(muddy.scene_path), "its scene exists")
	assert_gt(muddy.two_star_time, muddy.three_star_time, "two stars is the easier target")
	var progress := Progress.new()
	assert_false(progress.is_unlocked(shipped, muddy), "locked at first")
	progress.record_finish(shipped.levels[0], 90.0, {})
	assert_true(progress.is_unlocked(shipped, muddy), "unlocked by finishing Rally Road")


func test_frozen_pass_is_third_and_unlocks_after_muddy_valley() -> void:
	var shipped: LevelCatalog = load("res://levels/catalog.tres")
	var frozen: LevelDef = shipped.levels[2]
	assert_eq(frozen.id, &"frozen_pass")
	assert_eq(frozen.display_name, "Frozen Pass")
	assert_true(ResourceLoader.exists(frozen.scene_path))
	assert_eq(frozen.two_star_time, 135.0, "placeholder pending owner playtest")
	assert_eq(frozen.three_star_time, 120.0)
	var progress := Progress.new()
	assert_false(progress.is_unlocked(shipped, frozen))
	progress.record_finish(shipped.levels[0], 90.0, {})
	assert_false(progress.is_unlocked(shipped, frozen), "Rally Road alone is not enough")
	progress.record_finish(shipped.levels[1], 100.0, {})
	assert_true(progress.is_unlocked(shipped, frozen))


func test_rock_canyon_is_fourth_and_unlocks_after_frozen_pass() -> void:
	var shipped: LevelCatalog = load("res://levels/catalog.tres")
	var canyon: LevelDef = shipped.levels[3]
	assert_eq(canyon.id, &"rock_canyon")
	assert_eq(canyon.display_name, "Rock Canyon")
	assert_true(ResourceLoader.exists(canyon.scene_path))
	assert_eq(canyon.two_star_time, 285.0, "placeholder pending owner playtest")
	assert_eq(canyon.three_star_time, 255.0)
	assert_eq(canyon.recommended_car, &"offroad_4x4")
	var progress := Progress.new()
	for level in shipped.levels.slice(0, 2):
		progress.record_finish(level, 100.0, {})
	assert_false(progress.is_unlocked(shipped, canyon), "two levels are not enough")
	progress.record_finish(shipped.levels[2], 100.0, {})
	assert_true(progress.is_unlocked(shipped, canyon))


func test_a_saved_level_scene_missing_from_the_catalog_is_flagged() -> void:
	assert_true(RunLevel.is_missing_from_catalog("res://levels/lost/lost.tscn", null))
	assert_false(RunLevel.is_missing_from_catalog("", null), "a level built in code by a test")
	assert_false(RunLevel.is_missing_from_catalog("res://a.tscn", catalog.levels[0]), "a catalog level")
