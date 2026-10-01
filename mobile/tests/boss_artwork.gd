extends SceneTree
## Render the final reference hulls at their real phone size. Also verify the
## hull, shielding and dodge geometry agree, and damage has a visible response.
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
	game.boss.refresh_artwork()
	game.refresh_space()
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("boss-artwork-record.cfg"):
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
	game.start_run()
	var valid_decks := true
	for cycle in range(4):
		var kinds: Array[String] = []
		for i in range(3): kinds.append(game.next_boss_kind())
		kinds.sort()
		valid_decks = valid_decks and kinds == ["asteroid", "black", "white"]
	check(valid_decks, "every shuffled deck contains the three final bosses and no carrier")
	for kind in ["black", "white", "asteroid"]:
		game.start_run()
		game.begin_boss(kind)
		var boss: Node2D = game.boss
		boss.phase = "firefight"
		boss.body_position = Vector2(270, 330)
		boss.animation_time = 2.5
		boss.refresh_artwork()
		var image: Image = boss.artwork.surface.texture.get_image()
		check(image.get_pixel(0,0).a < 0.01 and image.get_pixel(image.get_width()-1,0).a < 0.01, kind + " hull keeps a transparent background")
		check(boss.visual_hull_radius()*2.0 > game.ship.Artwork.size_for(0).x*3.0, kind + " is visibly more than three player hulls across")
		check(boss.shield_radius() > boss.visual_hull_radius() and boss.guard_orbit_radii().y > boss.shield_radius(), kind + " shield and guards clear the enlarged hull")
		await capture(kind + "-intact")
		boss.health = boss.max_health * 0.3
		boss.refresh_artwork(0.1)
		check(boss.artwork.damage_visual.cloud.visible and boss.artwork.finish.get_shader_parameter("hull_damage") > 1.5, kind + " low health produces scarred armor and smoke")
		await capture(kind + "-damaged")
		boss.health = boss.max_health
		boss.refresh_artwork()
		var guard: Node2D = game.spawn_enemy(Vector2(270,160), Vector2.ZERO)
		guard.shield_guard = true
		boss.guard_total = 1
		game.shield_visual.step(0.0)
		await capture(kind + "-shielded")
		check(game.shield_visual.boss_surface.visible, kind + " keeps its guard shield")
	game.free()
	await process_frame
	print("BOSS ARTWORK: %d passed; %d failed" % [checks-failures, failures])
	quit(1 if failures else 0)
