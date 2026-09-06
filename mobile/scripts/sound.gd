extends Node
## Small original synthesized effects. No external recordings or audio plugins.

var enabled := true
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var boss_music_active := false
var paused := false
var music := AudioStreamPlayer.new()
static var music_stream: AudioStreamWAV

func _ready() -> void:
	streams["shot"] = tone(1150, 430, 0.07, 0.0)
	streams["burst"] = tone(230, 60, 0.19, 0.45)
	streams["hit"] = tone(150, 35, 0.35, 0.6)
	streams["win"] = tone(440, 880, 0.6, 0.0)
	streams["rift"] = rift_boom()
	streams["pickup"] = tone(520, 1300, 0.22, 0.0)
	streams["laser"] = tone(820, 240, 0.13, 0.1)
	streams["rocket"] = tone(150, 45, 0.18, 0.25)
	music.volume_db = -16.0
	add_child(music)
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
	boss_music_active = false
	music.stop()

func set_boss_music(active: bool) -> void:
	boss_music_active = active
	sync_enabled()

func set_paused(value: bool) -> void:
	paused = value
	if paused:
		for voice in voices:
			voice.stop()
	sync_enabled()

func sync_enabled() -> void:
	if not enabled:
		for voice in voices:
			voice.stop()
	if not enabled or not boss_music_active:
		music.stop()
		return
	if not music.playing:
		if music_stream == null:
			music_stream = make_boss_music()
		music.stream = music_stream
		music.play()
	music.stream_paused = paused

func make_boss_music() -> AudioStreamWAV:
	# Original eight-second loop: minor bass ostinato, pulse, kick and hats.
	var sample_rate := 22050
	var count := sample_rate * 8
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var notes := [0, 0, 7, 0, 3, 3, 10, 7, 0, 0, 7, 12, 3, 7, 10, 7]
	var random := RandomNumberGenerator.new()
	random.seed = 121
	for i in range(count):
		var t := float(i) / sample_rate
		var beat := fmod(t, 0.5)
		var note_time := fmod(t, 0.25)
		var index := int(t * 2.0) % notes.size()
		var hz := 55.0 * pow(2.0, float(notes[index]) / 12.0)
		var bass := (sin(TAU * hz * beat) + sin(TAU * hz * 2.0 * beat) * 0.25) * exp(-beat * 5.0) * minf(beat * 100.0, 1.0)
		var kick := sin(TAU * (45.0 * beat + 9.0 * (1.0 - exp(-beat * 25.0)))) * exp(-beat * 19.0)
		var hat := random.randf_range(-1.0, 1.0) * exp(-note_time * 95.0)
		var pad := (sin(TAU * 110.0 * t) + sin(TAU * 165.0 * t)) * 0.06
		var wave := bass * 0.42 + kick * 0.32 + hat * 0.08 + pad
		bytes.encode_s16(i * 2, int(clampf(wave, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream

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
