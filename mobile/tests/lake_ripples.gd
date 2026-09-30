extends SceneTree
## Verify the visual's distance clock against actual uncancelled ship movement.
## Optional real-GPU captures also check that remote screen corners are warped.
var game: Node2D
var failed := 0
var passed := 0
var directory := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func fresh(kind: String) -> Node2D:
	game.start_run()
	game.ship.position = Vector2(270, 730)
	var well = game.Boss.new()
	well.game = game
	well.kind = kind
	well.lingering = true
	well.phase = "active"
	well.well_duration = 30.0
	well.well_position = Vector2(270, 490)
	game.add_child(well)
	game.lingering_wells.append(well)
	return well

func capture(name: String) -> Image:
	game.refresh_space()
	game.queue_redraw()
	game.gravity_fields.queue_redraw()
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	screenshot.save_png(directory.path_join(name + ".png"))
	return screenshot

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("lake-ripples-record.cfg"):
		quit(1)
		return
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	for kind in ["black", "white"]:
		var well := fresh(kind)
		var initial: Vector2 = game.ship.position
		var speed: float = game.gravity_fields.net_force_for(game.ship).length()
		game.gravity_fields.advance_ripples(0.05)
		game.gravity_fields.apply_player_force(0.05)
		var distance: float = game.gravity_fields.ripple_distance(well)
		check(is_equal_approx(distance, 3.0*initial.distance_to(game.ship.position)), kind+" ripple travels exactly three times the ship displacement")
		game.ship.position = initial
		well.phase_time = 20.0
		var later_speed: float = game.gravity_fields.net_force_for(game.ship).length()
		var before: float = game.gravity_fields.ripple_distance(well)
		game.gravity_fields.advance_ripples(0.02)
		check(is_equal_approx(game.gravity_fields.ripple_distance(well)-before,later_speed*3.0*0.02), kind+" ripple uses the accelerated/decelerated physical speed")
		check(later_speed>speed if kind=="black" else later_speed<speed, kind+" time-dependent acceleration retains its original direction")
		well.neutralise_time = 1.0
		before = game.gravity_fields.ripple_distance(well)
		game.gravity_fields.advance_ripples(0.02)
		game.gravity_fields.apply_player_force(0.02)
		check(game.ship.position.is_equal_approx(initial) and game.gravity_fields.ripple_distance(well)>before,kind+" waves remain active while a tap completely neutralises movement")
		game.combat.shield_time = 10.0
		before = game.gravity_fields.ripple_distance(well)
		game.gravity_fields.advance_ripples(0.02)
		check(game.gravity_fields.net_force_for(game.ship)==Vector2.ZERO and game.gravity_fields.ripple_distance(well)>before,kind+" immunity does not freeze the visible gravity waves")
		game.combat.shield_time = 0.0
		game.refresh_space()
		var styles: PackedVector4Array = game.space_folds.material.get_shader_parameter("lens_styles")
		var lenses: PackedVector4Array = game.space_folds.material.get_shader_parameter("lenses")
		var travels: PackedFloat32Array = game.space_folds.material.get_shader_parameter("wave_distances")
		var covers := true
		for corner in [Vector2.ZERO,Vector2(540,0),Vector2(540,960),Vector2(0,960)]:
			covers = covers and (corner-well.well_position).length()/0.83<lenses[0].z
		check(covers and travels[0]>=0.0 and styles[0].y==(-1.0 if kind=="black" else 1.0),kind+" wave covers every corner with the correct travel direction")
		before = game.gravity_fields.ripple_distance(well)
		game.pause_run()
		game._physics_process(0.5)
		check(game.gravity_fields.ripple_distance(well)==before,kind+" ripple pauses with gameplay")
		if not directory.is_empty():
			game.state = game.State.PLAYING
			game.visual_time = 22.0
			well.animation_time = 4.0
			game.interface.refresh()
			var first := await capture(kind+"-first")
			# Only the ripple phase advances: art, stars, wind and all clocks stay fixed.
			game.gravity_fields.advance_ripples(0.13)
			var second := await capture(kind+"-second")
			var changed := 0
			for y in range(20,170):
				for x in range(20,520):
					var a := first.get_pixel(x,y)
					var b := second.get_pixel(x,y)
					if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.008:
						changed += 1
			check(changed>250,kind+" ripple moves the distant upper-screen background (%d pixels)" % changed)
	game.start_run()
	check(game.gravity_fields.ripple_travel.is_empty(),"restart removes old field clocks")
	print("LAKE RIPPLES: %d passed, %d failed" % [passed,failed])
	game.free()
	await process_frame
	quit(0 if failed==0 else 1)
