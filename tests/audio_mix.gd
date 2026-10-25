extends SceneTree
## Real-time mixer check: run --headless --audio-driver Dummy, without --fixed-fps.
## The capture is on Master, after the quiet SFX bus and per-cue faders.
var failures := 0
var checks := 0
var capture: AudioEffectCapture
var sound: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func record(cues: Array, duration: float, file: String) -> Dictionary:
	capture.clear_buffer()
	for cue in cues:
		sound.play_effect(cue)
	await create_timer(duration).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	var square_sum := 0.0
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.stereo = true
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 4)
	for i in samples.size():
		var frame: Vector2 = samples[i]
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		square_sum += frame.length_squared()
		pcm.encode_s16(i * 4, int(clampf(frame.x, -1, 1) * 32767))
		pcm.encode_s16(i * 4 + 2, int(clampf(frame.y, -1, 1) * 32767))
	wav.data = pcm
	wav.save_to_wav("user://" + file)
	var rms := sqrt(square_sum / maxf(samples.size() * 2, 1))
	return {"peak": peak, "rms": rms, "frames": samples.size()}

func run() -> void:
	await process_frame
	sound = root.get_node("SoundEffects")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.2
	var effect_slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	await create_timer(0.12).timeout
	var report: Dictionary = {}
	for cue in sound.CUES:
		var stream: AudioStream = sound.CUES[cue].stream
		var measured := await record([cue], stream.get_length() + 0.15, str(cue) + "_mixed.wav")
		report[str(cue)] = measured
		check(measured.frames > 1024 and measured.peak > 0.002, str(cue) + " reaches the actual audio output")
		check(measured.peak <= 0.14 and measured.rms <= 0.035, str(cue) + " stays quiet after both faders")
		print("AUDIO ", cue, ": ", JSON.stringify(measured))
	var overlapping := await record([&"mirror_flip", &"mirror_shatter", &"mirror_pass", &"crystal_green"], 1.9, "overlap_mixed.wav")
	report["overlap"] = overlapping
	check(overlapping.peak > 0.002 and overlapping.peak < 0.25, "four overlapping effects remain quiet and do not clip")
	var file := FileAccess.open("user://audio_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	AudioServer.remove_bus_effect(0, effect_slot)
	print("AUDIO MIX TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
