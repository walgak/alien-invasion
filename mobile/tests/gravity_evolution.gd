extends SceneTree
## Regression coverage for interacting gravity, shield controls, ammo, death presentation,
## sector lighting, and preserving touch through non-gravity boss transitions.
var game: Node2D
var failures := 0
var passed := 0

## Wait until the viewport exists before constructing the game.
func _initialize() -> void:
	call_deferred("run")

## Report each independent behavior rather than stopping at the first failure.
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

## Keep director spawns out of deterministic interaction scenarios.
func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000
	game.boss_timer = 1000
	game.asteroid_timer = 1000
	game.progress.vibration_enabled = false

## Create an already-active residual boss field with an exact remaining lifetime.
func field(kind: String, at: Vector2, duration: float) -> Node2D:
	var well = game.Boss.new()
	well.game = game
	well.kind = kind
	well.lingering = true
	well.phase = "active"
	well.well_position = at
	well.well_duration = duration
	game.add_child(well)
	game.lingering_wells.append(well)
	return well

## Create the player's well using its real rocket-to-field transition.
func player_field(at: Vector2) -> Node2D:
	var well = game.PlayerWell.new()
	well.game = game
	well.well_position = at
	well.cannon_position = at
	game.add_child(well)
	game.lingering_wells.append(well)
	well.step(0)
	return well

## Run the agreed interaction rules against a disposable save.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("gravity-evolution-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	fresh()
	var a := field("black", Vector2(100, 400), 2)
	var b := field("black", Vector2(440, 400), 3)
	game.gravity_fields.step(0.1)
	check(a.well_position.distance_to(b.well_position) < 340, "black holes attract")
	b.well_position = a.well_position + Vector2(30, 0)
	game.gravity_fields.step(0)
	check(game.lingering_wells.size() == 1, "touching black cores merge")
	check(is_equal_approx(game.gravity_fields.seconds_left(a), 5), "merger conserves remaining seconds")
	check(is_equal_approx(a.well_scale, sqrt(2.0)), "merger conserves area using square-root radius")
	fresh()
	a = player_field(Vector2(200, 400))
	b = field("black", Vector2(240, 400), 4)
	game.gravity_fields.step(0)
	check(game.lingering_wells == [a] and is_equal_approx(a.remaining, 5.5), "player/boss merger preserves player well and sums 1.5 plus 4 seconds")
	fresh()
	a = field("white", Vector2(220, 690), 2)
	b = field("white", Vector2(320, 690), 3)
	game.gravity_fields.step(0.1)
	check(a.well_position.distance_to(b.well_position) > 100, "white holes repel")
	check(a.well_duration == 2 and b.well_duration == 3, "repulsion never alters lifetime")
	a.resist()
	check(a.proximity_multiplier > 1 and a.neutralise_time < a.TAP_NEUTRALISE_SECONDS, "nearby white fields demand faster neutralisation taps")
	fresh()
	a = player_field(Vector2(270, 400))
	b = field("white", Vector2(300, 400), 3)
	game.spawn_enemy(Vector2(280, 410), Vector2.ZERO)
	game.spawn_hostile_shot(Vector2(280, 400), Vector2.ZERO)
	game.gravity_fields.step(0.01)
	check(game.gravity_fields.active_wells().is_empty() and game.enemies.size() == 1, "opposite fields vanish before a warning flash, without immediate damage")
	game.gravity_fields.step(0.35)
	check(game.enemies.is_empty() and game.projectiles.is_empty() and game.lives == 3, "safe shockwave damages enemies and clears bullets without harming player")
	fresh()
	game.combat.shield_time = 10
	a = field("black", Vector2(270, 500), 4)
	game.combat.press(0, game.ship.position)
	game.combat.move(0, game.ship.position + Vector2(60, 0))
	game.shot_timer = 0.0
	game._physics_process(0.1)
	check(game.ship.position.x > 270 and not game.projectiles.is_empty(), "shield permits physical steering and equipped firing inside gravity")
	game.combat.release(0, game.ship.position)
	game.combat.press(0, Vector2(100, 400))
	game.combat.step(2)
	game.combat.release(0, Vector2(100, 400))
	check(game.lingering_wells.size() == 2, "shield permits a gravity counterattack while the enemy field is active")
	game.combat.press(0, game.ship.position)
	game.combat.shield_time = 0.01
	game.combat.step(0.02)
	check(not game.combat.firing(), "shield expiry restores tap-only controls")
	fresh()
	game.weapons.level = 2
	game.combat.equip_laser()
	game.combat.step(4)
	check(game.combat.laser_time == 10, "idle laser time does not drain")
	game.combat.press(0, game.ship.position)
	game.combat.step(0.5)
	check(game.combat.laser_time == 9.5, "held laser spends actual firing time")
	game.combat.release(0, game.ship.position)
	game.combat.step(3)
	check(game.combat.laser_time == 9.5, "release pauses laser countdown")
	fresh()
	check(game.combat.missiles == 30, "run begins with thirty targeting missiles")
	game.spawn_enemy(Vector2(220, 400), Vector2.ZERO)
	game.combat.press(0, Vector2(220, 400))
	game.combat.release(0, Vector2(220, 400))
	check(game.combat.missiles == 29, "targeted launch consumes one missile")
	game.clear_hazards()
	game.combat.missiles = 0
	game.spawn_enemy(Vector2(220, 400), Vector2.ZERO)
	game.combat.step(1)
	game.combat.press(0, Vector2(220, 400))
	game.combat.release(0, Vector2(220, 400))
	check(game.projectiles.is_empty(), "empty missile inventory cannot fire")
	game.spawn_pickup(game.ship.position, "missiles")
	game.collect_pickup(game.pickups.back())
	check(game.combat.missiles == 5, "missile pickup adds exactly five")
	game.spawn_enemy(Vector2(245, 400), Vector2.ZERO)
	game.detonate_rocket(Vector2(232, 400), 65, null)
	check(game.enemies.is_empty(), "one blast destroys both touching three-hit aliens")
	fresh()
	game.ship.position = Vector2(120, 900)
	game.ship.target_x = 120
	game.returning_to_cruise = true
	game._physics_process(0.2)
	check(game.ship.position.x == 120 and game.ship.position.y < 900 and game.ship.visible, "cruise recovery changes only Y and keeps the hull visible")
	fresh()
	a = player_field(Vector2(300, 400))
	game.spawn_asteroid(Vector2(80, 300), Vector2.DOWN * 100, 20)
	var rock: Node2D = game.asteroids[0]
	game.update_asteroids(0.2)
	var velocity: Vector2 = rock.velocity
	check(velocity.x > 0 and not game.combat.controls_actor(rock), "asteroid bends through gravity while retaining inertia")
	a.finish_well()
	game.update_asteroids(0.2)
	check(rock.velocity == velocity and not game.combat.returns.has(rock.get_instance_id()), "asteroid keeps new trajectory after well ends")
	fresh()
	game.combat.press(0, game.ship.position)
	game.boss_timer = 0
	game.update_director(0.1)
	check(game.combat.firing(), "warning preserves held control")
	game.update_director(3.1)
	check(game.combat.firing(), "boss arrival preserves held control")
	game.boss.kind = "asteroid"
	game.boss.activate_special()
	check(game.combat.firing(), "tractor barrage introduction never drops the held pointer")
	var old_light: Vector3 = game.sector_light
	game.boss.take_hit(10000)
	check(game.sector_light == old_light and game.target_light != old_light, "boss victory schedules a gradual light transition without snapping")
	check(game.lingering_wells.size() == 1 and game.lingering_wells[0].has_method("draw_tractor_remnant"), "unfinished tractor attack retains a visible power source")
	fresh()
	game.instant_loss("A black hole collapsed your ship.")
	check(game.state == game.State.LOST and game.death_time > 0 and not game.interface.primary.visible, "fatal event freezes play but delays menu")
	game._process(0.6)
	check(not game.ship.visible and game.death_visual.pieces.size() > 10, "gravity death replaces the hull with crumbling plates")
	game._process(1.3)
	check(game.death_time == 0 and game.interface.primary.visible, "menu appears after death animation")
	game.free()
	await process_frame
	print("GRAVITY EVOLUTION: %d passed; %d failed" % [passed, failures])
	quit(0 if failures == 0 else 1)
