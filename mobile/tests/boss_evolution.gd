extends SceneTree
## Full encounter regression: guards, exposure-based laser, residual wells and return.
var failures := 0
## SceneTree test entry point; defer setup until the root viewport is ready.
func _initialize() -> void:
	call_deferred("run")
## Record a readable assertion without aborting the remaining checks, so one run reports all failures.
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)
## Create an isolated test game, exercise the stated behavior, and exit nonzero on a failed assertion.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("boss-evolution-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.start_run()
	var guard = game.spawn_enemy(Vector2(220, 300), Vector2.DOWN * 100)
	game.boss_timer = 0
	game.update_director(0.1)
	check(game.enemies.has(guard), "boss warning preserves existing aliens")
	game.update_director(3.1)
	game.boss.step(1.5)
	game.update_enemies(0.1)
	var hp: float = game.boss.health
	game.boss.take_hit(10)
	check(guard.shield_guard and game.boss.health == hp, "surviving aliens form an invulnerable boss shield")
	game.destroy_enemy(guard)
	game.boss.take_hit(1)
	check(game.boss.health == hp - 1, "last guard destruction unlocks boss damage")
	game.start_run()
	game.weapons.level = 3
	var enemy = game.spawn_enemy(Vector2(270, 400), Vector2.ZERO)
	enemy.health = 9
	game.update_laser(0.24)
	var beam = game.laser
	check(game.enemies.has(enemy) and enemy.health == 9, "laser needs a quarter-second exposure")
	game.update_laser(0.011)
	check(not game.enemies.has(enemy) and game.laser == beam, "continuous beam kills a non-boss at quarter second without respawning")
	enemy = game.spawn_enemy(Vector2(270, 400), Vector2.ZERO)
	game.update_laser(0.2)
	enemy.position.x = 100
	game.update_laser(0.1)
	enemy.position.x = 270
	game.update_laser(0.1)
	check(game.enemies.has(enemy), "leaving the beam resets exposure")
	game.clear_hazards()
	game.begin_boss("asteroid")
	game.boss.phase = "firefight"
	game.boss.body_position = Vector2(270, 300)
	hp = game.boss.health
	game.update_laser(0.5)
	check(game.boss.health == hp - 2, "boss laser damage equals one bullet per quarter second")
	game.weapons.level = 0
	game.update_laser(0)
	check(not is_instance_valid(game.laser) and not game.sound.laser_active, "weapon reset removes beam and electric hum")
	for kind in ["black", "white"]:
		game.start_run(kind)
		game.boss.step(1.5)
		game.boss.begin_special()
		game.boss.step(1.3)
		game.boss.phase_time = 1.0
		var original_well: Vector2 = game.boss.well_position
		game.ship.position.x = 180
		var before: Vector2 = game.ship.position
		game.boss.take_hit(10000)
		check(game.ship.position == before, kind + ": victory never teleports the ship")
		check(game.lingering_wells.size() == 2, kind + ": original attack survives alongside a death hole")
		check(game.lingering_wells[0].well_position == original_well and game.lingering_wells[0].phase_time == 1.0, kind + ": original attack keeps its position and remaining time")
		check(game.lingering_wells[1].well_duration == 8.0 and game.lingering_wells[1].well_scale > 1, kind + ": larger death hole lasts twice as long")
		game.shot_timer = 1000
		for i in range(490):
			for well in game.lingering_wells:
				well.resist()
			game._physics_process(1.0 / 60.0)
		check(game.lingering_wells.is_empty(), kind + ": surviving wells expire naturally")
		var moving_from: Vector2 = game.ship.position
		game._physics_process(1.0 / 60.0)
		check(game.ship.position.distance_to(moving_from) <= 260.0 / 60.0 + 0.01, kind + ": cruise return uses bounded physical speed")
		for i in range(120):
			game._physics_process(1.0 / 60.0)
		check(game.ship.position.is_equal_approx(game.cruise_position()), kind + ": smooth return reaches normal position")
	game.start_run("asteroid")
	game.boss.step(1.5)
	game.boss.begin_special()
	game.boss.step(1.3)
	game.boss.step(0.1)
	var rocks: int = game.asteroids.size()
	game.boss.take_hit(10000)
	check(game.asteroids.size() == rocks and game.lingering_wells.size() == 1, "asteroid barrage survives boss death")
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
