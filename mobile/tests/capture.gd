extends SceneTree
## Developer-only rendering check. Captures actual Godot frames, then exits.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var destination := OS.get_environment("ALIEN_CAPTURE_DIR")
	if destination.is_empty():
		push_error("Set ALIEN_CAPTURE_DIR to a writable output directory.")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join("title.png"))
	game.start_run()
	game.ship.target_x = 340
	for i in range(100):
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
	game.interface.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join("mission.png"))
	game.pause_run()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join("pause.png"))
	game.resume_run()
	for enemy in game.enemies.duplicate():
		game.destroy_enemy(enemy)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join("continued-flight.png"))
	for mode in ["black", "white", "asteroid", "swarm"]:
		game.start_run(mode)
		game.rng.seed = 14
		game.boss.step(1.5)
		if mode == "black":
			for i in range(120):
				game._physics_process(1.0 / 60.0)
				game._process(1.0 / 60.0)
			game.interface.refresh()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destination.path_join("firefight.png"))
		game.boss.begin_special()
		if mode in ["black", "white"]:
			# Capture the moving lens as well as the hole it creates.
			game.boss.step(0.12)
			game.refresh_space()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(destination.path_join(mode + "-cannon.png"))
			for i in range(95):
				game.boss.step(1.0 / 60.0)
			game.boss.resist()
			game.boss.resist()
		else:
			for i in range(270):
				game.elapsed += 1.0 / 60.0
				game.boss.step(1.0 / 60.0)
				game.update_asteroids(1.0 / 60.0)
				game.update_enemies(1.0 / 60.0)
		game.interface.refresh()
		game.refresh_space()
		game.queue_redraw()
		game.boss.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination.path_join(mode + ".png"))
		# Same lighting and actors, but no displacement: isolates real refraction.
		game.space_folds.material.set_shader_parameter("refraction_strength", 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination.path_join(mode + "-no-refraction.png"))
		game.space_folds.material.set_shader_parameter("refraction_strength", 1.0)
	for level in [3, 4]:
		game.start_run()
		game.weapons.level = level
		game.spawn_enemy(Vector2(220, 240), Vector2.DOWN * 100)
		game.spawn_pickup(Vector2(160, 540), "weapon")
		game.spawn_pickup(Vector2(330, 590), "life")
		game.fire_player_shot()
		game.update_projectiles(0.05 if level == 3 else 0.35)
		game.interface.refresh()
		game.refresh_space()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination.path_join("weapon-%d.png" % level))
	print("Screens captured to " + destination)
	quit(0)
