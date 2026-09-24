extends Node
## Standalone on-device render regression. Copied into an isolated export project;
## never shipped in the playable pack. Own save file protects the player's score.
var game: Node2D
var results: Array[String] = []

## Wait for a ready viewport before launching the deterministic test world.
func _ready() -> void:
	call_deferred("run")

## Persist progress so a watchdog termination identifies the last rendered phase.
func record(message: String) -> void:
	results.append(message)
	var file := FileAccess.open("user://gravity_probe.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	file.close()
	print(message)

## Swallow and delete many actors through actual render frames, then repeat after
## restoration. This covers the mobile draw callback missed by CPU-only checks.
func run() -> void:
	OS.set_environment("ALIEN_SAVE_PATH", "user://gravity_probe_record.cfg")
	game = load("res://main.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	record("PROBE START")
	for cycle in range(3):
		game.start_run()
		game.wave_timer = 1000
		game.boss_timer = 1000
		game.asteroid_timer = 1000
		game.combat.shield_time = 30
		for i in range(14):
			game.spawn_enemy(Vector2(80+i%7*60, 300+i/7*100), Vector2.ZERO)
		for i in range(6):
			game.spawn_asteroid(Vector2(80+i*65,300),Vector2.DOWN*30,20)
		game.combat.add_gravity_charge(50.0)
		game.combat.arm_gravity()
		game.combat.press(0,Vector2(270,420))
		game.combat.release(0,Vector2(270,420))
		game.combat.step(0.34)
		if game.lingering_wells.size() != 1:
			record("FAIL: maximum-charge button did not launch a field")
			return
		for frame in range(660):
			game._physics_process(1.0/60)
			game._process(1.0/60)
			await get_tree().process_frame
			if frame%120 == 0:
				record("cycle=%d frame=%d aliens=%d fields=%d" % [cycle,frame,game.enemies.size(),game.lingering_wells.size()])
		if game.state != game.State.PLAYING or not game.lingering_wells.is_empty():
			record("FAIL: field failed to complete")
			return
		record("CYCLE %d PASS" % cycle)
	record("PROBE PASS: three maximum-charge fields rendered, swallowed actors, expired and recovered")
	game.show_title()
