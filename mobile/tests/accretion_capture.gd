extends SceneTree
## Render real GPU frames for reference matching, colour, occlusion and lensing.
## Uses a disposable save; does not change player progress or the main scene.
var game: Node2D
var directory: String
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)

func capture(label: String) -> Image:
	# Multiple GPU capture tools may change macOS focus. These are deterministic
	# presentation snapshots, so clear focus-loss pause before sampling a frame.
	if game.state == game.State.PAUSED:
		game.state = game.State.PLAYING
	game.interface.refresh()
	game.refresh_space()
	game.gravity_fields.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(directory.path_join(label + ".png"))
	return frame

func run() -> void:
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty() or not OS.get_environment("ALIEN_SAVE_PATH").ends_with("accretion-capture-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	for kind in ["player", "red", "violet", "white"]:
		game.start_run("white" if kind == "white" else "black")
		game.visual_time = 2.0
		game.boss.step(1.5)
		game.boss.phase = "active"
		game.boss.well_position = Vector2(270, 640)
		game.boss.well_scale = 1.8
		game.boss.hole_color = Color("ff4d35") if kind == "red" else Color("a45cff")
		if kind == "player":
			game.boss.phase = "firefight"
			var well = game.PlayerWell.new()
			well.game = game
			well.well_position = Vector2(270, 640)
			well.cannon_position = well.well_position
			game.add_child(well)
			game.lingering_wells.append(well)
			well.step(0.0)
		game.boss.queue_redraw()
		var frame := await capture(kind + "-vortex")
		var core := frame.get_pixel(270, 640)
		check(core.r > 0.9 if kind == "white" else maxf(core.r, maxf(core.g, core.b)) < 0.02, kind + " has the correct opaque core")
		game.visual_time += 1.0
		var moved := await capture(kind + "-motion")
		check(frame.get_data() != moved.get_data(), kind + " texture animates with simulation time")
		# Match the very same camera, actors and plasma while disabling refraction.
		game.progress.distortion_strength = 0.0
		var flat := await capture(kind + "-no-distortion")
		check(flat.get_data() != moved.get_data(), kind + " retains actual background displacement")
		game.progress.distortion_strength = 1.0
		# Flood transient tap rings; an actual well must retain one priority slot.
		for i in range(12):
			game.combat.warp_pulses.append({"at": Vector2(70+i*25, 750), "age": 0.1})
		game.refresh_space()
		var lenses: PackedVector4Array = game.space_folds.material.get_shader_parameter("lenses")
		var contains_well := false
		for lens in lenses:
			contains_well = contains_well or (lens.x == 270.0 and lens.y == 640.0 and lens.z > 200.0)
		check(contains_well and game.space_folds.lens_count == 8, kind + " distortion survives a burst of tap rings and hazard protection")
	game.start_run()
	game.refresh_space()
	check(game.gravity_fields.accretion_pool.all(func(v: Node2D) -> bool: return not v.visible), "new run hides reused accretion sprites")
	game.visual_time = 75.0
	await capture("vibrant-nebula")
	game.start_run()
	for at in [Vector2(140,410),Vector2(405,575),Vector2(165,755)]:
		var well = game.PlayerWell.new()
		well.game = game
		well.charge = 5.0
		well.well_position = at
		well.cannon_position = at
		game.add_child(well)
		game.lingering_wells.append(well)
		well.step(0.0)
	await capture("three-maximum-fields")
	var pool_size: int = game.gravity_fields.accretion_pool.size()
	for frame in range(20):
		game.visual_time += 1.0 / 60.0
		game.refresh_space()
		await process_frame
	check(game.gravity_fields.accretion_pool.size() == pool_size and pool_size <= 12, "maximum fields reuse a bounded visual pool")
	game.pause_run()
	var frozen_time: float = game.visual_time
	game._process(0.5)
	check(game.visual_time == frozen_time and game.gravity_fields.accretion_pool[0].material.get_shader_parameter("visual_time") == frozen_time, "pause freezes shader animation")
	game.free()
	await process_frame
	print("ACCRETION CAPTURE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
