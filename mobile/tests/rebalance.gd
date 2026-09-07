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
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("rebalance-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.start_run()
	var previous := 0.0
	var increment := 100.0
	for wins in range(25):
		game.bosses_defeated = wins
		game.begin_boss("black")
		var hp: float = game.boss.max_health
		check(hp >= 20 and hp < 100, "boss health bounded below 100")
		if wins == 0:
			check(hp == 20, "first boss takes 20 single bullets")
		else:
			var curve := 100.0 - 1200.0 / (15.0 + wins)
			var prior_curve := 100.0 - 1200.0 / (14.0 + wins)
			var prior_gain := 1200.0 / (13.0 + wins) - 1200.0 / (14.0 + wins)
			check(hp >= previous and curve - prior_curve <= prior_gain + 0.000001, "underlying boss health curve has shrinking gains")
			increment = hp - previous
		previous = hp
		var alien = game.spawn_enemy(Vector2(270, 250), Vector2.DOWN * 100)
		check(alien.health == mini(9, 3 + wins / 2), "alien gains one hit every two wins up to nine")
		game.spawn_asteroid(Vector2(270, 500), Vector2.DOWN * 100, 20)
		check(game.asteroids[0].health == 5 + wins / 2, "small asteroid minimum five and rising")
	game.start_run()
	game.pointer_id = 0
	game.previous_pointer_x = 200
	game.ship.target_x = 270
	game.boss_timer = 0
	game.update_director(0.1)
	check(game.pointer_id == 0, "boss warning preserves active touch")
	game.update_director(3.1)
	check(game.pointer_id == 0, "boss creation preserves active touch")
	var hp: float = game.boss.health
	game.weapons.level = 3
	game.fire_player_shot()
	game.update_projectiles(0.01)
	check(game.boss.health == hp, "laser cannot hit an arriving boss")
	game.boss.step(1.5)
	check(game.pointer_id == 0, "arrival completion preserves active touch")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(240, 780)
	game._unhandled_input(drag)
	check(game.ship.target_x == 310, "same held finger continues steering after arrival")
	game.start_run()
	game.weapons.level = 3
	var hidden = game.spawn_enemy(Vector2(270, -10), Vector2.ZERO)
	game.fire_player_shot()
	game.update_projectiles(0.01)
	check(hidden.health == 3, "laser never damages an offscreen ship")
	game.detonate_rocket(Vector2(270, 0), 65, null)
	check(hidden.health == 3, "rocket splash never damages an offscreen ship")
	for level in range(3):
		game.clear_hazards()
		game.weapons.level = level
		check(is_equal_approx(game.fire_player_shot(), 0.17), "all small-bullet weapons use the same firing interval")
		for shot in game.projectiles:
			check(is_equal_approx(shot.velocity.length(), 850), "all small bullets use the same speed")
	game.clear_hazards()
	game.weapons.level = 4
	var started := Time.get_ticks_usec()
	for i in range(3600):
		game.ship.invulnerable = 100
		game._physics_process(1.0 / 60.0)
		if is_instance_valid(game.boss):
			game.boss.resist()
		if i % 60 == 0:
			await process_frame
	check(game.projectiles.size() < 100 and game.particles.size() <= 256, "rocket stress run bounds projectiles and particles")
	print("60 seconds rocket simulation CPU wall time: ", (Time.get_ticks_usec() - started) / 1000000.0)
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
