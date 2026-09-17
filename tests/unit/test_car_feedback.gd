extends GutTest
## The spray and sound nodes (M3B spec §4.2, §5.5, §5.6, §6): a wheel spray
## switches and hides itself, the driving rig carries the car's effects and sound,
## a reset quiets them, and a level's ambience plays wind and birds.

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")
const FEELS := preload("res://effects/surface_feel_table.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func test_a_spray_emits_switches_kind_and_hides_when_idle() -> void:
	var spray := WheelSpray.new()
	add_child_autofree(spray)
	assert_false(spray.visible, "idle sprays start hidden")
	spray.update(FEELS.feel_for(DIRT), 0.8, 0.016)
	assert_true(spray.emitting)
	assert_true(spray.visible)
	assert_eq(spray.kind, SurfaceFeel.SprayKind.DUST)
	assert_almost_eq(spray.lifetime, 1.2, 0.001)
	spray.update(FEELS.feel_for(MUD), 0.8, 0.016)
	assert_eq(spray.kind, SurfaceFeel.SprayKind.CLODS)
	assert_almost_eq(spray.lifetime, 0.7, 0.001)
	spray.update(FEELS.feel_for(MUD), 0.01, 0.5)
	assert_false(spray.emitting, "below the threshold it stops")
	assert_true(spray.visible, "its last particles are still flying")
	spray.update(null, 0.0, 0.5)
	assert_false(spray.visible, "hidden once idle longer than its particles live")


func test_a_reset_stops_a_spray_at_once() -> void:
	var spray := WheelSpray.new()
	add_child_autofree(spray)
	spray.update(FEELS.feel_for(MUD), 1.0, 0.016)
	spray.stop_now()
	assert_false(spray.emitting)
	assert_false(spray.visible)


func test_the_rig_carries_sprays_and_sound_and_a_reset_quiets_them() -> void:
	var rig: DrivingRig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	assert_eq(rig.effects.sprays.size(), 4, "one spray per wheel")
	assert_eq(rig.audio.players.size(), 9)
	for sound_name in CarAudio.LOOPS:
		assert_true((rig.audio.players[sound_name] as AudioStreamPlayer).playing, sound_name)
	rig.effects.sprays[2].update(FEELS.feel_for(MUD), 1.0, 0.016)
	rig.place_car(Transform3D(Basis(), Vector3(0.0, 2.0, 0.0)))
	assert_false(rig.effects.sprays[2].visible, "the reset stopped the spray")
	assert_true(rig.audio.impacts_muted(), "and holds back thumps for a moment")


func test_a_car_on_its_own_makes_no_sound() -> void:
	var car: Car = load("res://car/car.tscn").instantiate()
	add_child_autofree(car)
	assert_true(car.find_children("*", "AudioStreamPlayer", true, false).is_empty())


func test_ambience_plays_wind_and_birds_now_and_then() -> void:
	var ambience := LevelAmbience.new()
	ambience.bird_interval = Vector2(0.05, 0.1)
	add_child_autofree(ambience)
	assert_true(ambience.wind.playing)
	await wait_seconds(0.5)
	assert_gt(ambience.birds_played, 1)
	var quiet := LevelAmbience.new()
	quiet.birds = false
	quiet.bird_interval = Vector2(0.05, 0.1)
	add_child_autofree(quiet)
	await wait_seconds(0.3)
	assert_eq(quiet.birds_played, 0)
