extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: " + label)
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("swarm-rewards-record.cfg"):
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.start_run()
	for i in range(10):
		game.clear_hazards()
		game.spawn_enemy_group()
		var before: int = game.pickups.size()
		game.destroy_enemy(game.enemies[0])
		check(game.pickups.size() == before + 1, "every independent swarm guarantees a drop")
	game.start_run("swarm")
	game.boss.activate_special()
	game.boss.summon_alien()
	game.destroy_enemy(game.enemies[0])
	check(game.pickups.size() == 1, "carrier's summoned swarm also guarantees a drop")
	game.start_run("black")
	check(game.boss.max_health == 35, "starting boss has 35 health")
	game.boss.take_hit(1000)
	check(game.pickups.size() == 1, "boss guarantees exactly one reward")
	game.start_run("white")
	for i in range(12):
		game.spawn_pickup(Vector2(270, 500), "life")
	var oldest = game.pickups[0]
	game.boss.take_hit(1000)
	check(game.pickups.size() == 12 and not game.pickups.has(oldest), "boss reward survives a full pickup budget")
	game.start_run()
	game.weapons.level = 2
	var advanced := 0
	for i in range(100):
		game.guaranteed_drop(Vector2(270, 500))
		for drop in game.pickups.duplicate():
			advanced += int(drop.kind == "weapon")
			game.pickups.erase(drop)
			drop.queue_free()
	check(advanced <= 1, "guaranteed rewards preserve advanced weapon rarity")
	game.sound.enabled = true
	game.sound.play_effect("boss_death")
	for i in range(20):
		game.sound.play_effect("shot")
	check(game.sound.impact_voice.stream == game.sound.streams["boss_death"], "gunfire cannot steal the boss death audio channel")
	game.sound.set_paused(true)
	check(not game.sound.impact_voice.playing, "pausing stops deep impact audio")
	game.sound.silence()
	# Allow the audio server to release playback references before test teardown.
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
