extends SceneTree
## Routes input through Godot's GUI and input pipeline, rather than calling handlers.

var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func run_checks() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	await click(game.interface.mode_buttons["white"].get_global_rect().get_center())
	check(game.selected_mode == "white", "the visible flight selector changes the encounter")
	await click(game.interface.primary.get_global_rect().get_center())
	check(game.state == game.State.PLAYING and game.encounter == "white", "the launch button starts the selected boss")
	await click(game.interface.pause_button.get_global_rect().get_center())
	check(game.state == game.State.PAUSED, "the pause button intercepts a gameplay click")
	await click(game.interface.primary.get_global_rect().get_center())
	check(game.state == game.State.PLAYING, "the resume button returns to flight")
	game.boss.begin_special()
	game.boss.step(1.3)
	await click(Vector2(220, 820))
	check(is_equal_approx(game.boss.resistance, 0.36), "one routed mouse click produces exactly one resistance impulse")
	game.boss.resistance = 0
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = Vector2(220, 820)
		touch.pressed = down
		Input.parse_input_event(touch)
		await process_frame
	check(is_equal_approx(game.boss.resistance, 0.36), "one routed touch produces exactly one resistance impulse")
	game.free()
	await process_frame
	print("INPUT FLOW: %d failures" % failures)
	quit(0 if failures == 0 else 1)
