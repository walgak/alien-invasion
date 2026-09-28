extends SceneTree
## Cross-generation reward eligibility and actual swept shield contact behavior.
var game: Node2D
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	if value:
		passed += 1
		print("PASS: "+label)
	else:
		failed += 1
		push_error(label)
func fresh() -> void:
	game.start_run()
	game.sound.enabled=false
	game.progress.vibration_enabled=false
	game.wave_timer=1000
	game.boss_timer=1000
	game.asteroid_timer=1000
func large() -> Node2D:
	return game.spawn_asteroid(Vector2(260,330),Vector2.ZERO,43)
func finish_all() -> void:
	var safety:=0
	while not game.asteroids.is_empty() and safety<32:
		var rock: Node2D=game.asteroids[0]
		game.damage_target(rock,"rock",rock.health,"primary")
		safety += 1
func specials() -> int:
	return game.pickups.filter(func(item: Node2D)->bool:return item.kind in ["laser","electron"]).size()
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("asteroid-rewards-zaps-record.cfg"):
		quit(1)
		return
	root.size=Vector2i(540,960)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	fresh()
	var rock:=large()
	var family: Dictionary=rock.reward_family
	game.damage_target(rock,"rock",rock.health,"primary")
	check(family.remaining==2 and specials()==0,"large rock starts one shared family and no early special")
	for medium in game.asteroids.duplicate(): game.damage_target(medium,"rock",medium.health,"primary")
	check(game.asteroids.size()==4 and family.remaining==4,"all four terminal fragments retain the same family")
	for i in range(3):
		rock=game.asteroids[0]
		game.damage_target(rock,"rock",rock.health,"primary")
	check(specials()==0 and family.remaining==1,"no reward until the last fragment")
	rock=game.asteroids[0]
	game.damage_target(rock,"rock",rock.health,"primary")
	game.hit_asteroid(rock,100,true,"primary")
	check(specials()==1 and game.pickups.size()==1 and family.rewarded,"last piece pays one boss-only special exactly once")
	fresh()
	rock=large()
	game.damage_target(rock,"rock",1,"special")
	finish_all()
	check(specials()==0,"a nonfatal special hit on the ancestor disqualifies all descendants")
	fresh()
	rock=large()
	game.damage_target(rock,"rock",rock.health,"primary")
	game.damage_target(game.asteroids[0],"rock",1,"special")
	finish_all()
	check(specials()==0,"special damage to one descendant cancels the shared bonus")
	fresh()
	rock=large()
	game.damage_target(rock,"rock",rock.health,"primary")
	game.remove_asteroid(game.asteroids[0])
	finish_all()
	check(specials()==0,"an escaped fragment cancels the family completion reward")
	fresh()
	game.spawn_asteroid(Vector2(260,330),Vector2.ZERO,20)
	finish_all()
	check(specials()==0,"unrelated small asteroids never grant this reward")
	fresh()
	rock=large()
	var shot=game.weapons.spawn_shot(game,rock.position,Vector2.ZERO)
	shot.kind="plasma"
	shot.damage=2
	game.update_projectiles(0)
	check(rock.health==10 and rock.reward_family.eligible,"actual enhanced primary plasma preserves eligibility")
	for i in range(12): game.spawn_pickup(Vector2(40+i*30,250),"life",true)
	finish_all()
	check(game.pickups.size()==12 and specials()==1,"guaranteed final reward survives a full pickup pool")
	fresh()
	game.combat.shield_time=10
	var reach: float=game.combat.shield_radius()+game.Enemy.Artwork.size_for().x*0.5+1.0
	var enemy: Node2D=game.spawn_enemy(game.ship.position+Vector2(0,-reach-1),Vector2.ZERO)
	check(not game.shield_zap_if_close(enemy,enemy.position,enemy.position),"shield does not zap before the one-pixel proximity margin")
	enemy.position.y += 1.1
	check(game.shield_zap_if_close(enemy,enemy.position,enemy.position) and not game.enemies.has(enemy) and game.lives==3,"shield zaps at the circumference without taking a life")
	check(game.impact_visual.ages.min()==0.0,"proximity zap triggers the electrical animation")
	fresh()
	game.combat.shield_time=10
	enemy=game.spawn_enemy(game.ship.position+Vector2(0,-150),Vector2(0,5000))
	enemy.zigzag=false
	game.update_enemies(0.1)
	check(not game.enemies.has(enemy) and game.projectiles.is_empty(),"fast ship crossing the dome is zapped before it can fire an escape cannon")
	fresh()
	enemy=game.spawn_enemy(game.ship.position,Vector2.ZERO)
	game.handle_alien_collision(enemy)
	check(game.lives==2 and not game.enemies.has(enemy) and game.impact_visual.ages.min()==0.0,"unshielded ram zaps only at contact and costs one life")
	print("ASTEROID REWARDS/ZAPS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	await process_frame
	quit(0 if failed==0 else 1)
