extends SceneTree
## Actual phone-size rendered frames for hull readability, relative scale,
## alternating gun ports, guard formation, tractor throws and resisting engines.
var game: Node2D
var directory: String

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	game.ship.queue_redraw()
	game.interface.refresh()
	game.refresh_space()
	game.combat.queue_redraw()
	game.gravity_fields.queue_redraw()
	for enemy in game.enemies:
		enemy.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))

func run() -> void:
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty() or not OS.get_environment("ALIEN_SAVE_PATH").ends_with("alien-capture-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	game.start_run()
	game.ship.position = Vector2(180,660)
	game.spawn_enemy(Vector2(360,660),Vector2.ZERO)
	await shot("player-alien-size")
	game.start_run()
	game.ship.position = Vector2(270,775)
	for at in [Vector2(120,320),Vector2(300,410),Vector2(430,305)]:
		var enemy = game.spawn_enemy(at,Vector2.ZERO)
		enemy.shot_timer = 0
	game.update_enemies(0)
	game.update_projectiles(0.04)
	await shot("alien-flight")
	game.begin_boss("black")
	game.boss.step(1.5)
	game.update_enemies(0.6)
	await shot("alien-guards")
	game.start_run("swarm")
	game.boss.step(1.5)
	game.spawn_enemy(Vector2(380,470),Vector2.ZERO,true,game.boss.body_position+Vector2(0,42))
	await shot("alien-tractor")
	game.start_run()
	var well = game.PlayerWell.new()
	well.game = game
	well.phase = "active"
	well.well_position = Vector2(270,370)
	well.well_scale = 1.8
	game.add_child(well)
	game.lingering_wells.append(well)
	for at in [Vector2(160,535),Vector2(380,535)]:
		game.spawn_enemy(at,Vector2.ZERO)
	game.ship.position = Vector2(270,720)
	game.combat.update_attitudes(1.0)
	await shot("alien-engines")
	game.free()
	await process_frame
	quit()
