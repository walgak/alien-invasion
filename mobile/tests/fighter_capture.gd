extends SceneTree
## Render real GPU frames for the fighter, its engine sockets and textured debris.
var game: Node2D
var directory: String

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	game.ship.queue_redraw()
	game.interface.refresh()
	game.refresh_space()
	game.gravity_fields.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))

func run() -> void:
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty() or not OS.get_environment("ALIEN_SAVE_PATH").ends_with("fighter-capture-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	await shot("fighter-title")
	for tier in range(5):
		game.start_run()
		game.weapons.level = tier
		game.ship.weapon_level = tier
		game.ship.position = Vector2(270,690)
		game.combat.press(0,game.ship.position)
		game.fire_player_shot()
		game.update_projectiles(0.025)
		await shot("fighter-tier-%d" % tier)
	for kind in ["black","white"]:
		for distance in [130.0,340.0]:
			game.start_run(kind)
			game.boss.phase = "active"
			game.boss.well_position = Vector2(270,650-distance)
			game.boss.body_position = Vector2(270,190)
			game.ship.position = Vector2(270,650)
			game.combat.update_attitudes(1.0)
			await shot("burn-%s-%d" % [kind,int(distance)])
	game.start_run()
	var well = game.PlayerWell.new()
	well.game = game
	well.phase = "active"
	well.well_position = Vector2(270,390)
	well.well_scale = 1.8
	game.add_child(well)
	game.lingering_wells.append(well)
	for at in [Vector2(160,520),Vector2(380,520)]:
		game.spawn_enemy(at,Vector2.ZERO)
	game.ship.position = Vector2(270,650)
	game.combat.update_attitudes(1.0)
	await shot("burn-alien-and-player")
	game.ship.position = Vector2(300,525)
	game.instant_loss("Caught in a black hole.")
	await shot("fighter-death-start")
	game._process(0.19)
	await shot("fighter-crumble")
	game._process(0.45)
	await shot("fighter-horizon")
	game.free()
	await process_frame
	quit()
