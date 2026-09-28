extends SceneTree
## Real fixed-step checks for continuous offscreen boss avoidance and mass/time
## conservation while two horizons join through an opaque liquid neck.
var game: Node2D
var failed := 0
var passed := 0
var capture_directory := OS.get_environment("ALIEN_CAPTURE_DIR")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000.0
	game.boss_timer = 1000.0
	game.asteroid_timer = 1000.0
	game.combat.shield_time = 1000.0
	game.progress.vibration_enabled = false

func make_well(at: Vector2, charge: float = 1.0) -> Node2D:
	var well = game.PlayerWell.new()
	well.game = game
	well.charge = charge
	well.well_position = at
	well.cannon_position = at
	game.add_child(well)
	game.lingering_wells.append(well)
	well.step(0.0)
	return well

func capture(label: String) -> void:
	if capture_directory.is_empty():
		return
	game.state = game.State.PLAYING
	game.refresh_space()
	game.gravity_fields.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join(label + ".png"))

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("dodge-coalescence.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	fresh()
	game.begin_boss("black")
	var boss: Node2D = game.boss
	boss.phase = "firefight"
	boss.cooldown = 1000.0
	boss.shot_timer = 1000.0
	boss.body_position = Vector2(270, game.top_inset + 250)
	var target: Vector2 = boss.body_position
	game.combat.pending_gravity_time = 1.0 / 3.0
	game.combat.pending_gravity_charge = 5.0
	game.combat.pending_gravity_target = target
	var previous: Vector2 = boss.body_position
	var maximum_step := 0.0
	# Include pending cannon animation and realistic rocket flight anticipation.
	for frame in range(50):
		boss.step(1.0 / 60.0)
		maximum_step = maxf(maximum_step, boss.body_position.distance_to(previous))
		previous = boss.body_position
	game.combat.pending_gravity_time = -1.0
	var well := make_well(target, 5.0)
	var minimum_clearance := INF
	var farthest_from_screen := 0.0
	for frame in range(360):
		well.well_position += Vector2(sin(float(frame) * 0.025) * 0.5, 0.0)
		boss.step(1.0 / 60.0)
		maximum_step = maxf(maximum_step, boss.body_position.distance_to(previous))
		minimum_clearance = minf(minimum_clearance, boss.player_well_clearance(boss.body_position, false))
		farthest_from_screen = minf(farthest_from_screen, boss.body_position.y)
		previous = boss.body_position
	check(maximum_step < 14.0, "moving maximum-charge well never grid-snaps or teleports the boss")
	check(minimum_clearance >= -0.01, "entire boss hull remains outside the moving event horizon")
	check(farthest_from_screen < -20.0, "boss can retreat offscreen instead of shuddering against a screen boundary")
	await capture("boss-offscreen-dodge")
	well.finish_well()
	for frame in range(300):
		boss.step(1.0 / 60.0)
		maximum_step = maxf(maximum_step, boss.body_position.distance_to(previous))
		previous = boss.body_position
	check(absf(boss.body_position.y - (game.top_inset + 250.0)) < 1.0 and maximum_step < 14.0, "boss smoothly returns to its patrol after the hole closes")
	# Two pre-existing active fields are an adversarial spawn/merge case: the
	# radial safety projection must still find a clear position, never oscillate.
	fresh()
	var first := make_well(Vector2(207, 500), 1.0)
	var second := make_well(Vector2(333, 500), 1.0)
	first.remaining = 3.0
	second.remaining = 5.0
	var mass: float = first.well_scale * first.well_scale + second.well_scale * second.well_scale
	var centre: Vector2 = (first.well_position + second.well_position) * 0.5
	game.gravity_fields.step(0.0)
	game.visual_time = 2.0
	await capture("droplets-approach")
	var maximum_area_error := 0.0
	var passed_contact := false
	for frame in range(180):
		game.gravity_fields.step(1.0 / 60.0)
		game.visual_time += 1.0 / 60.0
		if game.gravity_fields.active_wells().size() == 2:
			var ra: float = game.gravity_fields.core_radius(first)
			var rb: float = game.gravity_fields.core_radius(second)
			var distance: float = first.well_position.distance_to(second.well_position)
			var area: float = game.gravity_fields.disc_union_area(ra, rb, distance)
			maximum_area_error = maxf(maximum_area_error, absf(area / (PI * 31.0 * 31.0 * mass) - 1.0))
			passed_contact = passed_contact or distance < 31.0 * (first.well_scale + second.well_scale)
		if frame == 22:
			await capture("droplets-neck")
		if frame == 55:
			await capture("droplets-relax")
		if game.gravity_fields.active_wells().size() == 1:
			break
	var survivors: Array[Node2D] = game.gravity_fields.active_wells()
	check(passed_contact, "black holes form a continuous neck after contact before losing their separate identities")
	check(maximum_area_error < 0.004, "coalescence conserves visible area throughout the droplet deformation")
	check(survivors.size() == 1 and absf(survivors[0].well_scale * survivors[0].well_scale - mass) < 0.001, "final radius preserves both original hole areas")
	check(survivors.size() == 1 and is_equal_approx(survivors[0].remaining, 8.0), "final field preserves the exact sum of remaining lifetimes")
	check(survivors.size() == 1 and survivors[0].well_position.distance_to(centre) < 0.1, "equal droplets keep their centre of mass while combining")
	check(game.gravity_fields.exits.is_empty(), "consumed droplet causes no fake expiry explosion or player recoil")
	await capture("droplets-combined")
	game.gravity_fields.update_visuals()
	check(game.gravity_fields.coalescence_pool.size() <= 1 and game.gravity_fields.coalescence_pool.all(func(v: Node2D) -> bool: return not v.visible), "finite neck quad is reused and hidden after merging")
	game.free()
	await process_frame
	print("DODGE / COALESCENCE: %d passed; %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
