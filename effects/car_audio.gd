class_name CarAudio
extends Node
## The car's sound (spec §5.5): two engine layers, the road, gravel, mud and skid
## loops, and a thump for hard hits. Each frame it reads the car and sets every
## player's pitch and volume. Its players pause with the game.

const LOOPS: Array[StringName] = [&"engine_low", &"engine_high", &"road", &"gravel", &"mud", &"skid", &"snow", &"rock"]
## Volumes move toward their targets this fast (linear units per second), so nothing clicks.
const EASE_PER_SECOND := 4.0
const SILENT := 0.01
const SILENT_DB := -80.0
const IMPACT_COOLDOWN := 0.25
const RESET_MUTE := 0.5
const THUMP_BASE := 0.35
const THUMP_RANGE := 0.65
const ROLL_PITCH_BASE := 0.8
const ROLL_PITCH_RANGE := 0.4
const ROLL_PITCH_SPEED := 30.0

var car: Car
## The car's CarEffects, whose `wheels` array this reads each frame instead of
## working out every wheel's motion a second time.
var effects: CarEffects
## StringName sound -> AudioStreamPlayer (the loops and the thump).
var players := {}
var thumps_played := 0

## StringName loop -> current linear volume.
var _volumes := {}
var _impact_wait := 0.0


func setup(driven: Car, car_effects: CarEffects) -> void:
	car = driven
	effects = car_effects
	for sound_name in LOOPS:
		var player := _add_player(sound_name)
		player.volume_db = SILENT_DB
		player.play()
		_volumes[sound_name] = 0.0
	_add_player(&"thump")


## The loop's current linear volume (0-1).
func volume(sound_name: StringName) -> float:
	return _volumes[sound_name]


## A car reset: no thump for a moment, since the car was just put down.
func notify_reset() -> void:
	_impact_wait = RESET_MUTE


## True while a thump would be held back (just after a thump or a reset).
func impacts_muted() -> bool:
	return _impact_wait > 0.0


## Stops every player on the way out, so the audio server lets go of their playbacks.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in players.values():
		player.stop()


func _process(delta: float) -> void:
	if car == null or car.drivetrain == null:
		return
	_impact_wait = maxf(0.0, _impact_wait - delta)
	var engine := EngineSoundLogic.layers(car.drivetrain.rpm, car.input.throttle, car.drivetrain.is_shifting())
	_set_loop(&"engine_low", engine["low_volume"], engine["low_pitch"], delta)
	_set_loop(&"engine_high", engine["high_volume"], engine["high_pitch"], delta)

	var hardest := 0.0
	for wheel in car.wheels:
		if wheel.in_contact:
			var bottomed := ImpactLogic.is_bottomed_out(wheel.compression, wheel.stats.suspension_length)
			hardest = maxf(hardest, ImpactLogic.strength(wheel.compression_speed, bottomed))
	var tyres := TyreSoundLogic.mix(effects.wheels)
	var roll_pitch := ROLL_PITCH_BASE + ROLL_PITCH_RANGE * clampf(absf(car.forward_speed()) / ROLL_PITCH_SPEED, 0.0, 1.0)
	_set_loop(&"road", tyres["road"], roll_pitch, delta)
	_set_loop(&"gravel", tyres["gravel"], roll_pitch, delta)
	_set_loop(&"mud", tyres["mud"], roll_pitch, delta)
	_set_loop(&"snow", tyres["snow"], roll_pitch, delta)
	_set_loop(&"rock", tyres["rock"], roll_pitch, delta)
	_set_loop(&"skid", tyres["skid"], 1.0, delta)

	if hardest > 0.0 and _impact_wait <= 0.0:
		var thump: AudioStreamPlayer = players[&"thump"]
		thump.volume_db = linear_to_db(THUMP_BASE + THUMP_RANGE * hardest)
		thump.play()
		thumps_played += 1
		_impact_wait = IMPACT_COOLDOWN


func _set_loop(sound_name: StringName, target: float, pitch: float, delta: float) -> void:
	var level := move_toward(_volumes[sound_name], clampf(target, 0.0, 1.0), EASE_PER_SECOND * delta)
	_volumes[sound_name] = level
	var player: AudioStreamPlayer = players[sound_name]
	player.volume_db = linear_to_db(level) if level > SILENT else SILENT_DB
	player.pitch_scale = maxf(pitch, 0.01)


func _add_player(sound_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = String(sound_name).to_pascal_case()
	player.stream = SoundSynth.sound(sound_name)
	add_child(player)
	players[sound_name] = player
	return player
