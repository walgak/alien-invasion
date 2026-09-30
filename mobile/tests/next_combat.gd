extends SceneTree
## Regression coverage for loot ownership, core-safe energy, and release recoil.
var game: Node2D
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if value: print("PASS: "+label)
	else:
		failures += 1
		push_error(label)
func fresh() -> void:
	game.start_run()
	game.wave_timer=10000
	game.asteroid_timer=10000
	game.boss_timer=10000
func field(kind: String,at: Vector2) -> Node2D:
	var well = game.Boss.new()
	well.game=game
	well.kind=kind
	well.lingering=true
	well.phase="active"
	well.well_position=at
	game.add_child(well)
	game.lingering_wells.append(well)
	return well
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("next-combat-record.cfg"):
		quit(1)
		return
	root.size=Vector2i(540,960)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled=false
	game.progress.vibration_enabled=false
	fresh()
	game.bosses_defeated=80
	var enemy: Node2D=game.spawn_enemy(Vector2(230,350),Vector2.ZERO)
	check(enemy.health==3,"alien durability remains three across difficulty")
	game.damage_target(enemy,"enemy",1)
	check(enemy.health==2 and game.enemies.has(enemy),"first bullet wrecks the alien without killing")
	game.damage_target(enemy,"enemy",1)
	check(enemy.health==1,"second bullet reaches smoke stage")
	game.damage_target(enemy,"enemy",1)
	check(not game.enemies.has(enemy),"third bullet destroys alien")
	fresh()
	var exact_loot := true
	for i in range(80):
		game.boss_drops(Vector2(270,400))
		var drops: Array=game.pickups.slice(-3)
		exact_loot = exact_loot and drops.size()==3 and drops[0].kind in ["laser","electron"] and drops[1].kind=="weapon" and drops[2].kind=="shield"
	check(exact_loot,"boss always drops exactly special/upgrade/shield across rolls and full pickup pool")
	fresh()
	game.weapons.level=4
	for i in range(150): game.guaranteed_drop(Vector2(270,400))
	check(game.pickups.all(func(p: Node2D)->bool:return p.kind not in ["laser","electron"]),"swarm rewards cannot produce boss-only specials")
	fresh()
	game.begin_boss("asteroid")
	game.boss.phase="firefight"
	game.boss.body_position=Vector2(270,180)
	var health: float=game.boss.health
	for point in [Vector2(270,470),Vector2(120,380),Vector2(390,330)]:
		enemy=game.spawn_enemy(point,Vector2.ZERO)
		enemy.shield_guard=true
	game.spawn_asteroid(Vector2(160,270),Vector2.ZERO,43,90)
	check(game.fire_electron(),"electron activates on a valid visible chain")
	for i in range(180): game.electron_beam.step(0.06)
	check(game.enemies.is_empty() and game.asteroids.is_empty(),"electron clears small aliens and melts asteroids without fragments")
	check(is_equal_approx(game.boss.health,health-3),"electron hits boss once for cannon damage after guards")
	fresh()
	check(not game.fire_electron(),"empty screen does not spend electron charge")
	var well:=field("black",Vector2(270,420))
	var shot=game.weapons.spawn_shot(game,Vector2(270,470),Vector2(0,-850))
	game.update_projectiles(0.15)
	check(not game.projectiles.has(shot),"fast projectile is swallowed before crossing black core")
	var segments: Array[Vector2]=game.reflected_laser(Vector2(270,650))
	var safe:=true
	for i in range(0,segments.size()-1,2):
		var closest:=Geometry2D.get_closest_point_to_segment(well.well_position,segments[i],segments[i+1])
		if closest.distance_to(well.well_position)<30.99: safe=false
	check(safe and segments.back().y>420 and is_equal_approx(segments.back().distance_to(well.well_position),31.0),"laser is absorbed at the near horizon without splitting through the core")
	fresh()
	well=field("white",Vector2(270,420))
	shot=game.weapons.spawn_shot(game,Vector2(270,470),Vector2(0,-850))
	game.update_projectiles(0.15)
	check(game.projectiles.has(shot) and shot.position.distance_to(well.well_position)>31 and absf(shot.velocity.x)>50,"white core deflects rather than transmits a projectile")
	fresh()
	var edge_rock: Node2D=game.spawn_asteroid(Vector2(5,350),Vector2.ZERO,43,12)
	enemy=game.spawn_enemy(Vector2(28,375),Vector2.ZERO)
	game.weapons.spawn_shot(game,Vector2(5,500),Vector2(0,-850))
	game.update_projectiles(0.22)
	check(edge_rock.health==11 and enemy.health==3,"edge collisions choose the nearer asteroid surface instead of the nearer alien center")
	fresh()
	for index in range(8):
		well=field("black" if index%2==0 else "white",Vector2(240+(index%3)*32,360+index*15))
		well.well_scale=2.2
	var route: Array[Vector2]=game.route_energy_link(Vector2(270,720),Vector2(270,120))
	check(route.size()<=game.EnergyOptics.MAX_ROUTE_POINTS,"overlapping-core routing stays inside its allocation budget")
	var route_safe:=true
	for index in range(0,route.size()-1,2):
		for active in game.gravity_fields.active_wells():
			var closest:=Geometry2D.get_closest_point_to_segment(active.well_position,route[index],route[index+1])
			if closest.distance_to(active.well_position)<31.0*active.well_scale-0.1: route_safe=false
	check(route_safe,"truncated crowded optical paths stop at the first obstructing horizon")
	fresh()
	game.combat.shield_time=10
	game.spawn_escape_cannon(game.ship.position+Vector2(0,90))
	game.update_projectiles(0.1)
	check(game.projectiles.is_empty() and game.lives==3 and not game.gravity_fields.shockwaves.is_empty(),"shield absorbs doom cannon and emits safe outward ripple")
	fresh()
	game.ship.position=Vector2(180,260)
	game.ship.target_x=180
	game.request_cruise_return(Vector2(0,-90))
	game._physics_process(0.05)
	check(game.recoil_time>0 and game.ship.position.y>260,"gravity release briefly preserves resistance thrust")
	for i in range(300): game._physics_process(1.0/60.0)
	check(absf(game.ship.position.y-game.cruise_position().y)<0.1 and absf(game.ship.position.x-180)<0.1,"recoil settles to cruise Y while preserving X")
	fresh()
	var regular_drop_count := true
	for index in range(25):
		enemy = game.spawn_enemy(Vector2(200,350),Vector2.ZERO)
		enemy.drop_group = {"awarded": false}
		game.destroy_enemy(enemy)
		regular_drop_count = regular_drop_count and game.pickups.size()==int((index+1)/10)
	check(regular_drop_count,"one drop per ten defeats across independent swarms, with no first-kill bonus")
	fresh()
	game.begin_boss("asteroid")
	game.boss.phase = "firefight"
	game.boss.body_position = Vector2(270,180)
	game.combat.missiles = 2
	var boss_health: float = game.boss.health
	check(game.combat.can_fire_cannon_button() and game.combat.fire_cannon_volley()==1 and game.combat.missiles==1,"cannon button can fire one at a visible boss with fewer than five in stock")
	game.combat.press(41,game.boss.body_position)
	game.combat.release(41,game.boss.body_position)
	check(not game.combat.can_fire_cannon_button() and game.combat.fire_cannon_volley()==0 and game.combat.missiles==1,"tap and button share the one-cannon-in-flight boss limit")
	for frame in range(100): game.update_projectiles(1.0/60.0)
	check(game.boss.health==boss_health-3 and not game.combat.boss_cannon_in_flight(),"boss-targeted cannon actually damages the boss and releases its flight limit")
	game.combat.press(42,game.boss.body_position)
	game.combat.release(42,game.boss.body_position)
	check(game.combat.missiles==0 and game.combat.boss_cannon_in_flight(),"next boss tap may fire only after the previous cannon resolves")
	fresh()
	game.combat.gravity_charge = 50.0
	game.combat.arm_gravity()
	check(game.interface.gravity_target_position().is_equal_approx(game.arena*Vector2(0.5,0.25)),"armed target marker indicates the automatic upper-half destination")
	game.combat.press(53,Vector2(100,20))
	check(game.interface.gravity_target_position()==Vector2(100,20),"target preview accepts visible upper-edge space with no old top-bar cutoff")
	game.combat.release(53,Vector2(100,20))
	check(not game.combat.gravity_armed and game.combat.pending_gravity_time>0.0,"target selection hides the guide and starts preparation")
	check(is_equal_approx(game.PlayerWell.scale_for_charge(1),0.9) and is_equal_approx(game.PlayerWell.scale_for_charge(5),1.35),"player charge uses the smaller core range without changing lifetime or force")
	print("NEXT_COMBAT: %d checks, %d failures"%[checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
