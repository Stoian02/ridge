class_name SoundSynth
extends RefCounted
## Every sound in the game, synthesized in code (spec §5.1): 16-bit mono at
## 22 050 Hz, built the first time it is asked for and kept for the session.
## Tone loops hold whole cycles; noise loops cross-fade their end into their start,
## so every loop repeats without a click.

const RATE := 22050
## Loops are normalized to this peak, one-shots to ONE_SHOT_PEAK.
const LOOP_PEAK := 0.7
const ONE_SHOT_PEAK := 0.9
## Noise loops cross-fade over this long (s).
const FADE_SECONDS := 0.1
## Every sound carries this many frames past its end: a copy of a loop's first frames,
## or silence after a one-shot. The mixer reads a few frames past loop_end while it
## interpolates; on the phone a loop ending at the very end of its data read past the
## buffer and crashed the audio thread when the 4 s wind loop first wrapped.
const LOOP_PAD := 32
const NAMES: Array[StringName] = [&"engine_low", &"engine_high", &"road", &"gravel", &"mud", &"skid", &"wind",
		&"bird", &"thump", &"snow", &"rock", &"waterfall"]

static var _cache := {}


## The sound called `sound_name` (one of NAMES).
static func sound(sound_name: StringName) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		_cache[sound_name] = _build(sound_name)
	return _cache[sound_name]


## Forgets every built sound, so the next request builds it again (tests time the build).
static func clear_cache() -> void:
	_cache.clear()


static func _build(sound_name: StringName) -> AudioStreamWAV:
	match sound_name:
		&"engine_low":
			return _wav(_normalized(_engine(50.0, 0.7, 11), LOOP_PEAK), true)
		&"engine_high":
			return _wav(_normalized(_engine(150.0, 1.0, 12), LOOP_PEAK), true)
		&"road":
			return _wav(_normalized(_seamless(_road(1.0)), LOOP_PEAK), true)
		&"gravel":
			return _wav(_normalized(_seamless(_gravel(1.0)), LOOP_PEAK), true)
		&"mud":
			return _wav(_normalized(_seamless(_mud(1.5)), LOOP_PEAK), true)
		&"snow":
			return _wav(_normalized(_seamless(_snow(1.2)), LOOP_PEAK), true)
		&"rock":
			return _wav(_normalized(_seamless(_rock(1.3)), LOOP_PEAK), true)
		&"waterfall":
			return _wav(_normalized(_seamless(_waterfall(3.0)), LOOP_PEAK), true)
		&"skid":
			return _wav(_normalized(_seamless(_skid(0.8)), LOOP_PEAK), true)
		&"wind":
			return _wav(_normalized(_seamless(_wind(4.0)), LOOP_PEAK), true)
		&"bird":
			return _wav(_normalized(_bird(), ONE_SHOT_PEAK), false)
		&"thump":
			return _wav(_normalized(_thump(), ONE_SHOT_PEAK), false)
	push_error("SoundSynth: no sound called %s" % sound_name)
	return null


## A four-cylinder engine tone: firing frequency with harmonics, a half-order rumble,
## and a little roughness that changes cycle to cycle. Holds 0.4 s of whole cycles.
static func _engine(firing_hz: float, brightness: float, seed: int) -> PackedFloat32Array:
	var cycle := roundi(RATE / firing_hz)
	var cycles := roundi(0.4 * firing_hz / 2.0) * 2
	var rng := _rng(seed)
	var roughness := PackedFloat32Array()
	for c in cycles:
		roughness.append(1.0 + rng.randf_range(-0.15, 0.15))
	var samples := PackedFloat32Array()
	samples.resize(cycle * cycles)
	for i in samples.size():
		var phase := float(i) / cycle
		var index := int(phase)
		var amplitude := lerpf(roughness[index], roughness[(index + 1) % cycles], phase - index)
		var w := TAU * phase
		samples[i] = amplitude * (sin(w) + 0.6 * brightness * sin(2.0 * w) + 0.35 * brightness * sin(3.0 * w)
				+ 0.2 * brightness * brightness * sin(4.0 * w) + 0.45 * sin(0.5 * w))
	return samples


## Tyres rolling on asphalt: a low rumble (noise low-passed twice) under a soft 110 Hz
## tread note that flutters three times a second. Whole cycles of both fit the loop.
static func _road(seconds: float) -> PackedFloat32Array:
	var rng := _rng(21)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		low += 0.03 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.15 * (low - lower)
		var tread := sin(TAU * 110.0 * t) * (0.55 + 0.45 * sin(TAU * 3.0 * t))
		samples[i] = lower + tread * 0.04
	return samples


static func _gravel(seconds: float) -> PackedFloat32Array:
	var rng := _rng(22)
	var samples := _padded(seconds)
	var low := 0.0
	var smooth := 0.0
	for i in samples.size():
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.3 * (noise - low)
		smooth += 0.5 * ((noise - low) - smooth)
		samples[i] = smooth
	# Crackles, kept clear of the cross-faded ends.
	var fade := _fade_samples()
	for click in 70:
		var at := rng.randi_range(fade, samples.size() - fade * 2)
		var sign := 1.0 if rng.randf() < 0.5 else -1.0
		for k in 50:
			samples[at + k] += sign * 0.9 * exp(-k / 8.0) * (1.0 if k % 2 == 0 else -0.6)
	return samples


static func _mud(seconds: float) -> PackedFloat32Array:
	var rng := _rng(23)
	var samples := _padded(seconds)
	var bubbles := PackedFloat32Array()
	for b in 16:
		bubbles.append(rng.randf_range(0.0, seconds))
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var swell := 0.35
		for at in bubbles:
			swell += exp(-pow((t - at) / 0.05, 2.0))
		low += 0.035 * (rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * swell + 0.25 * sin(TAU * 38.0 * t) * (swell - 0.35)
	return samples


## Soft, band-passed crunch, pulsing gently as the tread compresses packed snow.
static func _snow(seconds: float) -> PackedFloat32Array:
	var rng := _rng(27)
	var samples := _padded(seconds)
	var low := 0.0
	var band := 0.0
	for i in samples.size():
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.035 * (noise - low)
		band += 0.18 * (noise - low - band)
		var pulse := 0.7 + 0.3 * pow(sin(TAU * 5.0 * i / RATE), 2.0)
		samples[i] = tanh(band * 2.0) * pulse
	return samples


## Tyres grinding on rock: a low, twice-filtered rumble with irregular knocks
## (short decaying 60 Hz bursts) as the tread catches on edges. Kept clear of the
## cross-faded ends so the loop joins cleanly.
static func _rock(seconds: float) -> PackedFloat32Array:
	var rng := _rng(28)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	for i in samples.size():
		low += 0.12 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.3 * (low - lower)
		samples[i] = lower * 1.2
	var fade := _fade_samples()
	var knock := 400
	for k in 40:
		var at := rng.randi_range(fade, samples.size() - fade * 2 - knock)
		var amplitude := rng.randf_range(0.4, 1.0)
		for j in knock:
			samples[at + j] += amplitude * sin(TAU * 60.0 * j / RATE) * exp(-j / 90.0)
	return samples


## A waterfall: a bright hiss (noise minus its low band) over a deep rumble
## (noise low-passed twice), steady rather than gusting like the wind.
static func _waterfall(seconds: float) -> PackedFloat32Array:
	var rng := _rng(29)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	var band := 0.0
	for i in samples.size():
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.04 * (noise - low)
		lower += 0.08 * (low - lower)
		band += 0.35 * ((noise - low) - band)
		samples[i] = band * 0.6 + lower * 1.6
	return samples


static func _skid(seconds: float) -> PackedFloat32Array:
	var rng := _rng(24)
	var samples := _padded(seconds)
	var phase := 0.0
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (900.0 + 45.0 * sin(TAU * 7.0 * t)) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.4 * (noise - low)
		samples[i] = sin(phase) * 0.8 + sin(phase * 2.0) * 0.2 + (noise - low) * 0.3
	return samples


static func _wind(seconds: float) -> PackedFloat32Array:
	var rng := _rng(25)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		low += 0.02 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.05 * (low - lower)
		samples[i] = lower * (0.65 + 0.35 * sin(TAU * t / seconds))
	return samples


static func _bird() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.35 * RATE))
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		for start: float in [0.0, 0.17]:
			var u := (t - start) / 0.12
			if u >= 0.0 and u <= 1.0:
				phase += TAU * lerpf(2500.0, 4200.0, u) / RATE
				samples[i] += sin(phase) * sin(PI * u)
	return samples


static func _thump() -> PackedFloat32Array:
	var rng := _rng(26)
	var samples := PackedFloat32Array()
	samples.resize(int(0.3 * RATE))
	var phase := 0.0
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(70.0, 40.0, t / 0.3) / RATE
		low += 0.2 * (rng.randf_range(-1.0, 1.0) - low)
		samples[i] = sin(phase) * exp(-t * 14.0) + low * 0.8 * exp(-t * 40.0)
	return samples


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _fade_samples() -> int:
	return int(FADE_SECONDS * RATE)


## Room for `seconds` of loop plus the cross-fade tail.
static func _padded(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE) + _fade_samples())
	return samples


## Folds the tail past the loop length into the start, so the end runs straight on into the start.
static func _seamless(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade := _fade_samples()
	var length := samples.size() - fade
	var result := samples.slice(0, length)
	for i in fade:
		result[i] = lerpf(samples[length + i], samples[i], float(i) / fade)
	return result


static func _normalized(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var loudest := 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	if loudest <= 0.0:
		return samples
	var result := samples.duplicate()
	for i in result.size():
		result[i] = samples[i] * peak / loudest
	return result


static func _wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var frames := samples.size()
	var data := PackedByteArray()
	data.resize((frames + LOOP_PAD) * 2)
	for i in frames:
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	for k in LOOP_PAD:
		var tail: float = samples[k % frames] if looping else 0.0
		data.encode_s16((frames + k) * 2, int(clampf(tail, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames
	return wav
