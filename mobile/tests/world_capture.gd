extends SceneTree
## Small real-GPU presentation check. The disposable save keeps these staged
## shield, tide and particle scenes separate from a player's run/progress.
var game: Node2D
var directory: String
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:
		failures += 1

func capture(label: String) -> Image:
	game.state = game.State.PLAYING
	game.shield_visual.step(0.0)
	game.interface.refresh()
	game.refresh_space()
	game.queue_redraw()
	game.gravity_fields.queue_redraw()
	# The celestial SubViewport renders first, then the main canvas samples it.
	# Two completed frames avoid comparing a fresh lens to stale background data.
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(directory.path_join(label+".png"))
	return frame

func add_well(kind: String, at: Vector2, size: float = 1.8) -> Node2D:
	var well: Node2D = game.PlayerWell.new() if kind == "black" else game.Boss.new()
	well.game = game
	well.kind = kind
	well.phase = "active"
	well.well_position = at
	well.well_scale = size
	well.animation_time = 4.2
	well.hole_color = Color("358cff") if kind == "black" else Color("b9f8ff")
	if kind == "black":
		well.remaining = 7.5
	else:
		well.lingering = true
		well.phase_time = 8.0
	game.add_child(well)
	game.lingering_wells.append(well)
	return well

func run() -> void:
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty() or not OS.get_environment("ALIEN_SAVE_PATH").ends_with("world-capture-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	game.start_run()
	game.visual_time = 22.0
	game.ship.weapon_level = 2
	game.weapons.level = 2
	game.ship.queue_redraw()
	game.combat.laser_stock = 3
	game.combat.electron_stock = 2
	game.combat.gravity_charge = 1.0
	var baseline := await capture("01-flight")
	game.combat.shield_time = 10.0
	var shield := await capture("02-blue-hex-shield")
	check(baseline.get_data() != shield.get_data(),"full shield renders visibly")
	check(game.shield_visual.player_surface.visible,"reusable shield surface visible")
	game.shield_visual.hit_ripple(game.ship.position+Vector2(45,-18))
	game.shield_visual.step(0.12)
	await capture("03-impact-ripple")
	game.combat.shield_time = 0.0
	add_well("black",Vector2(225,500))
	game.combat.warp_pulses.append({"at":game.ship.position,"age":0.10})
	var black := await capture("04-black-hole-tap")
	check(black.get_pixel(225,500).r < 0.02 and black.get_pixel(225,500).b < 0.02,"black event horizon remains opaque over background and stars")
	check(game.shield_visual.player_surface.visible,"tap and gravity ward share the shield language")
	game.start_run()
	game.visual_time = 22.0
	add_well("white",Vector2(275,570))
	var white := await capture("05-white-hole-edge")
	check(white.get_pixel(275,570).r > 0.9,"white core remains radiant and opaque")
	check(game.space_folds.white_edge_strength == 1.0,"white field uses display edge refraction")
	game.start_run()
	game.visual_time = 12.0
	add_well("black",Vector2(350,375),2.6)
	game.combat.shield_time = 10.0
	await capture("06-celestial-tides")
	check(game.space_background.sky_material.get_shader_parameter("field_count") == 1,"celestial tides receive active gravity")
	game.clear_actors()
	game.refresh_space()
	check(game.space_background.sky_material.get_shader_parameter("field_count") == 0,"celestial tides stop when gravity disappears")
	# Fixed reusable surfaces/texture; repeated frames must not allocate wells,
	# celestial viewports or domes as time advances.
	var children: int = game.space_background.get_child_count()
	for frame in range(30):
		game.visual_time += 1.0/60.0
		game.refresh_space()
		game.shield_visual.step(1.0/60.0)
		await process_frame
	check(game.space_background.get_child_count() == children and game.shield_visual.get_child_count() == 2,"background and shield keep bounded reusable nodes")
	game.free()
	await process_frame
	print("WORLD CAPTURE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
