extends Node
## Small original synthesized effects. No external recordings or audio plugins.

var enabled := true
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	streams["shot"] = tone(1150, 430, 0.07, 0.0)
	streams["burst"] = tone(230, 60, 0.19, 0.45)
	streams["hit"] = tone(150, 35, 0.35, 0.6)
	streams["win"] = tone(440, 880, 0.6, 0.0)
	streams["rift"] = rift_boom()
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -20.0
		add_child(voice)
		voices.append(voice)

func play_effect(effect: String) -> void:
	if not enabled or not streams.has(effect):
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = streams[effect]
	voice.play()

func silence() -> void:
	for voice in voices:
		voice.stop()

func tone(start_hz: float, end_hz: float, duration: float, noise: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 17
	for i in range(count):
		var t := float(i) / count
		phase += lerpf(start_hz, end_hz, t) / sample_rate
		var wave := lerpf(sin(phase * TAU), random.randf_range(-1, 1), noise)
		var envelope := minf(t * 30.0, 1.0) * pow(1.0 - t, 2.0)
		bytes.encode_s16(i * 2, int(wave * envelope * 26000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream

func rift_boom() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.88
	var count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var main_phase := 0.0
	var sub_phase := 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 31
	for i in range(count):
		var t := float(i) / count
		var bend := pow(t, 0.58)
		main_phase += lerpf(760.0, 48.0, bend) / sample_rate
		sub_phase += lerpf(120.0, 26.0, t) / sample_rate
		var main := sin(main_phase * TAU) * 0.68
		var sub := sin(sub_phase * TAU) * 0.42
		var grit := random.randf_range(-1.0, 1.0) * 0.18 * pow(1.0 - t, 1.5)
		var envelope := minf(t * 18.0, 1.0) * pow(1.0 - t, 1.35)
		bytes.encode_s16(i * 2, int((main + sub + grit) * envelope * 23000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream
