extends SceneTree
## Checks the firefight -> special attack -> firefight loop through collisions.

const Projectile = preload("res://scripts/projectile.gd")
var failures := 0
var checks := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		failures += 1
	else:
		print("PASS: " + description)
		checks += 1

func hit_core_with_bullet() -> void:
	var shot = Projectile.new()
	shot.position = game.boss.body_position + Vector2(0, 120)
	shot.previous_position = shot.position
	game.add_child(shot)
	game.projectiles.append(shot)
	game.update_projectiles(0.2)

func run_checks() -> void:
	var save_path := OS.get_environment("ALIEN_SAVE_PATH")
	if not save_path.ends_with("boss-cycle-record.cfg"):
		push_error("Set ALIEN_SAVE_PATH to a temporary path ending in boss-cycle-record.cfg.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	for mode in ["black", "white", "asteroid", "swarm"]:
		game.start_run(mode)
		check(game.boss.phase == "arrival", mode + ": enters from offscreen")
		game.boss.step(1.5)
		check(game.boss.phase == "firefight", mode + ": arrival leads to exchanging fire")
		game.boss.step(1.0)
		check(game.projectiles.size() == 3 and game.projectiles.all(func(shot): return shot.hostile), mode + ": boss shoots an aimed three-shot volley")
		game.update_projectiles(3.0)
		check(game.lives == 2 and game.boss.health == game.boss.max_health, mode + ": boss bullets hurt the player, never the boss")
		hit_core_with_bullet()
		var remaining_health: int = game.boss.health
		check(remaining_health == game.boss.max_health - 1, mode + ": a player bullet damages the boss core")
		game.boss.begin_special()
		if mode in ["black", "white"]:
			check(game.boss.cannon_active and is_equal_approx(game.boss.cannon_velocity.length(), 1225.0), mode + ": rift cannon flies five times faster than a normal boss bullet")
		game.boss.step(1.3)
		check(game.boss.phase == "active", mode + ": warning leads into the special attack")
		if mode in ["black", "white"]:
			check(game.projectiles.all(func(shot): return not shot.hostile), mode + ": old bullets clear before steering changes to tapping")
			for i in range(245):
				if i % 12 == 0:
					game.boss.resist()
				game.boss.step(1.0 / 60.0)
		else:
			for i in range(250):
				game.boss.step(1.0 / 60.0)
			check(game.boss.phase == "clearing" and (not game.asteroids.is_empty() or not game.enemies.is_empty()), mode + ": waits until the finite barrage has been dealt with")
			for enemy in game.enemies.duplicate():
				game.destroy_enemy(enemy)
			for rock in game.asteroids.duplicate():
				while game.asteroids.has(rock):
					game.hit_asteroid(rock)
			game.boss.step(1.0 / 60.0)
		check(game.state == game.State.PLAYING and game.boss.phase == "firefight", mode + ": surviving the special returns to the firefight")
		check(game.boss.health == remaining_health, mode + ": survival preserves boss damage without adding damage")
		var before_shots: int = game.projectiles.size()
		game.boss.step(1.0)
		check(game.projectiles.size() == before_shots + 3, mode + ": normal boss shooting resumes")
		for i in range(600):
			if game.boss.phase != "firefight":
				break
			game.boss.step(1.0 / 60.0)
		check(game.boss.phase == "warning" and game.boss.health == remaining_health, mode + ": another special follows without resetting health")
		# Only one point remains, and the final hit uses the actual collision path.
		game.boss.health = 1
		hit_core_with_bullet()
		check(game.state == game.State.PLAYING and not is_instance_valid(game.boss), mode + ": the final player bullet returns to endless flight")
		check(game.projectiles.is_empty() and game.bosses_defeated == 1, mode + ": defeated boss hazards clear")
		if mode in ["black", "white"]:
			check(game.ship.position == game.cruise_position(), mode + ": victory restores the normal ship position")
	game.start_run("black")
	game.rng.seed = 77
	var intervals: Array[float] = []
	for i in range(12):
		game.boss.return_to_firefight()
		intervals.append(game.boss.cooldown)
	check(intervals.min() >= 5.0 and intervals.max() <= 9.0 and intervals.min() < intervals.max(), "special attacks use varying intervals with a guaranteed firefight between them")
	game.free()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	await process_frame
	print("BOSS CYCLE: %d passed; %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)
