extends GutTest


func _wet() -> WaterWaveSource.Observation:
	var observation := WaterWaveSource.Observation.new()
	observation.body_id = &"pool"
	observation.body_immersion = 0.4
	observation.wheel_immersion = 1.0
	observation.upper_clearance = 0.1
	observation.velocity = Vector3(0.0, 0.0, 8.0)
	observation.size = Vector3(1.8, 1.0, 4.0)
	observation.bow_at = Vector2(0.0, 2.0)
	observation.wake_at = Vector2(0.0, -2.0)
	return observation


func test_spawn_and_bobbing_never_retrigger_entry_but_dry_rearm_does() -> void:
	var source := WaterWaveSource.new()
	var field := WaterWaveField.new()
	var wet := _wet()
	for tick in 120:
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	assert_eq(source.entries, 0, "underwater spawn seeds history")
	wet.body_immersion = 0.01
	for tick in 60:
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	wet.body_immersion = 0.1
	source.step(1.0 / 120.0, wet, field)
	assert_eq(source.entries, 1)
	field.step(0.0)
	var entry := WaterWaveSnapshot.new()
	field.write_snapshot(&"pool", false, entry)
	assert_almost_eq(entry.directions[0].w, -wet.size.x * 0.5, 0.000001)
	for tick in 240:
		wet.body_immersion = 0.04 if tick % 2 == 0 else 0.06
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	assert_eq(source.entries, 1, "ordinary crossing chatter cannot rearm")
	source.reset()
	source.step(1.0 / 120.0, wet, field)
	assert_eq(source.entries, 0)


func test_prescribed_motion_cadence_matches_60_and_120_and_stops_at_relative_rest() -> void:
	var counts: Array[int] = []
	for hz: int in [60, 120]:
		var source := WaterWaveSource.new()
		var field := WaterWaveField.new()
		var wet := _wet()
		source.step(0.0, wet, field)
		for tick in hz * 3:
			source.step(1.0 / hz, wet, field)
			field.step(1.0 / hz)
		counts.append(source.wakes)
		assert_eq(source.wakes, 10)
		wet.velocity = Vector3.ZERO
		for tick in hz * 5:
			source.step(1.0 / hz, wet, field)
			field.step(1.0 / hz)
		assert_eq(source.wakes, 10, "throttle/wheel spin are not source inputs")
		assert_eq(field.active_count(), 0)
		assert_lt(field._bow_value, 0.000001)
	assert_eq(counts[0], counts[1])


func test_deep_fade_reverse_direction_and_body_isolation() -> void:
	var source := WaterWaveSource.new()
	var field := WaterWaveField.new()
	var wet := _wet()
	wet.velocity = Vector3(-8.0, 0.0, 0.0)
	source.step(0.0, wet, field)
	for tick in 60:
		source.step(1.0 / 60.0, wet, field)
		field.step(1.0 / 60.0)
	assert_eq(field._bow_direction, Vector2.LEFT)
	assert_gt(source.wakes, 0)
	var count := source.wakes
	wet.body_id = &"other"
	wet.upper_clearance = -0.61
	for tick in 60:
		source.step(1.0 / 60.0, wet, field)
		field.step(1.0 / 60.0)
	assert_eq(source.wakes, count, "deeply submerged sources cannot stir distant surface")
	for slot: WaterWaveField.Packet in field._slots:
		if slot.active:
			assert_eq(slot.body_id, &"pool")


## An entry throws water the way the car is already going: the bow crest, which
## sits ahead of the hull, is boosted briefly on top of the symmetric ring.
func test_entry_leans_the_crest_toward_travel_and_the_boost_fades() -> void:
	var field := WaterWaveField.new()
	var wet := _wet()
	var steady := WaterWaveSource.new()
	# A car already in the water, at the same speed, is the comparison.
	for tick in 240:
		steady.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	field.step(0.0)
	var settled := WaterWaveSnapshot.new()
	field.write_snapshot(&"pool", false, settled)
	var cruising: float = settled.bow.z

	var entering := WaterWaveField.new()
	var source := WaterWaveSource.new()
	var dry := _wet()
	dry.body_immersion = 0.0
	for tick in 120:
		source.step(1.0 / 120.0, dry, entering)
		entering.step(1.0 / 120.0)
	source.step(1.0 / 120.0, wet, entering)
	assert_eq(source.entries, 1, "the entry ring is still emitted")
	# The crest ramps in over bow_rise_seconds, so the boost shows as a peak
	# over the following moments rather than on the entry tick itself.
	var peak := 0.0
	for tick in 36:
		entering.step(1.0 / 120.0)
		var rising := WaterWaveSnapshot.new()
		entering.write_snapshot(&"pool", false, rising)
		peak = maxf(peak, rising.bow.z)
		source.step(1.0 / 120.0, wet, entering)
	assert_gt(peak, cruising, "entering leans the crest forward harder than cruising does")
	assert_lte(peak, entering.profile.bow_amplitude + entering.profile.entry_kick_amplitude,
			"the boost stays inside its own ceiling")

	# Allow the boost to expire and the crest itself to fall back (bow_fall_seconds).
	for tick in int((entering.profile.entry_kick_seconds + 1.5) * 120.0):
		source.step(1.0 / 120.0, wet, entering)
		entering.step(1.0 / 120.0)
	entering.step(0.0)
	var faded := WaterWaveSnapshot.new()
	entering.write_snapshot(&"pool", false, faded)
	assert_almost_eq(faded.bow.z, cruising, 0.002, "the boost fades back to the cruising crest")


## Consecutive wake packets straddle the centre line, so the trail spreads into
## a V instead of a single file of rings behind the car.
func test_wake_packets_alternate_across_the_travel_line() -> void:
	var field := WaterWaveField.new()
	var source := WaterWaveSource.new()
	var wet := _wet()
	var sides: Array[float] = []
	for tick in 600:
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
		if source.wakes > sides.size():
			field.step(0.0)
			var snapshot := WaterWaveSnapshot.new()
			field.write_snapshot(&"pool", false, snapshot)
			var latest := Vector2.ZERO
			var newest := INF
			for index in range(WaterWaveProfile.ENTRY_SLOTS, WaterWaveProfile.PACKET_SLOTS):
				var packet := snapshot.packets[index]
				if packet.w > 0.0 and packet.z < newest:
					newest = packet.z
					latest = Vector2(packet.x, packet.y)
			# Travel is +Z, so the across-track axis is X.
			sides.append(signf(latest.x - wet.wake_at.x))
	assert_gt(sides.size(), 3, "several wake packets were emitted")
	for index in range(1, sides.size()):
		assert_ne(sides[index], sides[index - 1], "wake packet %d swaps side" % index)
		assert_ne(sides[index], 0.0, "each packet is offset from the centre line")
