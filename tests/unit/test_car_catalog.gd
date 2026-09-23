extends GutTest
## The car catalog, its unlocks, and the three shipped cars (spec §3).

var catalog: CarCatalog


func _car(id: StringName, stars: int) -> CarDef:
	var car := CarDef.new()
	car.id = id
	car.unlock_stars = stars
	return car


func _ids(cars: Array[CarDef]) -> Array:
	return cars.map(func(car: CarDef) -> StringName: return car.id)


func before_each() -> void:
	catalog = CarCatalog.new()
	catalog.cars = [_car(&"a", 0), _car(&"b", 3), _car(&"c", 5)]


func test_finds_cars_by_id() -> void:
	assert_eq(catalog.find_by_id(&"b"), catalog.cars[1])
	assert_null(catalog.find_by_id(&"missing"))


func test_total_stars_unlock_cars_in_order() -> void:
	assert_eq(_ids(catalog.unlocked(0)), [&"a"])
	assert_eq(_ids(catalog.unlocked(2)), [&"a"])
	assert_eq(_ids(catalog.unlocked(3)), [&"a", &"b"])
	assert_eq(_ids(catalog.unlocked(6)), [&"a", &"b", &"c"])


func test_newly_unlocked_cars_are_the_ones_a_finish_crosses() -> void:
	assert_eq(_ids(catalog.newly_unlocked(2, 3)), [&"b"])
	assert_eq(_ids(catalog.newly_unlocked(2, 6)), [&"b", &"c"])
	assert_eq(_ids(catalog.newly_unlocked(3, 4)), [], "the 3-star car was already unlocked")
	assert_eq(_ids(catalog.newly_unlocked(5, 5)), [], "no new stars")


func test_the_shipped_catalog_has_the_three_cars() -> void:
	var shipped: CarCatalog = load("res://car/car_catalog.tres")
	assert_eq(_ids(shipped.cars), [&"rally", &"offroad_4x4", &"rally_tuned"])
	assert_eq(shipped.cars.map(func(car: CarDef) -> int: return car.unlock_stars), [0, 3, 5])
	for car in shipped.cars:
		assert_not_null(car.stats, "%s has stats" % car.id)
		assert_not_null(car.body, "%s has a body" % car.id)
		assert_false(car.description.is_empty(), "%s has a description" % car.id)
	assert_eq(shipped.cars[0].stats.resource_path, "res://car/rally_car.tres", "the stock Rally Car keeps its stats")


func test_the_new_cars_differ_from_stock_as_designed() -> void:
	var shipped: CarCatalog = load("res://car/car_catalog.tres")
	var stock: CarStats = shipped.cars[0].stats
	var offroad: CarStats = shipped.cars[1].stats
	var tuned: CarStats = shipped.cars[2].stats
	# Every differential stays open on the road cars: the 4x4's locks are what
	# make it the one that crawls. A partly locked centre was tried in the
	# 2026-09-23 balance tuning and rejected (see the feel log): it added mud
	# understeer, and the torque split alone fixed the looseness.
	assert_eq([stock.front_diff_lock, stock.rear_diff_lock, stock.centre_diff_lock], [0.0, 0.0, 0.0], "stock stays open")
	assert_eq([tuned.front_diff_lock, tuned.rear_diff_lock, tuned.centre_diff_lock], [0.0, 0.0, 0.0], "tuned stays open")
	for i in stock.torque_curve_nm.size():
		assert_almost_eq(tuned.torque_curve_nm[i], stock.torque_curve_nm[i] * 1.3, 0.6, "tuned torque point %d is +30%%" % i)
	assert_lt(tuned.mass, stock.mass)
	assert_gt(tuned.tire_grip, stock.tire_grip)
	assert_eq(offroad.archetype, &"offroad")
	assert_eq(offroad.centre_diff_lock, 1.0)
	assert_gt(offroad.mass, stock.mass)
	assert_gt(offroad.suspension_length, stock.suspension_length)
	var grip: GripTable = load("res://surfaces/grip_table.tres")
	assert_gt(grip.multiplier(&"offroad", &"mud"), grip.multiplier(&"offroad", &"asphalt"), "the 4x4 prefers mud")
