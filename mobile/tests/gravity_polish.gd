extends SceneTree
## Regression checks for lifetimes, shield counterplay, absorption and presentation.
var game: Node2D
var failed := 0
var passed := 0

## Delay construction until root viewport is available.
func _initialize() -> void:
	call_deferred("run")

## Emit a human-readable invariant for each feature.
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: "+label)
	else:
		failed += 1
		push_error("FAIL: "+label)

## Reset deterministic flight without touching real saves or physical haptics.
func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000
	game.boss_timer = 1000
	game.asteroid_timer = 1000
	game.progress.vibration_enabled = false

## Use the real rocket transition, with a deliberately large five-second charge.
func well(at: Vector2) -> Node2D:
	var result = game.PlayerWell.new()
	result.game = game
	result.well_position = at
	result.cannon_position = at
	result.charge = 5
	game.add_child(result)
	game.lingering_wells.append(result)
	result.step(0)
	return result

## Test removed actors across actual deletion boundaries and new combat contracts.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("gravity-polish-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	fresh()
	game.combat.shield_time = 20
	var field := well(Vector2(270,400))
	game.combat.gravity_haptic = true
	game.combat.haptic_cooldown = 0.0
	game.combat.vibrate("enemy")
	check(game.combat.gravity_haptic,"enemy feedback never restarts the continuous gravity haptic")
	for i in range(14):
		game.spawn_enemy(Vector2(245+i*3,400),Vector2.ZERO)
	field.step(0.01)
	await process_frame
	check(game.enemies.is_empty(),"maximum field swallows and frees every nearby alien")
	check(field.origins.keys().all(func(id: Variant) -> bool: return id is int),"gravity bookkeeping never stores freed objects as keys")
	for frame in range(20):
		game.combat.queue_redraw()
		await process_frame
	field.finish_well()
	check(game.combat.returns.keys().all(func(id: Variant) -> bool: return is_instance_id_valid(id)),"return queue contains only surviving identities")
	check(game.gravity_fields.exits.size()==1,"expired player well leaves a finite exit pulse")
	field=well(Vector2(360,500))
	game.combat.shield_time=0
	game.combat.press(3,Vector2(120,400))
	check(game.combat.warp_pulses.size()==1,"gravity tap creates the same warp-ring pulse as the shield")
	fresh()
	game.begin_boss("white")
	game.boss.phase="active"
	game.boss.well_position=Vector2(150,500)
	game.combat.update_attitudes(1)
	var nose := Vector2.UP.rotated(game.ship.rotation)
	check(nose.dot((game.boss.well_position-game.ship.position).normalized())>0.99,"white-hole resistance points ship nose toward the source")
	game.boss.kind="black"
	game.combat.update_attitudes(1)
	nose=Vector2.UP.rotated(game.ship.rotation)
	check(nose.dot((game.ship.position-game.boss.well_position).normalized())>0.99,"black-hole resistance points nose away from the source")
	game.boss.return_to_firefight()
	game.combat.update_attitudes(1)
	check(absf(wrapf(game.ship.rotation,-PI,PI))<0.01,"ship turns back upright after gravity")
	fresh()
	game.begin_boss("black")
	game.boss.phase="firefight"
	game.boss.body_position=Vector2(270,350)
	game.combat.equip_laser()
	game.combat.press(0,game.ship.position)
	game.update_laser(0.1)
	check(game.laser.absorbed and absf(game.laser.contact_point.distance_to(game.boss.body_position)-game.Boss.HIT_RADIUS)<0.1,"boss absorbs the laser exactly at its surface")
	check(game.laser.beam_segments.back()==game.laser.contact_point,"beam stops at the contact glow")
	fresh()
	field=well(Vector2(360,500))
	var ray: Array[Vector2]=game.reflected_laser(Vector2(270,750))
	check(ray.back().x>271,"laser path curves toward a nearby black hole")
	var v: Vector2=game.curved_velocity(Vector2(270,600),Vector2.UP*850,0.1,[field])
	check(is_equal_approx(v.length(),850) and v.x>0,"gravity curves fast bullets without changing speed")
	fresh()
	game.combat.shield_time=10
	game.spawn_enemy(Vector2(270,750),Vector2.ZERO)
	var before: Vector2=game.enemies[0].position
	game.gravity_fields.visual_shockwave(before)
	game.gravity_fields.step(0.4)
	check(game.enemies.size()==1 and game.enemies[0].position==before and game.lives==3,"shield shockwave causes no damage or displacement")
	fresh()
	game.combat.shield_time=10
	game.spawn_hostile_shot(game.ship.position-Vector2(0,120),Vector2.DOWN*300)
	var incoming:Node2D=game.projectiles[0]
	var incoming_speed:float=incoming.velocity.length()
	game.update_projectiles(0.12)
	check(game.projectiles.has(incoming) and incoming.velocity.x!=0.0 and is_equal_approx(incoming.velocity.length(),incoming_speed),"shield gravitationally bends a hostile shot without absorbing it")
	fresh()
	game.begin_boss("black")
	game.boss.phase="firefight"
	game.boss.body_position=Vector2(270,300)
	field=well(Vector2(270,310))
	game.boss.step(0.5)
	check(game.boss.dodge_offset.length()>40.0 and game.boss.body_position.distance_to(field.well_position)>80.0,"boss burns clear of a player black hole")
	for cause in ["Enemy fire destroyed your ship.","An alien collided with your ship.","The white hole pushed you into the boundary.","A black hole collapsed your ship."]:
		fresh()
		game.instant_loss(cause)
		check(not game.ship.visible and game.death_visual.pieces.size()>10,"death creates hull plates: "+cause)
		game._process(0.1)
		check(game.death_visual.exploded == (game.death_visual.cause=="shot"),"only gunfire explodes immediately")
		game._process(0.4)
		check(game.death_visual.exploded,"ram, edge and black-hole deaths ignite after the metal deforms")
		game._process(0.6)
		check(not game.death_visual.warp_state().is_empty() and game.death_time>0.0,"fire is followed by expanding distortion before the menu")
		game._process(game.death_visual.DURATION)
		check(game.death_time==0.0 and game.death_visual.warp_state().is_empty(),"death distortion completes without leaving a permanent effect")
	game.free()
	await process_frame
	print("GRAVITY POLISH: %d passed; %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
