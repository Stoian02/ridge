class_name WaterWaveSampler
extends RefCounted
## Exact drawn-triangle sampling for fixtures; deliberately not bound to WaterWorld.

var topology: WaterWaveMesh
var snapshot: WaterWaveSnapshot
var evaluated_vertices := 0
var _serials := PackedInt64Array()
var _values := PackedFloat32Array()


func configure(top: WaterWaveMesh, data: WaterWaveSnapshot) -> void:
	topology = top
	snapshot = data
	_serials.resize(top.vertices.size())
	_serials.fill(-2)
	_values.resize(top.vertices.size())
	evaluated_vertices = 0


func height_at(at: Vector2) -> float:
	var triangle := topology.triangle_at(at)
	if triangle < 0:
		return -INF
	var weights := topology.barycentric(at, triangle)
	var result := topology.level
	for corner in 3:
		result += weights[corner] * vertex_offset(topology.indices[triangle * 3 + corner])
	return result


func vertex_offset(index: int) -> float:
	if _serials[index] != snapshot.serial:
		var at := topology.vertices[index]
		_values[index] = WaterWaveMath.bounded(WaterWaveMath.raw(Vector2(at.x, at.z), snapshot), topology.limits[index]).x
		_serials[index] = snapshot.serial
		evaluated_vertices += 1
	return _values[index]
