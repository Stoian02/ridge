class_name CoastalTerrainDef
extends Resource
## Independent north/south coastline, with land to its west (-X).
## Each knot is (world Z, shore X, plateau Y, cliff/shore blend width).
## Ordered in increasing Z, unrelated to road stations. No water or wet bed.

@export var shore: Array[Vector4] = []
@export var low_ground: float = -6.0
## Rounded inland hills as (world X, world Z, radius, added height).
@export var hills: Array[Vector4] = []
@export var relief: float = 1.2


func snapshot() -> Dictionary:
	return {"shore": shore.duplicate(), "low": low_ground,
		"hills": hills.duplicate(), "relief": relief}


func validation_error() -> String:
	if shore.size() < 2:
		return "Coast requires at least two shore knots"
	for i in shore.size():
		if shore[i].w <= 0.0 or shore[i].z <= low_ground:
			return "Coast width/plateau must exceed zero/low ground"
		if i > 0 and shore[i].x <= shore[i - 1].x:
			return "Coast knots must have strictly increasing world Z"
	for hill: Vector4 in hills:
		if hill.z <= 0.0:
			return "Coast hills require positive radii"
	return ""
