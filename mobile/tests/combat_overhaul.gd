extends SceneTree
## Integration regressions for viewport-edge collision, redirected ore, and
## the distinction between incoming-hazard protection and gravity immunity.
var game: Node2D
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func fresh() -> void:
	game.start_run()
	game.wave_timer = 10000.0
	game.boss_timer = 10000.0
	game.asteroid_timer = 10000.0
	game.sound.enabled = false
	game.progress.vibration_enabled = false

func alien(at: Vector2) -> Node2D:
	game.spawn_enemy(at, Vector2.ZERO)
	var enemy: Node2D = game.enemies.back()
	enemy.zigzag = false
	return enemy

func field(kind: String) -> Node2D:
	var well = game.Boss.new()
	well.game = game
	well.kind = kind
	well.phase = "active"
	well.lingering = true
	well.well_position = Vector2(380, 510)
	game.add_child(well)
	game.lingering_wells.append(well)
	return well

func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("combat-overhaul-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	fresh()
	var edge: float = game.top_inset + 140.0
	for at in [Vector2(-10, 400), Vector2(550,400), Vector2(270,edge-10), Vector2(270,970)]:
		var rock: Node2D = game.spawn_asteroid(at,Vector2.ZERO,20)
		var visible: Vector2 = at.clamp(Vector2(1,edge+1),game.arena-Vector2.ONE)
		var shot = game.weapons.spawn_shot(game,visible,Vector2.ZERO)
		var before: int = rock.health
		game.update_projectiles(0.0)
		check(rock.health == before-1, "visible asteroid edge receives a shot at " + str(at))
	fresh()
	var rock: Node2D = game.spawn_asteroid(Vector2(-30,400),Vector2.ZERO,20)
	var shot = game.weapons.spawn_shot(game,Vector2(-30,450),Vector2(0,-500))
	game.update_projectiles(0.1)
	check(rock.health == rock.max_health, "a completely offscreen target cannot receive a shot")
	rock.position = Vector2(-10,400)
	shot = game.weapons.spawn_shot(game,Vector2(-15,410),Vector2(0,-100))
	game.update_projectiles(0.1)
	check(rock.health == rock.max_health, "offscreen portion of a partially visible rock cannot receive a shot")
	fresh()
	rock = game.spawn_asteroid(Vector2(540,400),Vector2.ZERO,20)
	shot = game.weapons.spawn_shot(game,Vector2(500,400),Vector2(1000,0))
	game.update_projectiles(0.1)
	check(rock.health == rock.max_health-1, "fast shot registers visible contact before leaving the viewport")
	fresh()
	var upper := alien(Vector2(150,300))
	var lower := alien(Vector2(300,600))
	game.begin_boss("swarm")
	check(upper.shield_guard and not lower.shield_guard and game.boss.guard_total == 1, "only upper-half aliens join a new boss shield")
	var old_y: float = lower.position.y
	lower.velocity = Vector2(0,100)
	game.update_enemies(0.1)
	check(lower.position.y > old_y, "lower alien continues forward during the boss introduction")
	fresh()
	game.weapons.level = 4
	game.ship.invulnerable = 0.0
	var victim := alien(game.ship.position)
	game.handle_alien_collision(victim)
	check(game.lives == 2 and not game.enemies.has(victim), "alien collision destroys alien and costs exactly one life")
	check(game.impact_visual.surfaces.any(func(surface: ColorRect) -> bool: return surface.visible), "alien collision starts an electrical discharge")
	game.ship.invulnerable = 0.0
	game.lives = 1
	game.damage_ship()
	check(game.state == game.State.LOST and game.lives == 0, "weapon upgrades do not create an extra life")
	fresh()
	game.lives = 2
	for count in range(2):
		game.spawn_pickup(Vector2(200,300),"shield")
		var pickup: Node2D = game.pickups.back()
		pickup.kind = "life"
		game.collect_pickup(pickup)
	check(game.lives == 3, "health drops refill lives and stop at three")
	fresh()
	field("black")
	rock = game.spawn_asteroid(game.ship.position,Vector2(0,100),20)
	game.update_asteroids(0.0)
	check(game.state == game.State.PLAYING and rock.player_deflected and rock.position.distance_to(game.ship.position) > 35.0, "forced tapping deflects a colliding asteroid")
	victim = alien(game.ship.position)
	game.handle_alien_collision(victim)
	check(game.lives == 3 and game.enemies.has(victim) and victim.position.distance_to(game.ship.position) > 39.0, "gravity hazard protection deflects alien contact without a life loss")
	game.spawn_hostile_shot(game.ship.position,Vector2(0,180))
	shot = game.projectiles.back()
	game.update_projectiles(0.0)
	check(game.lives == 3 and game.projectiles.has(shot) and shot.position.distance_to(game.ship.position) > 40.0, "gravity hazard protection bends bullets instead of absorbing them")
	game.lose_ship("Caught in a black hole.")
	check(game.state == game.State.LOST, "automatic hazard protection never grants immunity to a gravity core")
	fresh()
	rock = game.spawn_asteroid(Vector2(270,400),Vector2.ZERO,43)
	victim = alien(Vector2(270,400))
	game.update_asteroids(0.0)
	check(game.enemies.has(victim) and game.asteroids.has(rock), "ambient asteroids do not kill aliens")
	rock.player_deflected = true
	game.update_asteroids(0.0)
	check(not game.enemies.has(victim) and not game.asteroids.has(rock) and game.asteroids.size() == 2, "a player-redirected asteroid kills an alien and fractures once")
	check(game.asteroids.all(func(child: Node2D) -> bool: return child.player_deflected), "fragments preserve player deflection ownership")
	fresh()
	game.begin_boss("asteroid")
	game.boss.step(1.5)
	var hp: float = game.boss.health
	rock = game.spawn_asteroid(game.boss.body_position,Vector2.ZERO,20)
	rock.player_deflected = true
	game.update_asteroids(0.0)
	game.update_asteroids(0.0)
	check(game.boss.health == hp-3.0 and game.asteroids.is_empty(), "redirected ore damages a boss like one cannon, once")
	fresh()
	game.begin_boss("black")
	game.boss.step(1.5)
	victim = alien(game.boss.body_position+Vector2(110,0))
	victim.shield_guard = true
	hp = game.boss.health
	rock = game.spawn_asteroid(game.boss.body_position,Vector2.ZERO,20)
	rock.player_deflected = true
	game.update_asteroids(0.0)
	check(game.boss.health == hp, "redirected ore respects the remaining alien guard shield")
	var impulses: Array[float] = []
	for radius in [20.0,43.0]:
		fresh()
		rock = game.spawn_asteroid(Vector2(275,400),Vector2.ZERO,radius)
		var beams: Array[Vector2] = game.reflected_laser(Vector2(270,700),0.1)
		impulses.append(rock.velocity.length())
		var safe := true
		for index in range(0,beams.size(),2):
			safe = safe and beams[index+1].y <= beams[index].y+0.01
		check(rock.player_deflected and safe and rock.health == rock.max_health, "laser pushes and safely reflects from ore of radius " + str(radius))
	check(impulses[0] > impulses[1]*3.0, "laser momentum changes small asteroid paths more strongly")
	fresh()
	game.spawn_pickup(Vector2(100,300),"missiles")
	game.combat.missiles = 98
	game.collect_pickup(game.pickups.back())
	check(game.combat.missiles == 99, "cannon inventory caps at ninety-nine")
	await process_frame
	game.free()
	await process_frame
	print("COMBAT OVERHAUL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
