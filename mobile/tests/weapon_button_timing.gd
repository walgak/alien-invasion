extends SceneTree
## Drive the actual input router while stepping gameplay clocks deterministically.
## The haptic signal observes the same one-shot branch as the device call.
var game: Node2D
var passed := 0
var failed := 0
var feedback: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		push_error("FAIL: " + description)

func touch(id: int, at: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	await process_frame

func drag(id: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = at
	Input.parse_input_event(event)
	await process_frame

func button(id: int, control: Control) -> void:
	var at := control.get_global_rect().get_center()
	await touch(id, at, true)
	await touch(id, at, false)

func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000.0
	game.asteroid_timer = 1000.0
	game.boss_timer = 1000.0
	game.progress.vibration_enabled = false
	game.sound.enabled = false
	game.interface.refresh_special_buttons()
	feedback.clear()

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("weapon-button-timing-record.cfg"):
		push_error("Use a disposable weapon-button-timing-record.cfg save.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	game.combat.weapon_feedback_requested.connect(func(action: String): feedback.append(action))
	fresh()
	game.combat.gravity_charge = 30.0
	await touch(0, game.ship.position, true)
	await button(1, game.interface.gravity_button)
	check(game.combat.gravity_armed and game.combat.finger == 0 and game.combat.firing(), "gravity click preserves the existing steering finger")
	check(game.combat.gravity_selection_time == 3.0, "an accepted gravity click starts one three-second targeting window")
	for control in game.interface.special_buttons():
		await drag(0, control.get_global_rect().get_center())
	check(game.combat.finger == 0 and game.combat.gravity_selection_time == 3.0, "steering across buttons neither fires nor restarts the timer")
	game.combat.step(2.5)
	check(game.combat.gravity_preparation_time() < 0.0, "automatic precharge is absent before the final third-second")
	game.combat.step(0.49)
	check(game.lingering_wells.is_empty() and game.combat.pending_gravity_time < 0.0 and game.combat.gravity_armed, "automatic shot waits the full target selection window")
	check(game.combat.gravity_preparation_time() > 0.0 and game.combat.gravity_preparation_time() < 0.02 and game.combat.gravity_charge == 30.0, "final third-second shows muzzle precharge without reserving or spending charge")
	game.combat.step(0.01)
	check(not game.combat.gravity_armed and game.combat.pending_gravity_time < 0.0 and game.lingering_wells.size() == 1, "automatic launch occurs at three seconds with no extra preparation delay")
	check(game.combat.pending_gravity_target.is_equal_approx(game.arena * Vector2(0.5, 0.25)), "automatic aim is the middle of the upper half")
	check(game.combat.gravity_charge == 0.0 and game.combat.finger == 0, "automatic launch spends once while steering continues")
	game.combat.step(4.0)
	check(game.lingering_wells.size() == 1, "the targeting timer cannot create a second shot")
	fresh()
	game.combat.gravity_charge = 20.0
	await button(1, game.interface.gravity_button)
	await touch(0, Vector2(100, game.arena.y * 0.57), true)
	var before: float = game.ship.target_x
	await drag(0, Vector2(155, game.arena.y * 0.57))
	check(game.combat.finger == 0 and game.ship.target_x > before and game.combat.firing(), "fresh lower-half touches steer and fire while gravity is armed")
	check(game.combat.pending_gravity_time < 0.0 and game.combat.gravity_armed, "lower-half steering is never mistaken for a gravity destination")
	game.combat.step(2.99)
	await touch(1, Vector2(160, 310), true)
	await touch(1, Vector2(160, 310), false)
	check(game.combat.pending_gravity_target == Vector2(160, 310) and game.combat.finger == 0 and not game.combat.gravity_armed, "an upper-half tap can override automatic aim even during its final precharge without stealing steering")
	game.combat.step(0.32)
	check(game.lingering_wells.is_empty() and game.combat.gravity_charge == 20.0, "a late manual selection retains its full third-second preparation and bank")
	game.combat.step(0.02)
	game.combat.step(4.0)
	check(game.lingering_wells.size() == 1 and game.lingering_wells[0].well_position == Vector2(160, 310), "manual aim cancels the automatic shot permanently")
	fresh()
	game.combat.gravity_charge = 20.0
	await button(1, game.interface.gravity_button)
	await touch(2, Vector2(160, 310), true)
	await touch(2, Vector2(160, 310), false, true)
	check(game.combat.gravity_armed and game.combat.pending_gravity_time < 0.0, "canceled target taps leave automatic targeting available")
	await button(1, game.interface.gravity_button)
	game.combat.step(4.0)
	check(not game.combat.gravity_armed and game.combat.pending_gravity_time < 0.0 and game.combat.gravity_charge == 20.0, "a second gravity click cancels without spending charge")
	await button(1, game.interface.gravity_button)
	game.combat.step(1.5)
	game.pause_run()
	check(not game.combat.gravity_armed and game.combat.gravity_selection_time == 0.0 and game.combat.gravity_charge == 20.0, "pause clears automatic targeting without spending charge")
	fresh()
	game.combat.gravity_charge = 20.0
	await button(1, game.interface.gravity_button)
	game.begin_boss("black")
	game.boss.phase = "active"
	game.boss.well_position = Vector2(270, 480)
	game.combat.step(3.1)
	check(not game.combat.gravity_armed and game.combat.pending_gravity_time < 0.0 and game.combat.gravity_charge == 20.0, "unshielded boss gravity cancels automatic targeting before it fires")
	fresh()
	game.combat.gravity_charge = 20.0
	game.combat.laser_stock = 2
	game.progress.vibration_enabled = true
	await button(1, game.interface.gravity_button)
	await button(1, game.interface.gravity_button)
	await button(1, game.interface.laser_use_button)
	await button(1, game.interface.laser_use_button)
	check(feedback == ["gravity", "gravity", "laser", "laser"], "each accepted arm/cancel and laser toggle emits exactly one device feedback event")
	game.combat.step(0.5)
	check(feedback.size() == 4, "holding or advancing frames never repeats button feedback")
	await button(1, game.interface.cannon_button)
	await button(1, game.interface.electron_button)
	check(feedback.size() == 4, "unavailable attacks never emit a successful activation pulse")
	game.spawn_enemy(Vector2(220, 350), Vector2.ZERO)
	await button(1, game.interface.cannon_button)
	check(feedback.back() == "cannon" and feedback.size() == 5, "successful cannon volleys have a single tactile click")
	game.combat.electron_stock = 1
	await button(1, game.interface.electron_button)
	check(feedback.back() == "electron" and feedback.size() == 6, "successful electron activation has a single tactile click")
	game.progress.vibration_enabled = false
	await button(1, game.interface.laser_use_button)
	check(feedback.size() == 6, "the saved vibration toggle mutes all weapon button pulses")
	game.combat.stop_haptics()
	game.free()
	await process_frame
	print("WEAPON BUTTON TIMING: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
