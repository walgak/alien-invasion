extends SceneTree
## Exercise inventory and simultaneous steering/targeting using a disposable save.
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

func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000.0
	game.asteroid_timer = 1000.0
	game.boss_timer = 1000.0
	game.progress.vibration_enabled = false
	game.sound.enabled = false
	game.interface.refresh_special_buttons()

func target_enemy(at: Vector2, hp: int = 3) -> Node2D:
	game.spawn_enemy(at, Vector2.ZERO)
	var enemy: Node2D = game.enemies.back()
	enemy.health = hp
	return enemy

## Direct UI routing preserves all independent touch indices, including a
## second finger while the operating system's mouse emulation owns the first.
func button_touch(id: int, button: Button) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = id
		event.position = button.get_global_rect().get_center()
		event.pressed = down
		check(game.interface.route_special_touch(event), "special button captures its own touch %s" % down)

func routed_touch(id: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("special-buttons-record.cfg"):
		push_error("Use a disposable special-buttons-record.cfg save.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	fresh()
	game.weapons.level = 2
	game.combat.collect_laser()
	game.combat.collect_laser()
	check(game.combat.laser_stock == 2 and game.weapons.level == 2, "laser pickups bank without replacing primary guns")
	game.combat.activate_laser()
	check(game.combat.laser_stock == 1 and game.weapons.level == 3 and game.combat.laser_time == 10.0, "laser button spends exactly one charge")
	game.combat.step(2.0)
	check(game.combat.laser_time == 10.0, "selected laser does not consume time while idle")
	game.combat.press(0, game.ship.position)
	game.combat.step(2.0)
	check(game.combat.laser_time == 8.0, "laser consumes only actual firing time")
	game.combat.activate_laser()
	game.combat.step(2.0)
	check(game.weapons.level == 2 and game.combat.laser_time == 8.0, "laser toggle restores guns and preserves partial charge")
	game.combat.activate_laser()
	check(game.combat.laser_stock == 1 and game.combat.laser_time == 8.0, "resuming partial laser does not spend another pickup")
	game.combat.step(8.01)
	check(game.weapons.level == 2 and not game.combat.laser_active and game.combat.laser_stock == 1, "laser expiry never auto-consumes the next charge")
	for index in range(150):
		game.combat.collect_laser()
	check(game.combat.laser_stock == 99, "laser stock caps at ninety-nine")
	fresh()
	game.combat.press(0, Vector2(270, 400))
	game.combat.step(5.0)
	game.combat.release(0, Vector2(270, 400))
	check(game.lingering_wells.is_empty(), "holding empty space no longer fires gravity")
	game.combat.arm_gravity()
	check(not game.combat.gravity_armed, "gravity cannot arm below ten eligible kills")
	game.combat.add_gravity_charge(20.0)
	game.combat.press(0, game.ship.position)
	button_touch(1, game.interface.gravity_button)
	check(game.combat.gravity_armed and game.combat.finger == 0 and game.combat.firing(), "second-finger gravity button retains steering and primary fire")
	game.combat.press(1, Vector2(250, 400))
	game.combat.step(0.4)
	check(game.lingering_wells.is_empty() and game.combat.pending_gravity_time < 0.0, "target remains unlaunched while its finger obscures it")
	game.combat.release(1, Vector2(250, 400))
	check(game.combat.finger == 0 and game.combat.pending_gravity_charge == 2.0, "target release queues charge without releasing steering")
	game.combat.release(0, game.ship.position)
	game.combat.step(0.32)
	check(game.lingering_wells.is_empty(), "gravity waits the full third of a second after target release")
	game.combat.add_gravity_charge(2.0)
	game.combat.step(0.02)
	check(game.lingering_wells.size() == 1 and game.combat.gravity_charge == 2.0, "ordinary release preserves launch and newer kills remain banked")
	var well: Node2D = game.lingering_wells[0]
	check(well.charge == 2.0 and well.well_position == Vector2(250, 400), "launch retains the selected charge and destination")
	fresh()
	game.combat.add_gravity_charge(100.0)
	check(game.combat.gravity_charge == 50.0, "gravity bank caps at fifty eligible kills")
	game.combat.arm_gravity()
	game.combat.press(0, Vector2(270, 400))
	game.combat.release(0, Vector2(270, 400))
	game.pause_run()
	check(game.combat.pending_gravity_time < 0.0 and game.combat.gravity_charge == 50.0, "pause cancels queued gravity without spending its charge")
	fresh()
	game.combat.add_gravity_charge(20.0)
	game.combat.arm_gravity()
	game.combat.press(0, Vector2(270,400))
	game.combat.release(0, Vector2(270,400))
	game.begin_boss("black")
	game.boss.phase = "active"
	game.boss.well_position = Vector2(400,500)
	game.combat.step(0.4)
	check(game.combat.pending_gravity_time < 0.0 and game.lingering_wells.is_empty() and game.combat.gravity_charge == 20.0, "an unshielded gravity attack cancels preparation without spending the bank")
	fresh()
	var near: Node2D = target_enemy(Vector2(270, 680), 7)
	var far: Node2D = target_enemy(Vector2(180, 350), 6)
	game.combat.missiles = 5
	var fired: int = game.combat.fire_cannon_volley()
	var near_shots := 0
	for shot in game.projectiles:
		if shot.homing_target == near:
			near_shots += 1
	check(fired == 5 and near_shots == 3 and game.combat.missiles == 0, "limited volley allocates lethal damage to the nearest escaping aliens first")
	game.combat.missiles = 5
	check(game.combat.fire_cannon_volley() == 0 and game.combat.missiles == 5, "in-flight cannons reserve damage and prevent duplicate overkill")
	fresh()
	var single: Node2D = target_enemy(Vector2(270, 400), 3)
	game.combat.missiles = 5
	check(game.combat.fire_cannon_volley() == 1 and game.combat.missiles == 4, "five is the activation threshold, not mandatory ammunition expenditure")
	check(game.combat.fire_cannon_volley() == 0, "volley stays unavailable below five cannons")
	game.combat.press(0, game.ship.position)
	game.combat.press(1, single.position)
	game.combat.release(1, single.position)
	check(game.combat.missiles == 3 and game.combat.finger == 0, "one target tap spends shared cannon stock while steering continues")
	fresh()
	game.weapons.level = 4
	var cadence: float = game.weapons.fire(game)
	var all_plasma: bool = game.projectiles.size() == 3
	for shot in game.projectiles:
		all_plasma = all_plasma and shot.kind == "plasma" and shot.damage == 2 and is_equal_approx(shot.velocity.length(), 850.0)
	check(all_plasma and is_equal_approx(cadence, 0.17), "maximum primary has three plasma streams, fixed speed, fixed cadence and two damage")
	game.combat.collect_laser()
	game.combat.press(0, game.ship.position)
	button_touch(1, game.interface.laser_use_button)
	check(game.combat.laser_active and game.combat.finger == 0, "laser button can activate under a held steering finger")
	game.begin_boss("black")
	game.boss.phase = "active"
	game.boss.well_position = Vector2(270, 430)
	check(game.combat.gravity_blocks_control() and game.combat.hazards_protected(), "forced tapping grants incoming-hazard protection without gravity immunity")
	game.combat.shield_time = 10.0
	check(not game.combat.gravity_blocks_control() and game.combat.hazards_protected(), "collected shield still allows full gravity counterattack control")
	fresh()
	game.weapons.level = 4
	game.combat.add_gravity_charge(50.0)
	game.combat.laser_stock = 7
	game.interface.refresh_special_buttons()
	await routed_touch(0, game.ship.position, true)
	var laser_at: Vector2 = game.interface.laser_use_button.get_global_rect().get_center()
	await routed_touch(1, laser_at, true)
	await routed_touch(1, laser_at, false)
	check(game.combat.finger == 0 and game.combat.laser_active and game.combat.laser_stock == 6, "real GUI input routes a second-finger laser tap exactly once")
	var gravity_at: Vector2 = game.interface.gravity_button.get_global_rect().get_center()
	await routed_touch(1, gravity_at, true)
	await routed_touch(1, gravity_at, false)
	await routed_touch(1, Vector2(220, 400), true)
	await routed_touch(1, Vector2(220, 400), false)
	check(game.combat.finger == 0 and game.combat.pending_gravity_time > 0.0, "real GUI target release queues gravity while steering survives")
	await routed_touch(0, game.ship.position, false)
	check(not game.combat.firing() and game.combat.pending_gravity_time > 0.0, "real GUI steering release cannot cancel queued gravity")
	# Optional graphics run saves the actual GUI and preparation effect, not a mockup.
	var capture := OS.get_environment("ALIEN_SPECIAL_CAPTURE")
	if not capture.is_empty():
		game.combat.activate_laser()
		game.ship.weapon_level = 4
		game.combat.step(0.16)
		game.elapsed = 8.0
		target_enemy(Vector2(130, 360), 6)
		target_enemy(Vector2(340, 470), 3)
		game.weapons.fire(game)
		game.refresh_space()
		game.interface.refresh_special_buttons()
		game.interface.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(capture)
		check(error == OK, "actual rendered special-weapon panel captured")
	game.free()
	await process_frame
	print("SPECIAL BUTTONS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
