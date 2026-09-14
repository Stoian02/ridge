class_name CarCatalog
extends Resource
## The selectable cars in display order (spec §3.1). The first is the starter car.

@export var cars: Array[CarDef] = []


func find_by_id(id: StringName) -> CarDef:
	for car in cars:
		if car.id == id:
			return car
	return null


## The cars `total_stars` unlocks, in display order.
func unlocked(total_stars: int) -> Array[CarDef]:
	var result: Array[CarDef] = []
	for car in cars:
		if total_stars >= car.unlock_stars:
			result.append(car)
	return result


## The cars that going from `stars_before` to `stars_after` total stars unlocks.
func newly_unlocked(stars_before: int, stars_after: int) -> Array[CarDef]:
	var result: Array[CarDef] = []
	for car in cars:
		if stars_before < car.unlock_stars and stars_after >= car.unlock_stars:
			result.append(car)
	return result
