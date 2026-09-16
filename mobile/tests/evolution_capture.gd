extends SceneTree
## Capture actual GPU frames for remnants, sector light, recoil thrust and death.
var game: Node2D
var directory: String

## Start after the viewport has been constructed.
func _initialize() -> void:
	call_deferred("run")

## Redraw all layers before saving a representative frame.
func shot(label: String) -> void:
	game.interface.refresh()
	game.refresh_space()
	game.queue_redraw()
	game.combat.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

## Stage finite effects directly so visual checks don't depend on random gameplay.
func run() -> void:
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty():
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	for kind in ["asteroid", "swarm"]:
		game.start_run(kind)
		game.boss.step(1.5)
		game.boss.begin_special()
		game.boss.step(1.3)
		game.boss.step(0.1)
		game.boss.take_hit(10000)
		await shot(kind + "-remnant")
	game.start_run()
	game.combat.press(0, Vector2(250, 380))
	game.combat.step(2)
	game.combat.release(0, Vector2(250, 380))
	var well: Node2D = game.lingering_wells[0]
	well.step(1)
	game.spawn_enemy(Vector2(100, 360), Vector2.ZERO)
	well.resist()
	well.step(0.1)
	await shot("resisting-thrust")
	game.instant_loss("A black hole collapsed your ship.")
	game._process(0.65)
	await shot("gravity-death")
	game.start_run()
	game.visual_time = 8.0
	for side in [1.7, 0.3, -0.5]:
		game.sector_light = Vector3(0.5, -0.4, side).normalized()
		await shot("lighting-" + str(side))
	game.free()
	await process_frame
	quit(0)
