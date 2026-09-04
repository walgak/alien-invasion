extends RefCounted
## A local record only. ALIEN_SAVE_PATH isolates automated checks from real saves.

var best_by_mode := {"fleet": 0, "black": 0, "white": 0, "asteroid": 0}
var sound_enabled := true
var save_path := "user://flight_record.cfg"
var last_error := OK

func _init() -> void:
	var override_path := OS.get_environment("ALIEN_SAVE_PATH")
	if not override_path.is_empty():
		save_path = override_path
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		for mode in best_by_mode:
			var value = config.get_value("records", mode, config.get_value("record", "best", 0) if mode == "fleet" else 0)
			if value is int:
				best_by_mode[mode] = clampi(value, 0, 999999999)
		var sound = config.get_value("settings", "sound", true)
		if sound is bool:
			sound_enabled = sound

func save() -> void:
	var config := ConfigFile.new()
	for mode in best_by_mode:
		config.set_value("records", mode, best_by_mode[mode])
	config.set_value("settings", "sound", sound_enabled)
	last_error = config.save(save_path)
	if last_error != OK:
		push_warning("The local flight record could not be saved: %s" % error_string(last_error))

func best_for(mode: String) -> int:
	return int(best_by_mode.get(mode, 0))

func record_score(mode: String, score: int) -> void:
	best_by_mode[mode] = maxi(best_for(mode), score)
