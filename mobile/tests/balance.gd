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
	check(game.difficulty_percent() == 1 and is_equal_approx(game.difficulty_scale(), 0.02), "runs begin at one percent of the difficulty scale")
	game.begin_boss("black")
	check(game.boss.max_health == 35, "first boss scales down from the 50 percent reference")
	game.boss.take_hit(10000)
	check(game.difficulty_percent() == 2, "first victory advances to two percent")
	game.start_run()
	game.bosses_defeated = 0
	game.rng.seed = 32
	var target = game.spawn_enemy(Vector2(270, 250), Vector2.ZERO)
	game.damage_target(target, "enemy", 1)
	game.damage_target(target, "enemy", 1)
	check(game.enemies.has(target) and target.health == 1, "small alien survives two single bullets")
	game.damage_target(target, "enemy", 1)
	check(not game.enemies.has(target), "third single bullet destroys the small alien")
	game.begin_boss("black")
	check(game.boss.max_health == 35, "first boss has triple health")
	game.bosses_defeated = 50
	check(game.difficulty_percent() == 51 and is_equal_approx(game.difficulty_scale(), 1.02), "one victory increases difficulty from 50 to 51 percent")
	game.begin_boss("white")
	check(game.boss.max_health > 20 and game.boss.max_health < 100, "next boss health follows the 51 percent scale with integer rounding")
	game.bosses_defeated = 99
	check(game.difficulty_percent() == 100 and game.difficulty_scale() == 2.0, "100 percent difficulty is twice the starting baseline")
	game.start_run()
	game.bosses_defeated = 49
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
	var totals: Array[int] = []
	for victories in [0, 49]:
		game.start_run()
		game.bosses_defeated = victories
		game.rng.seed = 123
		var total := 0
		for i in range(5000):
			game.maybe_drop_pickup(Vector2(270, 300))
			total += game.pickups.size()
			for drop in game.pickups.duplicate():
				game.pickups.erase(drop)
				drop.queue_free()
		totals.append(total)
	check(totals[0] < 15 and totals[1] > 100 and totals[1] > totals[0] * 10, "drop frequency grows from the one-percent start to the fifty-percent reference")
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
