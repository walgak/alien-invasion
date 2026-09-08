extends Node
## Small original synthesized effects. No external recordings or audio plugins.

var enabled := true
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var boss_music_active := false
var flight_music_active := false
var paused := false
var music := AudioStreamPlayer.new()
var impact_voice := AudioStreamPlayer.new()
var hit_voice := AudioStreamPlayer.new()
var laser_voice := AudioStreamPlayer.new()
var laser_active := false
static var music_stream: AudioStreamWAV
static var flight_stream: AudioStreamWAV

## Godot calls this once after the node joins the scene; initialize child nodes and cached resources here.
func _ready() -> void:
	streams["shot"] = tone(180, 85, 0.10, 0.0)
	streams["burst"] = tone(110, 42, 0.28, 0.12)
	streams["hit"] = tone(90, 38, 0.35, 0.12)
	streams["win"] = tone(440, 880, 0.6, 0.0)
	streams["rift"] = rift_boom()
	streams["boss_death"] = rift_boom(1.3)
	streams["fold"] = tone(130, 55, 0.3, 0.05)
	streams["pickup"] = tone(110, 220, 0.22, 0.0)
	streams["laser"] = tone(160, 70, 0.13, 0.04)
	streams["rocket"] = tone(95, 40, 0.18, 0.1)
	impact_voice.volume_db = -10.0
	add_child(impact_voice)
	hit_voice.volume_db = -10.0
	add_child(hit_voice)
	laser_voice.volume_db = -23.0
	laser_voice.stream = electric_loop()
	add_child(laser_voice)
	music.volume_db = -16.0
	add_child(music)
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -20.0
		add_child(voice)
		voices.append(voice)

## Route a cached sound to its playback channel; dedicated channels protect hits and deep impacts from gunfire.
func play_effect(effect: String) -> void:
	if not enabled or not streams.has(effect):
		return
	if effect in ["rift", "boss_death"]:
		impact_voice.stream = streams[effect]
		impact_voice.play()
		return
	if effect == "hit":
		hit_voice.stream = streams[effect]
		hit_voice.play()
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = streams[effect]
	voice.volume_db = -11.0 if effect == "burst" else -20.0
	voice.play()

## Stop flight audio when leaving a run. The dedicated hit voice may finish the final damage sound.
func silence() -> void:
	set_laser(false)
	impact_voice.stop()
	for voice in voices:
		voice.stop()
	boss_music_active = false
	flight_music_active = false
	music.stop()

## Select the boss or ordinary flight loop while retaining the shared mute/pause behavior.
func set_boss_music(active: bool) -> void:
	boss_music_active = active
	flight_music_active = true
	sync_enabled()

## Freeze music and stop transient sounds during pause; resume does not replay old impacts.
func set_paused(value: bool) -> void:
	paused = value
	if paused:
		hit_voice.stop()
		laser_voice.stop()
		impact_voice.stop()
		for voice in voices:
			voice.stop()
	sync_enabled()

## Apply sound preferences and select the correct cached music stream without restarting it every frame.
func sync_enabled() -> void:
	set_laser(laser_active)
	if not enabled:
		hit_voice.stop()
		impact_voice.stop()
		for voice in voices:
			voice.stop()
	if not enabled or not flight_music_active:
		music.stop()
		return
	if music_stream == null:
		music_stream = make_boss_music()
	if flight_stream == null:
		flight_stream = make_flight_music()
	var desired := music_stream if boss_music_active else flight_stream
	if not music.playing or music.stream != desired:
		music.stream = desired
		music.play()
	music.stream_paused = paused

## Start or stop the persistent electric hum only when the beam's active state changes.
func set_laser(active: bool) -> void:
	laser_active = active
	if active and enabled and not paused:
		if not laser_voice.playing:
			laser_voice.play()
	else:
		laser_voice.stop()

## Synthesize a one-second seamless electric hum from phase modulation and periodic high-frequency sparks.
func electric_loop() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(22050 * 2)
	for i in range(22050):
		var t := float(i) / 22050.0
		var hum := sin(TAU * 110.0 * t + sin(TAU * 60.0 * t) * 1.8)
		var spark := sin(TAU * 880.0 * t) * pow(0.5 + 0.5 * sin(TAU * 17.0 * t), 12.0)
		bytes.encode_s16(i * 2, int((hum * 0.48 + spark * 0.12) * 26000))
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	return stream

## Build and cache the original ambient PCM loop; all frequencies are in Hz and time is in seconds.
func make_flight_music() -> AudioStreamWAV:
	# Original sixteen-second space theme: soft chords and a rolling arpeggio.
	var rate := 22050
	var count := rate * 16
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var roots := [0, -3, -5, -2]
	var arp := [0, 7, 12, 15, 12, 7, 19, 7]
	for i in range(count):
		var t := float(i) / rate
		var chord_time := fmod(t, 4.0)
		var root_note: int = roots[int(t / 4.0)]
		var base := 110.0 * pow(2.0, root_note / 12.0)
		var pad_envelope := sin(PI * chord_time / 4.0)
		var pad := (sin(TAU * base * chord_time) + sin(TAU * base * pow(2.0, 3.0 / 12.0) * chord_time) * 0.6 + sin(TAU * base * 1.5 * chord_time) * 0.5) * pad_envelope * 0.16
		var note_time := fmod(t, 0.25)
		var hz := base * pow(2.0, float(arp[int(t * 4.0) % 8]) / 12.0)
		var bell := sin(TAU * hz * note_time) * exp(-note_time * 14.0) * minf(note_time * 100.0, 1.0) * 0.18
		var beat := fmod(t, 0.5)
		var pulse := sin(TAU * 55.0 * beat) * exp(-beat * 14.0) * 0.12
		bytes.encode_s16(i * 2, int(clampf(pad + bell + pulse, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream

## Build the original bass-and-percussion boss loop as 16-bit PCM, generated once rather than per frame.
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

## Generate a short pitch sweep with a decaying envelope; the noise parameter mixes in deterministic grit.
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

## Synthesize the low descending gravity/death impact. Duration controls the longer boss-death tail.
func rift_boom(duration: float = 0.88) -> AudioStreamWAV:
	var sample_rate := 22050
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
		main_phase += lerpf(95.0, 24.0, bend) / sample_rate
		sub_phase += lerpf(52.0, 18.0, t) / sample_rate
		var main := sin(main_phase * TAU) * 0.68
		var sub := sin(sub_phase * TAU) * 0.42
		var grit := random.randf_range(-1.0, 1.0) * 0.035 * pow(1.0 - t, 1.5)
		var envelope := minf(t * 18.0, 1.0) * pow(1.0 - t, 1.35)
		bytes.encode_s16(i * 2, int((main + sub + grit) * envelope * 23000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream
