class_name LevelAmbience
extends Node
## A level's outdoor sound bed (spec §5.6): a wind loop, and now and then a bird.
## Its random numbers are seeded, so tests can count on them.

@export_range(0.0, 1.0) var wind_volume: float = 0.35
@export var birds: bool = true
## Seconds between birds, from x to y.
@export var bird_interval: Vector2 = Vector2(6.0, 16.0)
@export var seed: int = 1

const BIRD_PITCH := Vector2(0.85, 1.25)
const BIRD_VOLUME := Vector2(0.2, 0.45)

var wind: AudioStreamPlayer
var bird: AudioStreamPlayer
var birds_played := 0

var _rng := RandomNumberGenerator.new()
var _until_bird := 0.0


func _ready() -> void:
	_rng.seed = seed
	wind = AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = SoundSynth.sound(&"wind")
	wind.volume_db = linear_to_db(maxf(wind_volume, 0.0001))
	add_child(wind)
	wind.play()
	bird = AudioStreamPlayer.new()
	bird.name = "Bird"
	bird.stream = SoundSynth.sound(&"bird")
	add_child(bird)
	_until_bird = _rng.randf_range(bird_interval.x, bird_interval.y)


## Stops both players on the way out, so the audio server lets go of their playbacks.
func _exit_tree() -> void:
	wind.stop()
	bird.stop()


func _process(delta: float) -> void:
	if not birds:
		return
	_until_bird -= delta
	if _until_bird > 0.0:
		return
	bird.pitch_scale = _rng.randf_range(BIRD_PITCH.x, BIRD_PITCH.y)
	bird.volume_db = linear_to_db(_rng.randf_range(BIRD_VOLUME.x, BIRD_VOLUME.y))
	bird.play()
	birds_played += 1
	_until_bird = _rng.randf_range(bird_interval.x, bird_interval.y)
