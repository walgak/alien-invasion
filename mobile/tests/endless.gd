extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func run_checks() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("endless-record.cfg"):
		push_error("Set a temporary ALIEN_SAVE_PATH ending in endless-record.cfg.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.sound.enabled = true
	game.sound.set_boss_music(true)
	check(game.sound.music.playing and game.sound.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "boss music is a playing loop")
	game.sound.set_paused(true)
	check(game.sound.music.stream_paused, "pausing freezes boss music")
	game.sound.set_paused(false)
	check(not game.sound.music.stream_paused, "resuming restores boss music")
	game.sound.enabled = false
	game.sound.sync_enabled()
	check(not game.sound.music.playing, "muting stops boss music")
	game.start_run()
	game.rng.seed = 19
	var kinds: Array[String] = []
	for i in range(4):
		kinds.append(game.next_boss_kind())
	kinds.sort()
	check(kinds == ["asteroid", "black", "swarm", "white"], "every four-boss deck contains all four types")
	game.boss_timer = 0.01
	game.update_director(0.02)
	check(game.boss_warning > 0 and game.sound.boss_music_active and not is_instance_valid(game.boss), "music warns before the boss appears")
	game.update_director(3.1)
	check(is_instance_valid(game.boss) and game.boss.phase == "arrival", "warning transitions to boss arrival")
	game.boss.take_hit(10000)
	check(game.bosses_defeated == 1 and game.state == game.State.PLAYING and not game.sound.boss_music_active, "boss victory resumes flight and stops boss music")
	game.update_director(3.1)
	game.update_director(1.0)
	check(not game.enemies.is_empty(), "random enemies resume after boss victory")
	game.start_run()
	for level in range(1, 5):
		game.spawn_pickup(game.ship.position, "weapon")
		game.update_pickups(0)
		check(game.weapons.level == level, "collected weapon advances to level %d" % level)
		game.clear_hazards()
		game.fire_player_shot()
		var expected: int = [0, 2, 3, 1, 2][level]
		check(game.projectiles.size() == expected, "weapon level %d fires its own pattern" % level)
	game.damage_ship()
	check(game.lives == 2 and game.weapons.level == 4, "nonlethal damage preserves the weapon")
	game.ship.invulnerable = 0
	game.damage_ship()
	game.ship.invulnerable = 0
	game.damage_ship()
	check(game.lives == 1 and game.weapons.level == 0 and game.state == game.State.PLAYING, "lethal damage consumes upgrades and restores one life")
	game.ship.invulnerable = 0
	game.damage_ship()
	check(game.state == game.State.LOST, "the final single-shooter life ends the run")
	game.start_run()
	game.lives = 1
	for i in range(4):
		game.spawn_pickup(game.ship.position, "life")
		game.update_pickups(0)
	check(game.lives == 3, "life drops cannot exceed three hull lives")
	game.clear_hazards()
	game.weapons.level = 3
	var near = game.spawn_enemy(game.ship.position - Vector2(0, 150), Vector2.ZERO)
	var far = game.spawn_enemy(game.ship.position - Vector2(0, 300), Vector2.ZERO)
	near.health = 3
	far.health = 3
	game.fire_player_shot()
	game.update_projectiles(0.01)
	check(near.health == 1 and far.health == 1, "laser pierces multiple enemies")
	game.update_projectiles(0.01)
	check(near.health == 1 and far.health == 1, "one laser pulse never damages a target twice")
	game.clear_hazards()
	game.weapons.level = 4
	game.spawn_enemy(game.ship.position - Vector2(13, 170), Vector2.ZERO)
	game.spawn_enemy(game.ship.position + Vector2(45, -170), Vector2.ZERO)
	game.fire_player_shot()
	game.update_projectiles(0.3)
	check(game.enemies.is_empty(), "rocket impact destroys a nearby enemy with splash damage")
	game.start_run("swarm")
	game.boss.summon_alien()
	var alien = game.enemies[0]
	check(alien.summoned and alien.motion_phase == "pull", "fourth boss pulls alien ships from offscreen")
	game.boss.body_position = Vector2(270, 250)
	game.update_enemies(0.7)
	check(alien.motion_phase == "windup" and alien.fold_origin == Vector2(270, 292), "alien tether connects to the moving boss")
	game.update_enemies(0.22)
	var velocity: Vector2 = alien.velocity
	check(alien.motion_phase == "flight" and velocity.y > 0, "boss throws the alien toward the ship")
	game.ship.position.x = 40
	game.update_enemies(0.1)
	check(alien.velocity == velocity, "thrown aliens keep a dodgeable trajectory")
	game.start_run()
	game.rng.seed = 2026
	for i in range(18000):
		game.ship.invulnerable = 10
		if is_instance_valid(game.boss):
			game.boss.resist()
			if i % 180 == 0:
				game.boss.take_hit(10000)
		game._physics_process(1.0 / 60.0)
		if i % 60 == 0:
			await process_frame
	check(game.state == game.State.PLAYING and game.bosses_defeated >= 4, "five-minute simulation continues through multiple bosses")
	check(game.enemies.size() <= 14 and game.projectiles.size() < 150 and game.pickups.size() <= 12, "long runs keep actor counts bounded")
	game.free()
	await process_frame
	print("ENDLESS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
