class_name WaterWaveSampler
extends RefCounted
## Exact drawn-triangle sampling; optional Test Ground binding, never a collider.

var topology: WaterWaveMesh
var snapshot: WaterWaveSnapshot
var evaluated_vertices := 0
var _serials := PackedInt64Array()
var _values := PackedFloat32Array()
var _height := WaterWaveHeight.new()
var _prepared_serial := -2


func configure(top: WaterWaveMesh, data: WaterWaveSnapshot) -> void:
	topology = top
	snapshot = data
	_serials.resize(top.vertices.size())
	_serials.fill(-2)
	_values.resize(top.vertices.size())
	evaluated_vertices = 0
	_prepared_serial = -2


func height_at(at: Vector2) -> float:
	var located := topology.locate(at)
	var triangle := int(located.w)
	if triangle < 0:
		return -INF
	var result := topology.level
	for corner in 3:
		result += located[corner] * vertex_offset(topology.indices[triangle * 3 + corner])
	return result


func vertex_offset(index: int) -> float:
	if _serials[index] != snapshot.serial:
		if _prepared_serial != snapshot.serial:
			_height.prepare(snapshot)
			_prepared_serial = snapshot.serial
		var at := topology.vertices[index]
		_values[index] = _height.bounded(Vector2(at.x, at.z), topology.limits[index])
		_serials[index] = snapshot.serial
		evaluated_vertices += 1
	return _values[index]
