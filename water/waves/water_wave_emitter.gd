class_name WaterWaveEmitter
extends Node
## Reads the completed 13-probe controller state, without re-querying the bed.

var car: Car
var runtime: WaterWaveRuntime
var source := WaterWaveSource.new()
var observation := WaterWaveSource.Observation.new()
var step_usec := 0
var _weights := PackedFloat32Array()


func _ready() -> void:
	process_physics_priority = 50


func setup(driven: Car, clock: WaterWaveRuntime) -> void:
	car = driven
	runtime = clock
	_weights.resize(runtime.views.size())


func _view_index(id: StringName) -> int:
	for index in runtime.views.size():
		if runtime.views[index].body_id == id:
			return index
	return -1


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_observe()
	source.step(delta, observation, runtime.field)
	step_usec = Time.get_ticks_usec() - started


func _observe() -> void:
	observation.body_id = &""
	observation.body_immersion = 0.0
	observation.wheel_immersion = 0.0
	observation.velocity = Vector3.ZERO
	_weights.fill(0.0)
	var water := car.water
	for index in 8:
		var sample := water.body_samples[index]
		var view_index := _view_index(sample.body_id) if sample.valid else -1
		if view_index >= 0:
			_weights[view_index] += WaterForces.probe_fraction(water.body_positions[index].y,
				water.probe_radius, sample.rest_surface_y, sample.bed_y, sample.edge_weight)
	for index in 4:
		var sample := water.wheel_samples[index]
		var view_index := _view_index(sample.body_id) if sample.valid else -1
		if view_index >= 0:
			_weights[view_index] += WaterForces.wheel_fraction(water.wheel_positions[index].y,
				water.wheel_extents[index], sample.rest_surface_y, sample.bed_y, sample.edge_weight) * 0.15
	var chosen := -1
	var weight := 0.0
	for index in _weights.size():
		if _weights[index] > weight:
			chosen = index
			weight = _weights[index]
	if chosen < 0:
		return
	var view := runtime.views[chosen]
	var centre := Vector3.ZERO
	var current := Vector3.ZERO
	var total := 0.0
	var highest := -INF
	var rest_y := view.sampler.topology.level + view.origin.y
	for index in 8:
		var point := water.body_positions[index]
		highest = maxf(highest, point.y + water.probe_radius)
		var sample := water.body_samples[index]
		if not sample.valid or sample.body_id != view.body_id:
			continue
		var fraction := WaterForces.probe_fraction(point.y, water.probe_radius,
			sample.rest_surface_y, sample.bed_y, sample.edge_weight)
		observation.body_immersion += fraction / 8.0
		centre += point * fraction
		current += sample.current * fraction
		total += fraction
	for index in 4:
		var sample := water.wheel_samples[index]
		if not sample.valid or sample.body_id != view.body_id:
			continue
		var point := water.wheel_positions[index]
		var fraction := WaterForces.wheel_fraction(point.y, water.wheel_extents[index],
			sample.rest_surface_y, sample.bed_y, sample.edge_weight)
		observation.wheel_immersion += fraction / 4.0
		centre += point * fraction * 0.15
		current += sample.current * fraction * 0.15
		total += fraction * 0.15
	if total <= 0.0:
		return
	centre = centre / total - view.origin
	current /= total
	observation.at = Vector2(centre.x, centre.z)
	# Averages can lie in a concave dry corner: sources must still be in the top.
	if view.sampler.topology.triangle_at(observation.at) < 0:
		return
	observation.body_id = view.body_id
	observation.velocity = car.linear_velocity - current
	observation.current = Vector2(current.x, current.z)
	observation.size = car.stats.body_size
	observation.upper_clearance = highest - rest_y
	var horizontal := Vector2(observation.velocity.x, observation.velocity.z)
	var direction := horizontal.normalized() if horizontal.length_squared() > 0.000001 else Vector2.UP
	var forward := Vector2(car.global_basis.z.x, car.global_basis.z.z)
	var right := Vector2(car.global_basis.x.x, car.global_basis.x.z)
	var reach := 0.5 * (absf(direction.dot(forward)) * observation.size.z \
		+ absf(direction.dot(right)) * observation.size.x)
	var lateral := Vector2(-direction.y, direction.x)
	# Cross-flow span includes the long side of a sliding car, not just its width.
	observation.bow_width = absf(lateral.dot(forward)) * observation.size.z \
		+ absf(lateral.dot(right)) * observation.size.x
	observation.bow_sweep = clampf(reach * 0.75, 0.6, 2.0)
	var local_car := car.global_position - view.origin
	var middle := Vector2(local_car.x, local_car.z)
	observation.bow_at = middle + direction * (reach + 0.25)
	observation.wake_at = middle - direction * reach
	if view.sampler.topology.triangle_at(observation.bow_at) < 0:
		observation.bow_at = observation.at
	if view.sampler.topology.triangle_at(observation.wake_at) < 0:
		observation.wake_at = observation.at
