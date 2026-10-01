extends SceneTree
## Readable mineral silhouettes and the record transition use the real renderer.
var game: Node2D
var failures := 0
var directory := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func capture(name: String) -> void:
	if directory.is_empty(): return
	for frame in range(3):
		game.state = game.State.PLAYING
		game.interface.refresh()
		game.refresh_space()
		await process_frame
		await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(directory.path_join(name+".png"))
	var green_pixels := 0
	for y in range(120,650):
		for x in range(picture.get_width()):
			var color := picture.get_pixel(x,y)
			if color.g-maxf(color.r,color.b)>0.55: green_pixels += 1
	check(green_pixels==0,"production green screen is absent from gameplay: "+name)
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("asteroid-hud-record.cfg"):
		quit(1)
		return
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.progress.best_by_mode["endless"] = 1000
	game.progress.sound_enabled = false
	game.progress.vibration_enabled = false
	game.sound.enabled = false
	game.start_run()
	game.visual_time = 16.0
	game.add_score(600)
	game.lives = 2
	game.ship.set_hull_health(2)
	check(game.interface.hud_score_lines()==PackedStringArray(["000600","BEST  001000"]),"current score and saved record both appear before the record is beaten")
	var kinds := ["ice","ash","magma","fractured","cinder","ash"]
	var atlas_indices: Array[int] = []
	for index in range(kinds.size()):
		var rock: Node2D = game.Asteroid.new()
		rock.radius = 43.0
		rock.health = 12
		rock.visual_kind = kinds[index]
		rock.visual_seed = 1 if index < 5 else 2
		rock.position = Vector2(100+(index%3)*165,270+(index/3)*230)
		game.add_child(rock)
		game.asteroids.append(rock)
		atlas_indices.append(rock.atlas_index)
	check(atlas_indices==[0,1,2,3,4,5],"six designed silhouettes use the correct shared-atlas regions")
	await capture("01-asteroids-score-and-lives")
	game.add_score(400)
	check(game.interface.hud_score_lines().size()==2,"matching the record retains both scores until it is beaten")
	game.add_score(1)
	check(game.progress.best_for("endless")==1001 and game.interface.hud_score_lines()==PackedStringArray(["001001"]),"beating the record leaves one live score even while the saved record updates")
	await capture("02-new-record-single-score")
	game.add_score(50)
	check(game.interface.hud_score_lines()==PackedStringArray(["001051"]),"the lone record score keeps updating")
	game.start_run()
	check(game.lives==3 and game.interface.hud_score_lines()==PackedStringArray(["000000","BEST  001051"]),"the next run shows its new target record and restores three lives")
	game.free()
	await process_frame
	print("ASTEROID HUD: %d failures" % failures)
	quit(0 if failures==0 else 1)
