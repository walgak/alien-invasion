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
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("balance-record.cfg"):
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.start_run()
	game.rng.seed = 32
	var zigzags := 0
	for i in range(100):
		var alien = game.spawn_enemy(Vector2(270, 250), Vector2.DOWN * 100)
		zigzags += int(alien.zigzag)
		check(alien.shot_timer >= 0.85 and alien.shot_timer <= 1.7, "halved initial firing interval")
		game.remove_enemy(alien)
	check(zigzags > 25 and zigzags < 65, "waves mix zigzag and straight aliens")
	var alien = game.spawn_enemy(Vector2(270, 250), Vector2.DOWN * 100)
	alien.zigzag = true
	alien.phase = 0
	alien.advance(0.3)
	var right: float = alien.position.x
	alien.advance(1.0)
	check(right > 270 and alien.position.x < right, "zigzag reverses horizontal direction")
	game.weapons.level = 2
	var drops := 0
	for i in range(1000):
		game.maybe_drop_pickup(Vector2(270, 300))
		for drop in game.pickups.duplicate():
			if drop.kind == "weapon":
				drops += 1
			game.pickups.erase(drop)
			drop.queue_free()
	check(drops == 1, "at most one advanced drop per boss interval despite 1000 kills")
	game.bosses_defeated += 1
	for i in range(1000):
		game.maybe_drop_pickup(Vector2(270, 300))
	check(game.pickups.filter(func(drop): return drop.kind == "weapon").size() <= 1, "next sector retains advanced drop cap")
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
