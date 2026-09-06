extends SceneTree
## Taps cancel hole force without adding thrust; white holes target all four edges.

var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if condition:
		checks += 1
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func prepare(mode: String, at: Vector2 = Vector2(270, 780)) -> void:
	game.start_run(mode)
	game.ship.position = at
	game.ship.target_x = at.x
	game.boss.begin_special()
	game.boss.step(1.3)

func run_checks() -> void:
	var save_path := OS.get_environment("ALIEN_SAVE_PATH")
	if not save_path.ends_with("hole-physics-record.cfg"):
		push_error("Use a temporary ALIEN_SAVE_PATH ending in hole-physics-record.cfg.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	for mode in ["black", "white"]:
		prepare(mode)
		var original: Vector2 = game.ship.position
		for i in range(20):
			game.boss.resist()
		check(game.ship.position == original, mode + ": taps themselves never change position")
		game.boss.step(0.2)
		check(game.ship.position == original, mode + ": an active tap window holds the current position exactly")
		for i in range(36):
			if i % 12 == 0:
				game.boss.resist()
			game._physics_process(1.0 / 60.0)
		check(game.ship.position == original, mode + ": sustained tapping stays still through the real game loop")
		prepare(mode)
		original = game.ship.position
		game.boss.step(0.1)
		var unresisted_motion: Vector2 = game.ship.position - original
		prepare(mode)
		game.boss.resist()
		game.boss.step(0.1)
		check(game.ship.position == original, mode + ": one tap eliminates the force instead of reducing it")
		prepare(mode)
		game.boss.step(0.1)
		var drifted: Vector2 = game.ship.position
		game.boss.resist()
		game.boss.step(0.2)
		check(game.ship.position == drifted, mode + ": taps cannot recover ground already lost")
		game.boss.step(0.05)
		check(game.ship.position == drifted, mode + ": the tap window blocks force until it expires")
		game.boss.step(0.1)
		check((game.ship.position - drifted).dot(unresisted_motion) > 0, mode + ": the original force resumes at full strength after the tap window")
	for mode in ["black", "white"]:
		for at in [Vector2(60, 780), Vector2(480, 780), Vector2(270, 780), Vector2(270, 600)]:
			prepare(mode, at)
			var well: Vector2 = game.boss.well_position
			check(well.x >= 540 * 0.28 - 0.01 and well.x <= 540 * 0.72 + 0.01 and well.y >= 960 * 0.57 - 0.01 and well.y <= 960 * 0.70 + 0.01, mode + ": hole stays in lower-middle region")
			check(well.distance_to(at) >= 118.0, mode + ": hole opens with safe clearance")
			game.boss.step(0.1)
			var movement: Vector2 = game.ship.position - at
			check(movement.dot(well - at) * (1 if mode == "black" else -1) > 0, mode + ": force acts toward or away from its fixed core")
	game.start_run("white")
	game.boss.begin_special()
	var target: Vector2 = game.boss.well_position
	game.ship.position.x = 50
	game.boss.step(0.1)
	check(game.boss.well_position == target, "cannon destination does not track horizontal steering")
	game.start_run("black")
	game.boss.begin_special()
	game.ship.position = game.boss.well_position
	game.boss.step(1.3)
	check(game.state == game.State.PLAYING and game.boss.phase == "warning", "unsafe landing redirects cannon before a core can open")
	prepare("white")
	game.boss.step(0.2)
	var pushed_y: float = game.ship.position.y
	game.boss.return_to_firefight()
	game._physics_process(1.0 / 60.0)
	check(is_equal_approx(game.ship.position.y, pushed_y), "the firefight preserves vertical ground lost to the white hole")
	# A resize must preserve the vertical ship/hole separation, not collapse it.
	prepare("white")
	game.boss.step(0.2)
	var previous_ship: Vector2 = game.ship.position
	var previous_hole: Vector2 = game.boss.well_position
	root.size = Vector2i(600, 1000)
	game.update_layout()
	var scale_factor: Vector2 = game.arena / Vector2(540, 960)
	check(game.ship.position.is_equal_approx(previous_ship * scale_factor) and game.boss.well_position.is_equal_approx(previous_hole * scale_factor), "resizing preserves ship position and the hole's vertical separation")
	game.free()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	await process_frame
	print("HOLE PHYSICS: %d passed; %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)
