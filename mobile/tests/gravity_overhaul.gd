extends SceneTree
## Focused regressions for recovery from the upper screen, merged fields,
## non-recursive charge rewards, whole-hull avoidance, and white-edge discharge.
var game: Node2D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func fresh() -> void:
	game.start_run()
	game.wave_timer = 10000.0
	game.boss_timer = 10000.0
	game.asteroid_timer = 10000.0

func field(kind: String, at: Vector2, duration: float = 4.0) -> Node2D:
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

func player_field(at: Vector2, charge: float = 1.0) -> Node2D:
	var well = game.PlayerWell.new()
	well.game = game
	well.charge = charge
	well.cannon_position = at
	well.well_position = at
	game.add_child(well)
	game.lingering_wells.append(well)
	well.step(0.0)
	return well

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("gravity-overhaul-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	fresh()
	var well := player_field(Vector2(270, 400))
	check(is_equal_approx(well.remaining, 3.0), "minimum charge lasts three seconds")
	well.finish_well()
	well = player_field(Vector2(270, 400), 5.0)
	check(is_equal_approx(well.remaining, 7.5) and is_equal_approx(well.well_scale, 1.8 * sqrt(5.0)), "maximum lifetime and size remain unchanged")
	fresh()
	game.ship.position = Vector2(120, 250)
	game.ship.target_x = 120.0
	well = field("black", Vector2(400, 500), 0.01)
	well.step(0.02)
	check(game.returning_to_cruise, "ordinary black-hole expiration schedules recovery above screen midpoint")
	game._physics_process(0.1)
	check(game.ship.position.y > 250.0 and game.ship.position.x == 120.0, "recovery moves smoothly down and preserves X")
	fresh()
	game.ship.position = Vector2(105, 230)
	game.ship.target_x = 105.0
	well = player_field(Vector2(440, 400))
	well.step(0.0)
	check(not well.origins.has(game.ship.get_instance_id()), "a player hole never stores an upper-screen ship return destination")
	var other := field("black", Vector2(100, 500))
	well.finish_well()
	game.combat.shield_time = 10.0
	game._physics_process(0.1)
	check(is_equal_approx(game.ship.position.y, 230.0), "recovery waits for overlapping gravity even with a collected shield")
	other.return_to_firefight()
	for i in range(30):
		game._physics_process(0.1)
	check(is_equal_approx(game.ship.position.y, game.cruise_position().y) and game.ship.position.x == 105.0, "last overlapping field restores normal cruise height only")
	fresh()
	well = player_field(Vector2(270, 400))
	game.spawn_enemy(Vector2(270, 400), Vector2.ZERO)
	well.step(0.0)
	check(game.enemies.is_empty() and game.combat.gravity_charge == 0.0, "swallowing aliens never funds another gravity weapon")
	other = field("white", Vector2(280, 400))
	game.spawn_enemy(Vector2(300, 420), Vector2.ZERO)
	game.gravity_fields.step(0.0)
	game.gravity_fields.step(0.36)
	check(game.enemies.is_empty() and game.combat.gravity_charge == 0.0, "safe annihilation kills never replenish gravity charge")
	check(game.gravity_fields.exits.any(func(effect: Dictionary) -> bool: return effect.kind == "white"), "annihilating white hole emits its exit burst")
	fresh()
	game.begin_boss("swarm")
	game.boss.step(1.5)
	well = player_field(Vector2(270, game.boss.body_position.y), 5.0)
	other = player_field(Vector2(80, game.boss.body_position.y + 150.0), 2.0)
	var always_clear := true
	for i in range(90):
		game.boss.step(0.02)
		always_clear = always_clear and game.boss.player_well_clearance(game.boss.body_position) >= 0.0
	check(always_clear, "boss patrol keeps its whole hull outside every live player horizon")
	check(game.boss.has_player_gravity_threat(), "gravity-only boss shield remains through the complete field lifetime")
	var old_health: float = game.boss.health
	game.boss.take_hit(1)
	check(game.boss.health == old_health - 1.0, "gravity shield does not block normal weapon damage")
	fresh()
	well = field("white", Vector2(270, 550))
	game.refresh_space()
	check(game.space_folds.white_edge_strength == 1.0, "active white hole refracts the screen boundary")
	well.return_to_firefight()
	game.refresh_space()
	check(game.space_folds.white_edge_strength == 0.0 and game.space_folds.white_edge_release == 1.0, "white expiration releases its screen bubble with a light burst")
	game.gravity_fields.visual_step(1.3)
	game.refresh_space()
	check(game.space_folds.white_edge_release == 0.0, "white departure refraction is finite")
	game.free()
	await process_frame
	print("GRAVITY OVERHAUL: %d passed; %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
