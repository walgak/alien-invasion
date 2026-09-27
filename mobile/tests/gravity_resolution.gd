extends SceneTree
## Frozen encounter lifetimes, resultant force, finite pressure-front release,
## cannon interception, and the visible transition from boss hull to death well.
var game: Node2D
var failures := 0
var checks := 0
var directory := ""

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

func field(kind: String, at: Vector2, seconds: float = 4.0) -> Node2D:
	var well = game.Boss.new()
	well.game = game
	well.kind = kind
	well.lingering = true
	well.phase = "active"
	well.well_position = at
	well.well_duration = seconds
	game.add_child(well)
	game.lingering_wells.append(well)
	return well

func capture(label: String) -> void:
	if directory.is_empty():
		return
	game.state = game.State.PLAYING
	game.interface.refresh()
	game.refresh_space()
	game.gravity_fields.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("gravity-resolution-record.cfg"):
		quit(1)
		return
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	fresh()
	var a := field("black", Vector2(100, 400), 2.0)
	var b := field("black", Vector2(440, 400), 3.0)
	a.step(1.0)
	b.step(1.0)
	check(a.phase_time == 0.0 and b.phase_time == 0.0, "two fields pause both lifetime clocks")
	game.gravity_fields.step(0.5)
	check(a.well_position.distance_to(b.well_position) < 340.0, "paused black fields continue converging")
	b.well_position = a.well_position + Vector2(30, 0)
	game.gravity_fields.step(0.0)
	check(game.lingering_wells.size() == 1 and is_equal_approx(game.gravity_fields.seconds_left(a), 5.0), "merger preserves the sum of frozen remaining seconds")
	a.step(0.25)
	check(is_equal_approx(game.gravity_fields.seconds_left(a), 4.75), "lone merged survivor resumes its lifetime")
	fresh()
	a = field("black", Vector2(100, 400), 0.1)
	b = field("white", Vector2(440, 400), 0.1)
	game.gravity_fields.step(0.5)
	a.step(0.5)
	b.step(0.5)
	check(a.well_position.distance_to(b.well_position) < 340.0 and a.phase_time == 0.0 and b.phase_time == 0.0, "mixed fields converge without expiring first")
	for frame in range(80):
		game.gravity_fields.step(0.1)
	check(game.gravity_fields.active_wells().is_empty() and game.lives == 3, "mixed convergence resolves with a player-safe annihilation")
	fresh()
	a = field("white", Vector2(80, 420), 0.1)
	b = field("white", Vector2(460, 620), 0.1)
	var initial_distance: float = a.well_position.distance_to(b.well_position)
	game.gravity_fields.step(0.2)
	check(a.well_position.distance_to(b.well_position) > initial_distance, "white centers continue repelling")
	check(a.pressure_front_radius > 31.0 and b.pressure_front_radius > 31.0, "white pressure fronts expand independently of centers")
	await capture("white-pressure-fronts")
	for frame in range(100):
		game.gravity_fields.step(0.1)
	check(game.gravity_fields.active_wells().is_empty() and game.gravity_fields.exits.size() == 2, "white pressure fronts discharge both fields in finite time")
	fresh()
	a = field("black", Vector2(100, 500))
	b = field("black", Vector2(440, 500))
	game.ship.position = Vector2(270, 800)
	var force: Vector2 = game.gravity_fields.net_force_for(game.ship)
	game.lingering_wells.reverse()
	check(force.is_equal_approx(game.gravity_fields.net_force_for(game.ship)) and is_zero_approx(force.x) and force.y < 0.0, "resultant force is order-independent and cancels opposed horizontal components")
	var before: Vector2 = game.ship.position
	a.resist()
	b.resist()
	game.gravity_fields.apply_player_force(0.1)
	check(game.ship.position == before, "taps cancel resultant motion exactly")
	a.neutralise_time = 0.0
	b.neutralise_time = 0.0
	game.gravity_fields.apply_player_force(0.1)
	check(game.ship.position.is_equal_approx(before + force * 0.1), "player integrates the summed force exactly once")
	game.combat.shield_time = 2.0
	check(game.gravity_fields.net_force_for(game.ship) == Vector2.ZERO, "collected full shield cancels resultant gravity")
	fresh()
	a = field("black", game.ship.position, 0.01)
	game.gravity_fields.apply_player_force(0.02)
	check(game.state == game.State.PLAYING and game.gravity_fields.active_wells().is_empty(), "expiration wins over last-frame lethal core contact")
	fresh()
	a = field("black", Vector2(270, 400))
	var collision: Dictionary = game.gravity_fields.intercept_cannon(Vector2(80, 400), Vector2(500, 400), null)
	check(not collision.is_empty() and is_equal_approx(collision.at.distance_to(a.well_position), 33.0), "fast gravity cannon stops just outside the first horizon")
	check(game.gravity_fields.intercept_cannon(Vector2(400, 400), Vector2(500, 400), null).is_empty(), "a horizon behind a cannon never registers a false intercept")
	check(game.gravity_fields.intercept_cannon(Vector2(80, 600), Vector2(500, 600), null).is_empty(), "nonintersecting cannon travel remains unchanged")
	fresh()
	game.begin_boss("black")
	game.boss.begin_special()
	check(game.boss.well_scale == 1.0, "first gravity boss uses the baseline size")
	game.bosses_defeated = 30
	game.boss.begin_special()
	var middle: float = game.boss.well_scale
	game.bosses_defeated = 1000
	game.boss.begin_special()
	check(middle > 1.0 and middle < game.boss.well_scale and game.boss.well_scale <= 1.7, "difficulty grows boss holes smoothly to the size cap")
	game.ship.position = game.arena * Vector2(0.5, 0.635)
	game.boss.position_gravity_hole()
	check(game.boss.well_position.distance_to(game.ship.position) >= game.boss.gravity_spawn_clearance(), "largest boss core still has safe spawn clearance")
	for kind in ["black", "white"]:
		fresh()
		game.begin_boss(kind)
		game.boss.body_position = Vector2(270, 380)
		game.boss.phase = "firefight"
		game.gravity_fields.add_boss_collapse(game.boss)
		game.boss.visible = false
		var effect: Node2D = game.gravity_fields.collapses.back()
		effect.step(0.3)
		check(not effect.opened and effect.hull.visible and game.lingering_wells.is_empty(), kind + " boss visibly transforms before a death field exists")
		await capture(kind + "-boss-collapse")
		effect.step(0.4)
		check(effect.opened and not effect.hull.visible and game.lingering_wells.size() == 1 and game.lingering_wells[0].well_duration == 8.0, kind + " transformed hull opens one eight-second death field")
		await capture(kind + "-boss-death-field")
	game.free()
	await process_frame
	print("GRAVITY RESOLUTION: %d passed; %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
