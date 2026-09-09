extends RefCounted
## A local record only. ALIEN_SAVE_PATH isolates automated checks from real saves.

var best_by_mode := {"endless": 0, "fleet": 0, "black": 0, "white": 0, "asteroid": 0}
var sound_enabled := true
var vibration_enabled := true
var save_path := "user://flight_record.cfg"
var last_error := OK

## Construct defaults before this object enters the scene tree; do not depend on ready child nodes here.
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
		vibration_enabled = config.get_value("settings", "vibration", true) == true

## Write scores and sound preference to ConfigFile; save_path can be redirected by test environment variables.
func save() -> void:
	var config := ConfigFile.new()
	for mode in best_by_mode:
		config.set_value("records", mode, best_by_mode[mode])
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "vibration", vibration_enabled)
	last_error = config.save(save_path)
	if last_error != OK:
		push_warning("The local flight record could not be saved: %s" % error_string(last_error))

## Return the saved best for this score category without changing storage.
func best_for(mode: String) -> int:
	return int(best_by_mode.get(mode, 0))

## Update the in-memory high score only; game.gd decides when to flush it to disk.
func record_score(mode: String, score: int) -> void:
	best_by_mode[mode] = maxi(best_for(mode), score)
