extends SceneTree
## Exercise actual engine input dispatch, not just button callbacks. Disposable
## saves ensure repeated desktop tests never change a player's phone record.
var game: Node2D
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		push_error("FAIL: " + description)

func touch(id: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func drag(id: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = at
	Input.parse_input_event(event)
	await process_frame

func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000.0
	game.asteroid_timer = 1000.0
	game.boss_timer = 1000.0
	game.progress.vibration_enabled = false
	game.sound.enabled = false
	game.interface.refresh_special_buttons()

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("glass-controls-record.cfg"):
		push_error("Use a disposable glass-controls-record.cfg save.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	fresh()
	var controls: Array = game.interface.special_buttons()
	check(controls.size() == 4, "four special weapons have dedicated controls")
	for button in controls:
		check(button.size.x == button.size.y and button.position.x > game.arena.x * 0.8 and button.position.y < game.cruise_position().y, "glass controls are circular and above the right flight lane")
		check(button.mouse_filter == Control.MOUSE_FILTER_IGNORE and button.text.is_empty(), "icons have no native GUI hit region to steal steering")
	game.combat.laser_stock = 3
	game.combat.electron_stock = 2
	game.combat.gravity_charge = 50.0
	await touch(0, game.ship.position, true)
	for button in controls:
		await drag(0, button.get_global_rect().get_center())
		check(game.combat.finger == 0 and game.combat.firing(), "steering and firing survive dragging over a special control")
	check(game.combat.laser_stock == 3 and game.combat.electron_stock == 2 and not game.combat.gravity_armed, "crossing icons never deploys a special weapon")
	await touch(0, controls[0].get_global_rect().get_center(), false)
	check(game.combat.finger == -1 and not game.combat.firing(), "lifting over a control releases the original steering gesture")
	# The lower corner is inside the flight lane but outside the circular lens.
	var corner: Vector2 = controls[0].global_position + Vector2(2, controls[0].size.y-2)
	await touch(0, corner, true)
	check(game.combat.finger == 0 and game.interface.special_touches.is_empty(), "transparent corners remain usable for ship control")
	var at: Vector2 = controls[1].get_global_rect().get_center()
	await touch(1, at, true)
	await touch(1, at, false)
	check(game.combat.finger == 0 and game.combat.laser_active and game.combat.laser_stock == 2, "a second finger activates exactly one laser without replacing steering")
	await touch(0, corner, false)
	# Dragging out of the lens cancels activation without accidentally steering.
	game.combat.laser_active = false
	await touch(1, at, true)
	await drag(1, Vector2(270, 810))
	await touch(1, Vector2(270, 810), false)
	check(game.combat.finger == -1 and game.combat.laser_stock == 2, "dragging off a button neither spends stock nor becomes steering")
	fresh()
	game.spawn_enemy(Vector2(240, game.playfield_top()+25), Vector2.ZERO)
	var enemy: Node2D = game.enemies.back()
	game.combat.press(1, enemy.position)
	game.combat.release(1, enemy.position)
	check(game.combat.missiles == 29, "removing the top bar also removes its invisible targeting strip")
	for tier in range(5):
		game.weapons.level = tier
		check(game.combat.shield_radius() >= game.Ship.Artwork.size_for(tier).x * 0.5 + 8.0, "shield encloses upgraded wingspan at tier %d" % tier)
	fresh()
	for index in range(30):
		game.combat.collect_electron()
	check(game.combat.electron_stock == 10, "electron inventory cannot exceed ten")
	check(not game.combat.activate_electron() and game.combat.electron_stock == 10, "empty-screen electron activation never spends a charge")
	game.spawn_enemy(Vector2(game.ship.position.x, 350), Vector2.ZERO)
	check(game.combat.activate_electron() and game.combat.electron_stock == 9, "a successful chain spends exactly one electron charge")
	game.begin_boss("black")
	game.boss.phase = "active"
	game.boss.well_position = Vector2(270, 520)
	check(not game.combat.activate_electron() and game.combat.electron_stock == 9, "forced gravity tapping blocks electron launch without spending inventory")
	fresh()
	check(game.combat.electron_stock == 0, "new runs reset electron inventory")
	var capture := OS.get_environment("ALIEN_GLASS_CAPTURE")
	if not capture.is_empty():
		game.combat.shield_time = 10.0
		game.combat.gravity_charge = 36.0
		game.combat.laser_stock = 7
		game.combat.electron_stock = 3
		game.visual_time = 7.0
		game.combat.update_attitudes(0.0)
		game.refresh_space()
		game.interface.refresh_special_buttons()
		game.interface.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture) == OK, "actual glass HUD frame captured")
	game.free()
	await process_frame
	print("GLASS CONTROLS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
