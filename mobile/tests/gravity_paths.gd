extends SceneTree
## Matter capture, curved white exclusion and single-ray optics use real paths.
var game: Node2D
var failed := 0
var passed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:
		passed+=1
		print("PASS: "+label)
	else:
		failed+=1
		push_error("FAIL: "+label)
func fresh() -> void:
	game.start_run()
	game.wave_timer=10000
	game.asteroid_timer=10000
	game.boss_timer=10000
func field(kind: String,at: Vector2,scale: float=1.0) -> Node2D:
	var well = game.Boss.new()
	well.game=game
	well.kind=kind
	well.lingering=true
	well.phase="active"
	well.well_scale=scale
	well.well_position=at
	game.add_child(well)
	game.lingering_wells.append(well)
	return well
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("gravity-paths-record.cfg"):
		quit(1)
		return
	root.size=Vector2i(540,960)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled=false
	game.progress.vibration_enabled=false
	for kind in ["bullet","plasma","rocket","doom"]:
		fresh()
		var well:=field("black",Vector2(270,410))
		var shot: Node2D=game.weapons.spawn_shot(game,Vector2(270,630),Vector2.DOWN*(660.0 if kind=="rocket" else 850.0))
		shot.kind=kind
		var speed: float=shot.velocity.length()
		var previous_distance: float=shot.position.distance_to(well.well_position)
		var inward:=true
		var constant_speed:=true
		for frame in range(600):
			game.update_projectiles(1.0/60.0)
			if not game.projectiles.has(shot): break
			var distance: float=shot.position.distance_to(well.well_position)
			inward=inward and distance<=previous_distance+0.01
			constant_speed=constant_speed and is_equal_approx(shot.velocity.length(),speed)
			previous_distance=distance
		check(inward and constant_speed and not game.projectiles.has(shot),kind+" cannot escape capture and spirals into the horizon at its fixed speed")
	fresh()
	var well:=field("black",Vector2(270,420))
	var target: Node2D=game.spawn_enemy(Vector2(270,170),Vector2.ZERO)
	var rocket: Node2D=game.weapons.spawn_shot(game,Vector2(400,560),Vector2.UP*660.0)
	rocket.kind="rocket"
	rocket.homing_target=target
	game.update_projectiles(1.0/60.0)
	check(rocket.gravity_capture_id==well.get_instance_id() and rocket.homing_target==null,"capture cancels homing so targeted cannons cannot pull themselves free")
	well.phase="finished"
	game.update_projectiles(1.0/60.0)
	check(rocket.gravity_capture_id==0,"capture safely releases when its field ends")
	fresh()
	well=field("white",Vector2(270,420))
	var shot: Node2D=game.weapons.spawn_shot(game,Vector2(270,680),Vector2.UP*850)
	var safe:=true
	var curved:=false
	var smooth:=true
	var previous_velocity: Vector2=shot.velocity
	for frame in range(65):
		game.update_projectiles(1.0/120.0)
		if not game.projectiles.has(shot): break
		for i in range(0,shot.motion_segments.size()-1,2):
			var closest:=Geometry2D.get_closest_point_to_segment(well.well_position,shot.motion_segments[i],shot.motion_segments[i+1])
			safe=safe and closest.distance_to(well.well_position)>game.EnergyOptics.core_radius(well)+9.0
		curved=curved or absf(shot.position.x-270)>20.0
		smooth=smooth and absf(previous_velocity.angle_to(shot.velocity))<0.2
		previous_velocity=shot.velocity
	check(safe and curved,"white hole bends the shot along an exterior arc without touching the white center")
	check(smooth,"normal white-hole deflection has no single-frame billiard bounce")
	fresh()
	well=field("white",Vector2(270,420))
	shot=game.weapons.spawn_shot(game,Vector2(270,470),Vector2.UP*850)
	game.update_projectiles(0.15)
	safe=game.projectiles.has(shot)
	for i in range(0,shot.motion_segments.size()-1,2):
		safe=safe and Geometry2D.get_closest_point_to_segment(well.well_position,shot.motion_segments[i],shot.motion_segments[i+1]).distance_to(well.well_position)>game.EnergyOptics.core_radius(well)+9.0
	check(safe and absf(shot.position.x-270)>10,"long-frame white deflection retains a safe curved collision sweep")
	fresh()
	well=field("black",Vector2(270,420))
	var beam: Array[Vector2]=game.reflected_laser(Vector2(270,650))
	var continuous:=true
	for i in range(2,beam.size()-1,2): continuous=continuous and beam[i].is_equal_approx(beam[i-1])
	check(continuous and is_equal_approx(beam.back().distance_to(well.well_position),31.0) and beam.back().y>420,"head-on laser is one continuous ray absorbed at the near horizon")
	var links: Array[Vector2]=game.route_energy_link(Vector2(270,650),Vector2(270,180))
	check(links.back().y>420,"electron stream cannot route through or bypass a black horizon")
	fresh()
	well=field("black",Vector2(400,420))
	beam=game.reflected_laser(Vector2(270,750))
	var bend:=0.0
	for point in beam: bend=maxf(bend,point.x-270)
	check(bend>35.0 and beam.size()<=768,"glancing laser is strongly bent within a fixed trace budget")
	fresh()
	well=field("white",Vector2(270,420))
	beam=game.reflected_laser(Vector2(270,700))
	safe=true
	curved=false
	for i in range(0,beam.size()-1,2):
		var closest:=Geometry2D.get_closest_point_to_segment(well.well_position,beam[i],beam[i+1])
		safe=safe and closest.distance_to(well.well_position)>game.EnergyOptics.core_radius(well)+10.0
		curved=curved or absf(beam[i].x-270)>25
	check(safe and curved,"laser also curves clear of the white center")
	fresh()
	beam=game.reflected_laser(Vector2(270,750))
	check(beam.back().y<0.0,"laser reaches beyond the actual screen edge without a former top-bar cutoff")
	print("GRAVITY_PATHS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
