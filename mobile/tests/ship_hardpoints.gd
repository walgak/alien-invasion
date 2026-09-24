extends SceneTree
## Verify every firing path uses the new ship's transformed visual hardpoints.
## An intentionally stale visual tier models firing immediately after a pickup.

var game: Node2D
var passed := 0
var failed := 0

## Wait until the viewport is available before constructing the real game.
func _initialize() -> void:
	call_deferred("run")

## Keep failures readable and report all broken integration points in one run.
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)

## Freeze encounters and tilt the ship as it would be during steering/recovery.
func fresh(level: int) -> void:
	game.start_run()
	game.weapons.level = level
	game.ship.weapon_level = 0
	game.ship.rotation = 0.29
	game.wave_timer = 1000
	game.boss_timer = 1000
	game.asteroid_timer = 1000
	game.progress.vibration_enabled = false

## Exercise equipped fire, continuous laser, target tap, and charged release.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("ship-hardpoints-record.cfg"):
		push_error("Set an isolated ALIEN_SAVE_PATH ending in ship-hardpoints-record.cfg.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	for pattern in [{"level": 0, "lanes": [0]}, {"level": 1, "lanes": [-1, 1]}, {"level": 2, "lanes": [0, -1, 1]}, {"level": 4, "lanes": [-1, 0, 1]}]:
		var level: int = pattern.level
		fresh(level)
		var cooldown: float = game.fire_player_shot()
		check(game.projectiles.size() == pattern.lanes.size(), "tier %d emits the expected number of shots" % level)
		check(is_equal_approx(cooldown, 0.17), "tier %d preserves its firing interval" % level)
		for index in range(mini(game.projectiles.size(), pattern.lanes.size())):
			var shot: Node2D = game.projectiles[index]
			var muzzle: Vector2 = game.ship.muzzle_position(level, pattern.lanes[index])
			check(shot.position.is_equal_approx(muzzle) and shot.previous_position.is_equal_approx(muzzle), "tier %d shot %d starts at its rotated barrel without a phantom collision sweep" % [level, index])
			var expected_velocity := Vector2(0, -850)
			if (level == 2 and index > 0) or level == 4:
				expected_velocity = Vector2(float(pattern.lanes[index]) * 110, -880).normalized() * 850
			check(shot.velocity.is_equal_approx(expected_velocity), "tier %d shot %d preserves its flight direction and speed" % [level, index])
		await process_frame

	fresh(3)
	game.combat.press(0, game.ship.position)
	game.update_laser(0.0)
	var muzzle: Vector2 = game.ship.muzzle_position(3, 0, true)
	check(is_instance_valid(game.laser) and game.laser.beam_start.is_equal_approx(muzzle) and game.laser.beam_segments[0].is_equal_approx(muzzle), "continuous laser drawing and collision both start at the tilted emitter")

	fresh(2)
	var enemy: Node2D = game.spawn_enemy(Vector2(270, 430), Vector2.ZERO)
	game.combat.press(1, enemy.position)
	game.combat.release(1, enemy.position)
	check(game.projectiles.size() == 1 and game.projectiles[0].position.is_equal_approx(game.ship.muzzle_position(2, 0, true)) and game.projectiles[0].homing_target == enemy, "targeted missile leaves the special hardpoint and keeps its target")
	check(game.combat.missiles == 29, "targeted missile still spends one unit of ammunition")

	fresh(4)
	var aim := Vector2(130, 430)
	game.combat.add_gravity_charge(20.0)
	game.combat.arm_gravity()
	game.combat.press(2, aim)
	game.combat.release(2, aim)
	game.combat.step(game.combat.GRAVITY_PREPARATION)
	check(game.lingering_wells.size() == 1 and game.lingering_wells[0].cannon_position.is_equal_approx(game.ship.muzzle_position(4, 0, true)), "charged gravity cannon leaves the special hardpoint")
	check(game.lingering_wells.size() == 1 and game.lingering_wells[0].well_position == aim and game.lingering_wells[0].charge == 2.0, "moving the launch point preserves gravity targeting and charge")
	# Alien artwork has two barrels, but alternating their ports must not double
	# the established one-projectile volley or change either enemy speed tier.
	for summoned in [false, true]:
		fresh(0)
		enemy = game.spawn_enemy(Vector2(210, 400), Vector2.ZERO, summoned)
		enemy.rotation = 0.31
		var first_port: Vector2 = enemy.muzzle_position()
		var second_port: Vector2 = enemy.muzzle_position()
		check(not first_port.is_equal_approx(second_port), "alien wing cannons expose distinct firing ports")
		for port in [first_port, second_port]:
			var count_before: int = game.projectiles.size()
			enemy.shot_timer = 0.0
			game.update_enemies(0.0)
			var shot: Node2D = game.projectiles.back()
			check(game.projectiles.size() == count_before + 1 and shot.position.is_equal_approx(port) and shot.previous_position.is_equal_approx(port), "alien volley leaves one rotated barrel without an extra shot or collision sweep")
			check(is_equal_approx(shot.velocity.length(), 215.0 if summoned else 180.0) and enemy.shot_timer > 0.0, "alien volley preserves its speed and resets its firing timer")
	fresh(0)
	enemy = game.spawn_enemy(Vector2(210, 400), Vector2.ZERO)
	var legacy_port: Vector2 = enemy.muzzle_position()
	enemy.muzzle_position() # Restore the next port before the legacy volley.
	game.fire_enemy_shot()
	check(game.projectiles.size() == 1 and game.projectiles[0].position.is_equal_approx(legacy_port), "legacy alien volley uses the same visible gun hardpoint")
	fresh(0)
	enemy = game.spawn_enemy(Vector2(210, game.arena.y + game.Enemy.HIT_RADIUS + 1.0), Vector2.ZERO)
	var rear_port: Vector2 = enemy.rear_muzzle_position()
	game.update_enemies(0.0)
	check(game.enemies.is_empty() and game.projectiles.size() == 1 and game.projectiles[0].kind == "doom" and game.projectiles[0].position.is_equal_approx(rear_port) and game.projectiles[0].previous_position.is_equal_approx(rear_port), "escaped alien fires its doom cannon from the rear port at the existing escape boundary")
	# Engine intensity must express the requested distance relationship without
	# changing the physical pull. Alien and player art have opposite nose axes.
	fresh(0)
	var well = game.PlayerWell.new()
	well.game = game
	well.phase = "active"
	well.well_position = Vector2(270,350)
	game.add_child(well)
	game.lingering_wells.append(well)
	var near_point := Vector2(270,450)
	var far_point := Vector2(270,700)
	check(game.combat.gravity_engine_load(near_point,well)>game.combat.gravity_engine_load(far_point,well), "black-hole engine burn grows closer to the core")
	well.kind = "white"
	check(game.combat.gravity_engine_load(near_point,well)<game.combat.gravity_engine_load(far_point,well), "white-hole engine burn has the opposite distance response")
	well.kind = "black"
	enemy = game.spawn_enemy(Vector2(170,550),Vector2.ZERO)
	game.combat.update_attitudes(1.0)
	check(Vector2.DOWN.rotated(enemy.rotation).dot((enemy.position-well.well_position).normalized())>0.99, "alien nose and engines oppose the pull using their downward art orientation")
	check(game.ship.engine_burn.tint == Color("258dff") and enemy.engine_burn.tint == Color("b34cff"), "player engine stays blue and alien engine stays violet")
	check(game.ship.engine_burn.jets.all(func(jet: ColorRect) -> bool: return jet.mouse_filter == Control.MOUSE_FILTER_IGNORE), "engine surfaces cannot intercept touch controls")
	game.free()
	await process_frame
	print("SHIP HARDPOINTS: %d passed; %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
