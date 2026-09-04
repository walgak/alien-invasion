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
	var edges := [
		{"name": "bottom", "at": Vector2(270, 780), "direction": Vector2.DOWN},
		{"name": "left", "at": Vector2(60, 780), "direction": Vector2.LEFT},
		{"name": "right", "at": Vector2(480, 780), "direction": Vector2.RIGHT},
		{"name": "top", "at": Vector2(270, 60), "direction": Vector2.UP},
		{"name": "bottom near a corner", "at": Vector2(90, 910), "direction": Vector2.DOWN}
	]
	for edge in edges:
		prepare("white", edge.at)
		check(game.boss.white_push_direction == edge.direction, "white: selects the nearest " + edge.name + " edge")
		var away: Vector2 = (game.ship.position - game.boss.well_position).normalized()
		check(away.is_equal_approx(edge.direction), "white: spawns on the opposite side to push toward " + edge.name)
		game.boss.step(0.1)
		var displacement: Vector2 = game.ship.position - edge.at
		check(displacement.dot(edge.direction) > 0 and absf(displacement.cross(edge.direction)) < 0.001, "white: force moves only toward " + edge.name)
	# Player movement during the warning cannot leave the hole targeting a far edge.
	game.start_run("white")
	game.boss.begin_special()
	game.ship.position.x = 50
	game.ship.target_x = 50
	game.boss.step(0.1)
	check(game.boss.white_push_direction == Vector2.LEFT and game.boss.well_position.x > game.ship.position.x, "white: forming hole follows the nearest edge during the warning")
	game.boss.step(1.2)
	var fixed_hole: Vector2 = game.boss.well_position
	game.boss.step(0.1)
	check(game.boss.well_position == fixed_hole, "white: the active hole remains fixed while it pushes")
	for at in [Vector2(27, 480), Vector2(513, 480), Vector2(270, 27), Vector2(270, 933)]:
		prepare("white", at)
		game.boss.step(0.1)
		check(game.state == game.State.LOST and game.lives == 0 and not game.particles.is_empty(), "white: contact with boundary at %s destroys the ship" % at)
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
