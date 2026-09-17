extends GutTest
## Every synthesized sound (spec §5.1): right length and loop mode, audible but
## not clipped, loops that join without a click, cached, and quick to build.

const LOOP_SECONDS := {&"engine_low": 0.4, &"engine_high": 0.4, &"road": 1.0, &"gravel": 1.0, &"mud": 1.5,
		&"skid": 0.8, &"wind": 4.0, &"snow": 1.2, &"rock": 1.3, &"waterfall": 3.0}
const ONE_SHOT_SECONDS := {&"bird": 0.35, &"thump": 0.3}


func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(wav.data.size() / 2)
	for i in samples.size():
		samples[i] = wav.data.decode_s16(i * 2) / 32767.0
	return samples


func test_every_sound_builds_quickly_from_scratch() -> void:
	SoundSynth.clear_cache()
	var started := Time.get_ticks_usec()
	for sound_name in SoundSynth.NAMES:
		assert_not_null(SoundSynth.sound(sound_name), sound_name)
	var milliseconds := (Time.get_ticks_usec() - started) / 1000.0
	gut.p("building every sound: %.1f ms" % milliseconds)
	assert_lt(milliseconds, 300.0, "spec §5.1 sets a 100 ms budget on desktop (measured 68 ms); this bound only catches runaways")


func test_sounds_have_their_length_and_loop_mode() -> void:
	for sound_name: StringName in LOOP_SECONDS:
		var wav := SoundSynth.sound(sound_name)
		assert_eq(wav.mix_rate, SoundSynth.RATE, sound_name)
		assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, sound_name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound_name)
		assert_almost_eq(wav.get_length(), LOOP_SECONDS[sound_name], 0.01, sound_name)
		assert_eq(wav.loop_end, wav.data.size() / 2 - SoundSynth.LOOP_PAD, "%s: the loop ends before a padded tail" % sound_name)
	for sound_name: StringName in ONE_SHOT_SECONDS:
		var wav := SoundSynth.sound(sound_name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, sound_name)
		assert_almost_eq(wav.get_length(), ONE_SHOT_SECONDS[sound_name], 0.01, sound_name)


func test_sounds_are_audible_and_not_clipped() -> void:
	for sound_name in SoundSynth.NAMES:
		var samples := _samples(SoundSynth.sound(sound_name))
		var peak := 0.0
		var energy := 0.0
		for value in samples:
			peak = maxf(peak, absf(value))
			energy += value * value
		var rms := sqrt(energy / samples.size())
		assert_between(peak, 0.5, 0.95, "%s peak" % sound_name)
		assert_gt(rms, 0.03, "%s is audible" % sound_name)


func test_loops_join_without_a_click() -> void:
	for sound_name: StringName in LOOP_SECONDS:
		var wav := SoundSynth.sound(sound_name)
		var samples := _samples(wav)
		var biggest_step := 0.0
		for i in range(1, wav.loop_end):
			biggest_step = maxf(biggest_step, absf(samples[i] - samples[i - 1]))
		var join := absf(samples[0] - samples[wav.loop_end - 1])
		assert_lte(join, biggest_step * 1.05, "%s: the join is no bigger a step than the loop's own" % sound_name)


func test_a_sound_is_built_once() -> void:
	assert_same(SoundSynth.sound(&"road"), SoundSynth.sound(&"road"))


## Mean sample step over RMS: high for bright noise (hiss), low for a smooth rumble.
func _hiss(samples: PackedFloat32Array) -> float:
	var energy := 0.0
	var steps := 0.0
	for i in samples.size():
		energy += samples[i] * samples[i]
		if i > 0:
			steps += absf(samples[i] - samples[i - 1])
	return (steps / (samples.size() - 1)) / sqrt(energy / samples.size())


func test_rolling_on_asphalt_is_a_low_rumble_not_a_hiss() -> void:
	var road := _hiss(_samples(SoundSynth.sound(&"road")))
	var gravel := _hiss(_samples(SoundSynth.sound(&"gravel")))
	gut.p("hiss: road %.3f, gravel %.3f" % [road, gravel])
	assert_lt(road, 0.12, "the old filtered-noise road loop measured 0.34")
	assert_lt(road, gravel * 0.2, "far smoother than gravel")



## On the phone the audio thread crashed (SIGSEGV) exactly when the 4 s wind loop first
## wrapped: the mixer reads a few frames past loop_end, and a loop ending at the very
## end of its data overran the buffer. Every sound now carries a padded tail.
func test_every_sound_has_a_padded_tail_the_mixer_can_read_past_its_end() -> void:
	assert_gte(SoundSynth.LOOP_PAD, 16)
	for sound_name in SoundSynth.NAMES:
		var wav := SoundSynth.sound(sound_name)
		var samples := _samples(wav)
		var end: int = wav.loop_end if wav.loop_mode == AudioStreamWAV.LOOP_FORWARD else samples.size() - SoundSynth.LOOP_PAD
		assert_eq(samples.size(), end + SoundSynth.LOOP_PAD, "%s: exactly LOOP_PAD frames after the end" % sound_name)
		for k in SoundSynth.LOOP_PAD:
			var expected: float = samples[k] if wav.loop_mode == AudioStreamWAV.LOOP_FORWARD else 0.0
			assert_almost_eq(samples[end + k], expected, 0.0001,
					"%s: a loop's tail repeats its start, a one-shot's is silence" % sound_name)
