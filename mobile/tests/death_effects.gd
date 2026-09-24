extends SceneTree
## Cause-specific timing, opaque horizons, bounded discharge pools and completed
## offscreen warp travel. Optional GPU captures use ALIEN_CAPTURE_DIR.
var game: Node2D
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture(label: String) -> void:
	if directory.is_empty():
		return
	game.refresh_space()
	game.gravity_fields.queue_redraw()
	game.interface.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("death-effects-record.cfg"):
		quit(1)
		return
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	for kind in ["shot","impact","white","black"]:
		game.start_run()
		game.ship.position = Vector2(270,570)
		game.death_origin = game.ship.position
		game.death_target = Vector2(270,490)
		game.death_radius = 31.0
		game.death_is_gravity = kind == "black"
		game.death_synthetic = kind == "black"
		game.death_time = game.death_visual.DURATION
		game.state = game.State.LOST
		game.death_visual.begin(kind)
		check(game.death_visual.pieces.size() == 240,kind+" has a fixed hull mesh")
		check(game.death_visual.z_index < game.gravity_fields.z_index,kind+" debris and fire remain behind the opaque horizon")
		check(game.death_visual.fire.mouse_filter == Control.MOUSE_FILTER_IGNORE,"fire cannot intercept touches")
		game.death_visual.step(0.0)
		check(game.death_visual.exploded == (kind == "shot"),kind+" initial ignition timing")
		game.death_time = game.death_visual.DURATION-0.27
		game.death_visual.step(0.27)
		var strained: Vector2 = game.death_visual.strained_vertex(Vector2(20,-25),0.27)
		check(strained.is_finite() and strained.distance_to(Vector2(20,-25)) > 2.0,kind+" hull bends before tearing")
		await capture(kind+"-strain")
		game.death_time = game.death_visual.DURATION-0.68
		game.death_visual.step(0.41)
		check(game.death_visual.exploded and game.death_visual.fire.visible,kind+" ignites after hull deformation")
		await capture(kind+"-fire")
		game.death_time = game.death_visual.DURATION-1.25
		game.death_visual.step(0.57)
		await capture(kind+"-pressure")
		game.death_time = 0.03
		game.death_visual.step(1.89)
		var warp: Dictionary = game.death_visual.warp_state()
		var corner_distance: float = game.death_visual.explosion_at.distance_to(Vector2.ZERO)
		check(warp.radius > corner_distance,kind+" final wave travels beyond the viewport")
		check(not game.death_visual.fire.visible,kind+" fire expires before the menu")
		await capture(kind+"-wave")
		game.death_time = 0.0
		game.death_visual.step(0.03)
		check(game.death_visual.warp_state().is_empty(),kind+" has no lingering death distortion")
	game.start_run()
	for index in range(30):
		game.impact_visual.play_collision(Vector2(250,600),Vector2(275,573))
	check(game.impact_visual.get_child_count() == 4,"collision swarms reuse four discharge surfaces")
	check(game.impact_visual.surfaces.all(func(surface: ColorRect) -> bool: return surface.mouse_filter == Control.MOUSE_FILTER_IGNORE),"discharges cannot intercept touch")
	game.impact_visual.step(0.05)
	await capture("collision-discharge")
	game.impact_visual.step(0.4)
	check(game.impact_visual.surfaces.all(func(surface: ColorRect) -> bool: return not surface.visible),"collision discharge expires without new nodes")
	print("DEATH EFFECTS: %d checks, %d failures" % [checks,failures])
	game.free()
	await process_frame
	quit(0 if failures == 0 else 1)
