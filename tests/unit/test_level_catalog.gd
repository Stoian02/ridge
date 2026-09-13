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
