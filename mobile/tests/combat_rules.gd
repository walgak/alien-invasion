extends SceneTree
## Deterministic interaction tests: input arbitration, fatal hazards, temporary
## equipment, reflection, player gravity and survival restoration.
var game: Node2D
var passed := 0
var failed := 0

## Defer scene creation until the test viewport exists.
func _initialize() -> void:
	call_deferred("run")

## Report each invariant and keep checking after a failure.
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)

## Start a quiet run with no scheduled spawns to isolate interactions.
func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000
	game.asteroid_timer = 1000
	game.boss_timer = 1000
	game.progress.vibration_enabled = false
	game.ship.invulnerable = 0

## Advance actual game physics without wall-clock waits.
func tick(seconds: float) -> void:
	for frame in range(ceili(seconds * 60)):
		game._physics_process(1.0 / 60.0)

## Exercise agreed mechanics, always using a disposable record file.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("combat-rules-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	fresh()
	tick(0.5)
	check(game.projectiles.is_empty(), "idle ship never autofires")
	game.combat.press(0, game.ship.position)
	tick(0.2)
	check(not game.projectiles.is_empty(), "holding ship fires")
	game.combat.move(0, game.ship.position + Vector2(40, 0))
	tick(0.1)
	check(game.ship.position.x > 270, "drag steers physically")
	game.combat.release(0, game.ship.position)
	var idle: Vector2 = game.ship.position
	tick(0.1)
	check(game.ship.position == idle and not game.combat.firing(), "release stops control and motion")
	game.combat.press(0, game.ship.position)
	game.combat.move(0, Vector2(-10, 800))
	check(not game.combat.firing(), "leaving viewport cancels firing")
	fresh()
	game.spawn_enemy(Vector2(270, 300), Vector2.ZERO)
	var enemy: Node2D = game.enemies[0]
	game.combat.press(0, enemy.position)
	game.combat.release(0, enemy.position)
	check(game.projectiles.size() == 1 and game.projectiles[0].homing_target == enemy, "enemy tap launches targeted rocket")
	fresh()
	game.spawn_asteroid(game.ship.position, Vector2.ZERO, 20)
	game.weapons.level = 2
	game.ship.invulnerable = 99
	game.update_asteroids(0.01)
	check(game.state == game.State.LOST and game.lives == 0, "asteroid impact bypasses hull, backup and normal invulnerability")
	fresh()
	game.spawn_asteroid(Vector2(270, 1030), Vector2.DOWN * 100, 20)
	game.update_asteroids(0.01)
	check(game.state == game.State.PLAYING, "asteroids escape harmlessly")
	fresh()
	game.spawn_enemy(game.ship.position, Vector2.ZERO)
	game.update_enemies(0.001)
	check(game.lives == 2 and game.state == game.State.PLAYING, "alien collision costs exactly one life")
	fresh()
	game.spawn_enemy(Vector2(270, 1020), Vector2.ZERO)
	game.update_enemies(0.01)
	check(game.projectiles.size() == 1 and game.projectiles[0].kind == "doom", "escaped alien fires visible doom cannon")
	tick(0.4)
	check(game.state == game.State.LOST, "doom cannon causes instant loss on arrival")
	fresh()
	game.combat.shield_time = 10
	game.spawn_escape_cannon(Vector2(270, 1000))
	tick(0.4)
	check(game.state == game.State.PLAYING and game.lives == 3, "shield blocks doom cannon")
	game.spawn_asteroid(game.ship.position, Vector2.ZERO, 20)
	game.update_asteroids(0.01)
	game.damage_ship()
	game.lose_ship("test")
	check(game.lives == 3, "shield blocks rocks, bullets and lethal gravity")
	game.combat.step(10)
	game.instant_loss("expired")
	check(game.state == game.State.LOST, "shield expires after ten gameplay seconds")
	fresh()
	game.weapons.level = 2
	game.combat.equip_laser()
	game.combat.step(9.9)
	check(game.weapons.level == 3, "laser lasts ten seconds")
	game.combat.step(0.11)
	check(game.weapons.level == 2, "laser restores previous weapon")
	game.combat.equip_laser()
	game.pause_run()
	tick(2)
	check(game.combat.laser_time == 10, "pause does not spend laser duration")
	game.resume_run()
	game.combat.press(0, game.ship.position)
	game.spawn_enemy(Vector2(270, 300), Vector2.ZERO)
	game.update_laser(0.001)
	check(game.enemies.is_empty(), "laser instantly destroys ordinary alien")
	game.spawn_asteroid(Vector2(270, 500), Vector2.ZERO, 31)
	var rock: Node2D = game.asteroids[0]
	var hp: int = rock.health
	var segments: Array[Vector2] = game.reflected_laser(game.ship.position + Vector2(0, -44))
	check(segments.size() >= 4 and segments[3].y <= segments[2].y, "asteroid reflection travels away from player")
	var reflected_at: Vector2 = segments[2].lerp(segments[3], 0.08)
	game.spawn_enemy(reflected_at, Vector2.ZERO)
	game.update_laser(0.01)
	check(rock.health == hp and game.enemies.is_empty(), "reflection kills alien without damaging asteroid")
	fresh()
	game.begin_boss("black")
	game.boss.step(1.5)
	game.ship.position.x = game.boss.body_position.x
	game.combat.equip_laser()
	game.combat.press(0, game.ship.position)
	var boss_hp: float = game.boss.health
	game.update_laser(0.24)
	check(game.boss.health == boss_hp, "boss survives laser exposure below quarter second")
	game.update_laser(0.01)
	check(game.boss.health == boss_hp - 1, "boss loses one bullet of health per quarter second")
	game.boss.begin_special()
	game.boss.step(1.3)
	game.combat.press(0, game.ship.position)
	game.update_laser(0.1)
	check(not is_instance_valid(game.laser) and not game.combat.firing(), "gravity taps never fire laser")
	var held_position: Vector2 = game.ship.position
	game.combat.shield_time = 10
	game.boss.step(0.3)
	check(game.ship.position == held_position, "shield eliminates boss gravity movement")
	fresh()
	game.combat.press(0, Vector2(270, 400))
	game.combat.step(0.9)
	game.combat.release(0, Vector2(270, 400))
	check(game.lingering_wells.is_empty(), "short empty tap does not launch gravity")
	game.combat.press(0, Vector2(270, 400))
	game.combat.step(7)
	game.combat.release(0, Vector2(270, 400))
	var well: Node2D = game.lingering_wells[0]
	check(well.charge == 5 and not well.holds_steering(), "charge caps at five and first launches a rocket")
	well.step(1)
	check(well.holds_steering() and well.remaining == 5, "lifetime starts on implosion")
	fresh()
	game.spawn_enemy(Vector2(70, 250), Vector2.ZERO)
	enemy = game.enemies[0]
	var original: Vector2 = enemy.position
	game.combat.press(0, Vector2(270, 400))
	game.combat.step(1)
	game.combat.release(0, Vector2(270, 400))
	well = game.lingering_wells[0]
	well.step(1)
	check(is_equal_approx(well.well_scale, 1.8) and well.remaining == 1, "minimum charge matches boss death-well size and lasts one second")
	well.step(0.1)
	check(is_equal_approx(enemy.position.distance_to(original), 9.0), "pull speed is ninety pixels per second")
	var before_large: Vector2 = enemy.position
	well.well_scale *= 2
	well.step(0.1)
	check(is_equal_approx(enemy.position.distance_to(before_large), 9.0), "larger gravity core does not increase pull speed")
	well.well_scale /= 2
	var shot = game.weapons.spawn_shot(game, Vector2(100, 500), Vector2.UP * 850)
	game.bend_projectile(shot, 0.1)
	check(shot.velocity.x > 0 and is_equal_approx(shot.velocity.length(), 850), "gravity bends bullets without changing speed")
	held_position = game.ship.position
	well.resist()
	well.step(0.1)
	check(game.ship.position == held_position, "player-well tap cancels force without thrust")
	game.begin_boss("asteroid")
	game.boss.step(1.5)
	var boss_position: Vector2 = game.boss.body_position
	well.step(0.81)
	check(game.boss.body_position == boss_position, "boss resists player well")
	check(game.combat.returns.has(enemy), "surviving alien schedules return")
	game.combat.step(1)
	check(enemy.position.is_equal_approx(original), "survivor returns to original position")
	fresh()
	var health_drops := 0
	var shield_drops := 0
	game.rng.seed = 981
	for i in range(3000):
		game.spawn_pickup(Vector2(200, 400), "life")
		var drop: Node2D = game.pickups.pop_back()
		if drop.kind == "shield":
			shield_drops += 1
		else:
			health_drops += 1
		drop.free()
	check(absf(float(shield_drops) / health_drops - 1.0 / 3.0) < 0.04, "shield drop rate is one third of hull drops")
	game.free()
	await process_frame
	print("COMBAT RULES: %d passed; %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
