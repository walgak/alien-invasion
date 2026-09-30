extends SceneTree
## Real-GPU checks for distant-star refraction and the deliberately separate
## collected shield versus finger-held resistance warp. Saves use a disposable
## path, and fixed clocks make pixel comparisons independent of normal travel.
var game: Node2D
var directory: String
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func capture(label: String, hide_mesh: bool = false) -> Image:
	game.state = game.State.PLAYING
	game.shield_visual.step(0.0)
	game.interface.refresh()
	game.refresh_space()
	if hide_mesh:
		game.shield_visual.player_surface.visible = false
	game.queue_redraw()
	game.gravity_fields.queue_redraw()
	for frame in range(3):
		# A desktop focus notification can arrive just after opening the test
		# window. Keep only this frozen capture harness in the intended state.
		game.state = game.State.PLAYING
		game.interface.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(directory.path_join(label + ".png"))
	return image

func player_warp_present() -> bool:
	game.refresh_space()
	var styles: PackedVector4Array = game.space_folds.material.get_shader_parameter("lens_styles")
	var lenses: PackedVector4Array = game.space_folds.material.get_shader_parameter("lenses")
	for index in range(game.space_folds.lens_count):
		if styles[index].z == 3.0 and Vector2(lenses[index].x, lenses[index].y).distance_to(game.ship.position) < 0.1:
			return true
	return false

func run() -> void:
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty() or not OS.get_environment("ALIEN_SAVE_PATH").ends_with("refraction-record.cfg"):
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
	game.combat.shield_time = 0.01
	game.shield_visual.step(0.0)
	check(game.shield_visual.player_surface.visible and player_warp_present(), "last fraction of real shield time retains dome and refraction")
	var styles: PackedVector4Array = game.space_folds.material.get_shader_parameter("lens_styles")
	check(is_equal_approx(styles[0].x, game.combat.shield_radius()/1.2), "legacy warp radius is restored without reducing protective hull coverage")
	game.combat.shield_time = 0.0
	game.shield_visual.step(0.0)
	check(not game.shield_visual.player_surface.visible and not player_warp_present(), "expired immunity immediately removes collected shield")
	game.combat.shield_time = 10.0
	await capture("01-collected-shield")
	# Isolate the stars: no celestial art, solar cloud, or visible mesh can create
	# the measured difference. Only the full-sky lens can relocate these pixels.
	game.space_background.celestial_surface.visible = false
	game.space_background.wind_strength = 0.0
	game.progress.distortion_strength = 0.0
	var flat := await capture("02-stars-flat", true)
	game.progress.distortion_strength = 1.0
	var bent := await capture("03-stars-refracted", true)
	var relocated := 0
	var largest_change := 0.0
	var at: Vector2 = game.ship.position
	for y in range(maxi(0,int(at.y)-145), mini(flat.get_height(),int(at.y)+145)):
		for x in range(maxi(0,int(at.x)-145), mini(flat.get_width(),int(at.x)+145)):
			var d := Vector2(x,y).distance_to(at)
			if d < 55.0 or d > 140.0:
				continue
			var before := flat.get_pixel(x,y)
			var after := bent.get_pixel(x,y)
			var difference := maxf(absf(before.r-after.r),maxf(absf(before.g-after.g),absf(before.b-after.b)))
			largest_change = maxf(largest_change,difference)
			if difference > 0.015:
				relocated += 1
	check(relocated > 30 and largest_change > 0.10, "shield actually refracts distant stars (%d changed pixels)" % relocated)
	game.space_background.celestial_surface.visible = true
	game.combat.shield_time = 0.0
	var well: Node2D = game.PlayerWell.new()
	well.game = game
	well.phase = "active"
	well.remaining = 8.0
	well.well_scale = 1.4
	well.well_position = Vector2(240,450)
	well.animation_time = 3.0
	game.add_child(well)
	game.lingering_wells.append(well)
	game.shield_visual.step(0.0)
	check(not game.shield_visual.player_surface.visible and not player_warp_present(), "automatic gravity hazard protection never impersonates a collected shield")
	game.combat.press(91,game.ship.position)
	game.shield_visual.step(0.0)
	check(game.combat.gravity_touch_active() and player_warp_present() and not game.shield_visual.player_surface.visible, "gravity press shows only a held-finger warp")
	await capture("04-resistance-held")
	game.combat.release(91,game.ship.position)
	game.shield_visual.step(0.0)
	check(not game.combat.gravity_touch_active() and not player_warp_present() and not game.shield_visual.player_surface.visible, "resistance warp disappears on release without a lingering tap ring")
	await capture("05-resistance-released")
	var before_motion := await capture("06-hole-ripples-first")
	game.visual_time += 0.45
	well.animation_time += 0.45
	game.gravity_fields.advance_ripples(0.45)
	var after_motion := await capture("07-hole-ripples-moving")
	check(before_motion.get_data() != after_motion.get_data(), "gravity ripples continue to move with the field")
	game.free()
	await process_frame
	print("RESTORED REFRACTION: %d failures" % failures)
	quit(0 if failures == 0 else 1)
