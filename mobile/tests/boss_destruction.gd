extends SceneTree
## Verify the supplied RGB sheets actually render as isolated animated sprites,
## preserve death-field timing, and never cancel an already launched attack.
var game: Node2D
var failures := 0
var checks := 0
var directory := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func capture(label: String) -> void:
	if directory.is_empty(): return
	game.interface.refresh()
	game.refresh_space()
	game.gravity_fields.update_visuals()
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("boss-destruction-record.cfg"):
		quit(1)
		return
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	for kind in ["black", "white", "asteroid"]:
		game.start_run()
		game.begin_boss(kind)
		game.boss.body_position = Vector2(270, 335)
		game.boss.phase = "firefight"
		game.boss.refresh_artwork()
		game.gravity_fields.add_boss_collapse(game.boss)
		game.boss.visible = false
		var effect: Node2D = game.gravity_fields.collapses.back()
		check(effect.sheet.texture.get_size() == Vector2(2172,724), kind + " uses the original eight-frame strip")
		effect.step(0.3)
		check(not effect.opened and game.lingering_wells.is_empty() and effect.frame_position > 1.0, kind + " authored destruction advances before opening a field")
		var previous: float = effect.frame_position
		effect.step(0.0)
		check(is_equal_approx(effect.frame_position, previous), kind + " animation freezes with the simulation clock")
		await capture(kind + "-01-destruction")
		effect.step(0.3)
		await capture(kind + "-02-collapse-burst")
		effect.step(0.05)
		check(effect.opened and not effect.hull.visible and effect.sheet.visible, kind + " source hull clears while the authored tail continues")
		if kind == "asteroid":
			check(game.lingering_wells.is_empty(), "asteroid destruction never creates a gravity field")
		else:
			check(game.lingering_wells.size() == 1 and game.lingering_wells[0].well_duration == 8.0, kind + " still opens exactly one eight-second death field at 0.65 seconds")
		effect.step(0.20)
		await capture(kind + "-03-field-and-debris")
		effect.step(0.35)
		check(effect.frame_position == 7.0 and effect.finish.get_shader_parameter("opacity") > 0.0, kind + " final sprite blends out instead of popping away")
		await capture(kind + "-04-tail")
		effect.step(0.3)
		check(game.gravity_fields.collapses.is_empty() and effect.is_queued_for_deletion(), kind + " presentation cleans up after its finite lifetime")
		await process_frame
	# Exercise the real victory path, including active attack detachment.
	game.start_run()
	game.begin_boss("asteroid")
	game.boss.phase = "active"
	game.boss.phase_time = 1.0
	game.defeat_boss(game.boss)
	check(game.gravity_fields.collapses.size() == 1 and game.lingering_wells.size() == 1 and game.lingering_wells[0].kind == "asteroid", "actual asteroid victory keeps its throw attack and creates the supplied destruction visual")
	game.gravity_fields.collapses[0].step(0.7)
	check(game.lingering_wells.size() == 1, "asteroid death animation adds no extra attack to its surviving throw")
	game.free()
	await process_frame
	print("BOSS DESTRUCTION: %d passed; %d failed" % [checks-failures, failures])
	quit(1 if failures else 0)
