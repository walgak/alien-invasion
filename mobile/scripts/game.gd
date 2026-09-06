extends Node2D
## Owns the run state; the UI and actors handle their own presentation.

const Ship = preload("res://scripts/ship.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Progress = preload("res://scripts/progress.gd")
const Sound = preload("res://scripts/sound.gd")
const Interface = preload("res://scripts/interface.gd")
const Boss = preload("res://scripts/boss.gd")
const Asteroid = preload("res://scripts/asteroid.gd")
const SpaceBackground = preload("res://scripts/space_background.gd")
const SpaceFolds = preload("res://scripts/space_folds.gd")
const WeaponSystem = preload("res://scripts/weapon_system.gd")
const Pickup = preload("res://scripts/pickup.gd")
const POINTS_PER_ENEMY := 100
const MAX_LIVES := 3
const MAX_ENEMIES := 14
const BOSS_KINDS := ["black", "white", "asteroid", "swarm"]
enum State { MENU, PLAYING, PAUSED, WON, LOST }

var state := State.MENU
var selected_mode := "endless"
var encounter := "endless"
var loss_reason := "The next run starts with a clean slate."
var boss: Node2D
var asteroids: Array[Node2D] = []
var pickups: Array[Node2D] = []
var weapons = WeaponSystem.new()
var bosses_defeated := 0
var boss_timer := 40.0
var boss_warning := 0.0
var pending_boss := ""
var boss_deck: Array[String] = []
var recovery_time := 0.0
var wave_timer := 0.5
var asteroid_timer := 5.0
var save_timer := 10.0
var kills_since_drop := 0
var pickup_notice := ""
var pickup_notice_time := 0.0
var score := 0
var lives := 3
var elapsed := 0.0
var visual_time := 0.0
var shot_timer := 0.0
var enemy_shot_timer := 2.0
var damage_flash := 0.0
var best_at_start := 0
var arena := Vector2(540, 960)
var top_inset := 36.0
var bottom_inset := 28.0
var pointer_id := -1
var previous_pointer_x := 0.0
var enemies: Array[Node2D] = []
var projectiles: Array[Node2D] = []
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var progress = Progress.new()
var ship = Ship.new()
var sound = Sound.new()
var interface = Interface.new()
var space_background = SpaceBackground.new()
var space_folds = SpaceFolds.new()

func _ready() -> void:
	rng.randomize()
	space_background.z_index = -30
	add_child(space_background)
	add_child(space_folds)
	add_child(ship)
	add_child(sound)
	sound.enabled = progress.sound_enabled
	interface.game = self
	interface.z_index = 50
	add_child(interface)
	get_viewport().size_changed.connect(update_layout)
	update_layout()
	show_title()

func update_layout() -> void:
	var old_arena := arena
	arena = get_viewport_rect().size
	top_inset = 36.0
	bottom_inset = 28.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if screen.y > 0 and safe.size.y > 0:
			top_inset = maxf(top_inset, float(safe.position.y) / screen.y * arena.y + 12.0)
			bottom_inset = maxf(bottom_inset, float(screen.y - safe.end.y) / screen.y * arena.y + 12.0)
	if state == State.MENU:
		ship.position = Vector2(arena.x * 0.5, arena.y * 0.475)
	else:
		var resize_scale := arena / old_arena
		ship.position *= resize_scale
		ship.target_x = ship.position.x
		if is_instance_valid(boss):
			boss.well_position *= resize_scale
	interface.size = arena
	interface.refresh()
	refresh_space()
	queue_redraw()

func show_title() -> void:
	clear_actors()
	state = State.MENU
	sound.silence()
	pointer_id = -1
	ship.reset_ship(Vector2(arena.x * 0.5, arena.y * 0.475))
	ship.scale = Vector2.ONE * 1.65
	interface.refresh()

func start_run(mode: String = "") -> void:
	clear_actors()
	encounter = "endless"
	selected_mode = "endless"
	loss_reason = "The next run starts with a clean slate."
	score = 0
	lives = 3
	elapsed = 0.0
	bosses_defeated = 0
	weapons.level = 0
	boss_timer = rng.randf_range(38.0, 48.0)
	wave_timer = 0.4
	asteroid_timer = rng.randf_range(4.0, 7.0)
	save_timer = 10.0
	kills_since_drop = 0
	pickup_notice = ""
	pickup_notice_time = 0.0
	boss_deck.clear()
	shot_timer = 0.22
	enemy_shot_timer = 2.4
	damage_flash = 0.0
	pointer_id = -1
	best_at_start = progress.best_for(encounter)
	state = State.PLAYING
	ship.reset_ship(cruise_position())
	sound.set_boss_music(false)
	sound.set_paused(false)
	# Explicit modes are developer entry points for encounter tests only.
	if mode in BOSS_KINDS:
		begin_boss(mode)
	interface.refresh()
	refresh_space()

func cruise_position() -> Vector2:
	return Vector2(arena.x * 0.5, arena.y - bottom_inset - 152.0)

func restore_cruise_position() -> void:
	ship.position = cruise_position()
	ship.target_x = ship.position.x
	ship.rotation = 0.0
	ship.lean = 0.0
	pointer_id = -1

func clear_actors() -> void:
	for actor in enemies + projectiles + asteroids + pickups:
		actor.queue_free()
	if is_instance_valid(boss):
		boss.queue_free()
		boss = null
	enemies.clear()
	projectiles.clear()
	asteroids.clear()
	pickups.clear()
	particles.clear()
	boss_warning = 0.0
	pending_boss = ""
	recovery_time = 0.0

func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	pickup_notice_time = maxf(0.0, pickup_notice_time - delta)
	save_timer -= delta
	if save_timer <= 0.0:
		progress.save()
		save_timer = 10.0
	update_director(delta)
	damage_flash = maxf(0.0, damage_flash - delta * 2.5)
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	if is_instance_valid(boss) and boss.holds_steering():
		ship.animate(delta)
		ship.invulnerable = maxf(0, ship.invulnerable - delta)
	else:
		ship.move_ship(delta, clampf(direction, -1, 1), arena.x)
	shot_timer -= delta
	if shot_timer <= 0.0:
		shot_timer += fire_player_shot()
	if is_instance_valid(boss):
		boss.step(delta)
		if state != State.PLAYING:
			return
	update_enemies(delta)
	if state != State.PLAYING:
		return
	update_asteroids(delta)
	if state != State.PLAYING:
		return
	update_projectiles(delta)
	if state == State.PLAYING:
		update_pickups(delta)
	interface.queue_redraw()

func update_director(delta: float) -> void:
	if is_instance_valid(boss):
		return
	if recovery_time > 0.0:
		recovery_time = maxf(0.0, recovery_time - delta)
		return
	if boss_warning > 0.0:
		boss_warning = maxf(0.0, boss_warning - delta)
		if boss_warning == 0.0:
			begin_boss(pending_boss)
		return
	boss_timer -= delta
	if boss_timer <= 0.0:
		pending_boss = next_boss_kind()
		boss_warning = 3.0
		clear_hazards()
		sound.set_boss_music(true)
		interface.refresh()
		return
	wave_timer -= delta
	if wave_timer <= 0.0:
		spawn_enemy_group()
		wave_timer = rng.randf_range(1.5, 2.7) / minf(1.7, 1.0 + bosses_defeated * 0.08)
	asteroid_timer -= delta
	if asteroid_timer <= 0.0:
		var radius: float = [20.0, 31.0, 43.0][rng.randi_range(0, 2)]
		spawn_asteroid(Vector2(rng.randf_range(45.0, arena.x - 45.0), -radius - 10.0),
			Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(145.0, 205.0)), radius)
		asteroid_timer = rng.randf_range(4.0, 7.0)

func next_boss_kind() -> String:
	if boss_deck.is_empty():
		boss_deck.assign(BOSS_KINDS)
		for i in range(boss_deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := boss_deck[i]
			boss_deck[i] = boss_deck[j]
			boss_deck[j] = swap
	return boss_deck.pop_back()

func spawn_enemy_group() -> void:
	var count := mini(rng.randi_range(1, 5 + mini(bosses_defeated / 2, 2)), MAX_ENEMIES - enemies.size())
	if count <= 0:
		return
	var group_center := rng.randf_range(90.0, arena.x - 90.0)
	for i in range(count):
		var x := clampf(group_center + (i - (count - 1) * 0.5) * 66.0 + rng.randf_range(-16.0, 16.0), 38.0, arena.x - 38.0)
		spawn_enemy(Vector2(x, -45.0 - i * 42.0), Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(95.0, 145.0) + minf(bosses_defeated * 7.0, 80.0)))

func spawn_enemy(at: Vector2, velocity: Vector2, summoned: bool = false, fold_origin: Vector2 = Vector2.INF) -> Node2D:
	var enemy = Enemy.new()
	enemy.position = at
	enemy.previous_position = at
	enemy.velocity = velocity
	enemy.phase = rng.randf_range(0.0, TAU)
	enemy.shot_timer = rng.randf_range(1.7, 3.4)
	enemy.summoned = summoned
	enemy.tint = Color("73eac4") if summoned else [Color("ffb86a"), Color("f1958d"), Color("baacf5")][rng.randi_range(0, 2)]
	if fold_origin != Vector2.INF:
		enemy.begin_pull(fold_origin)
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func begin_boss(kind: String) -> void:
	clear_hazards()
	boss_warning = 0.0
	pending_boss = ""
	boss = Boss.new()
	boss.game = self
	boss.kind = kind if kind in BOSS_KINDS else "black"
	boss.max_health = 75 + bosses_defeated * 20
	boss.health = boss.max_health
	add_child(boss)
	boss.step(0.0)
	sound.set_boss_music(true)
	interface.refresh()

func defeat_boss(defeated: Node2D) -> void:
	if state != State.PLAYING or defeated != boss:
		return
	var was_gravity: bool = defeated.kind in ["black", "white"]
	var at: Vector2 = defeated.body_position
	burst(at, Color("ffca8d"), 60)
	add_score(1500 + bosses_defeated * 250)
	bosses_defeated += 1
	defeated.queue_free()
	boss = null
	clear_hazards()
	if was_gravity:
		restore_cruise_position()
	ship.invulnerable = maxf(ship.invulnerable, 2.5)
	spawn_pickup(Vector2(ship.position.x, ship.position.y - 130.0), "weapon")
	recovery_time = 3.0
	boss_timer = rng.randf_range(40.0, 55.0)
	wave_timer = 0.5
	asteroid_timer = 4.0
	sound.set_boss_music(false)
	sound.play_effect("win")
	progress.save()
	interface.refresh()
	refresh_space()

func clear_hazards() -> void:
	for enemy in enemies.duplicate():
		remove_enemy(enemy)
	for rock in asteroids.duplicate():
		remove_asteroid(rock)
	for shot in projectiles.duplicate():
		remove_projectile(shot)

func _process(delta: float) -> void:
	if state != State.PAUSED:
		visual_time += delta
		if state != State.PLAYING:
			ship.animate(delta)
		for i in range(particles.size() - 1, -1, -1):
			particles[i].life -= delta
			particles[i].position += particles[i].velocity * delta
			particles[i].velocity *= exp(-delta * 3.0)
			if particles[i].life <= 0:
				particles.remove_at(i)
	queue_redraw()
	interface.queue_redraw()
	refresh_space()

func refresh_space() -> void:
	space_background.update_background(arena, visual_time)
	space_folds.update_effects(self)

func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not enemies.has(enemy):
			continue
		if is_instance_valid(boss) and enemy.summoned:
			enemy.fold_origin = boss.body_position + Vector2(0, 42)
		enemy.advance(delta, ship.position)
		if enemy.motion_phase == "flight":
			enemy.position.x = clampf(enemy.position.x, 32.0, arena.x - 32.0)
		var closest := Geometry2D.get_closest_point_to_segment(ship.position, enemy.previous_position, enemy.position)
		if closest.distance_to(ship.position) < Ship.HIT_RADIUS + Enemy.HIT_RADIUS:
			remove_enemy(enemy)
			damage_ship()
			if state != State.PLAYING:
				return
			continue
		if enemy.position.y > arena.y + 65.0:
			remove_enemy(enemy)
			continue
		if enemy.motion_phase == "flight" and enemy.position.y > top_inset + 110.0 and enemy.position.y < ship.position.y - 90.0:
			enemy.shot_timer -= delta
			if enemy.shot_timer <= 0.0:
				var aim: Vector2 = (ship.position - enemy.position).normalized()
				spawn_hostile_shot(enemy.position + Vector2(0, 24), aim * (215.0 if enemy.summoned else 180.0))
				enemy.shot_timer = rng.randf_range(2.1, 3.8)

func fire_player_shot() -> float:
	return weapons.fire(self)

func fire_enemy_shot() -> void:
	var shooter = enemies[rng.randi_range(0, enemies.size() - 1)]
	# Modest horizontal aim: the player can read and dodge the trajectory.
	spawn_hostile_shot(shooter.position + Vector2(0, 23), Vector2(clampf((ship.position.x - shooter.position.x) * 0.24, -72, 72), 245))

func spawn_hostile_shot(at: Vector2, velocity: Vector2) -> void:
	var shot = Projectile.new()
	shot.hostile = true
	shot.position = at
	shot.previous_position = shot.position
	shot.velocity = velocity
	add_child(shot)
	projectiles.append(shot)

func update_projectiles(delta: float) -> void:
	for shot in projectiles.duplicate():
		if not projectiles.has(shot):
			continue
		shot.advance(delta)
		if shot.hostile:
			if shot.intersects(ship.position, Ship.HIT_RADIUS + 3.0):
				remove_projectile(shot)
				damage_ship()
				if state != State.PLAYING:
					return
		else:
			var targets: Array[Dictionary] = []
			for rock in asteroids.duplicate():
				if shot.intersects(rock.position, rock.radius):
					targets.append({"actor": rock, "type": "rock", "at": rock.position})
			if is_instance_valid(boss) and shot.intersects(boss.body_position, Boss.HIT_RADIUS):
				targets.append({"actor": boss, "type": "boss", "at": boss.body_position})
			for enemy in enemies.duplicate():
				if shot.intersects(enemy.position, Enemy.HIT_RADIUS):
					targets.append({"actor": enemy, "type": "enemy", "at": enemy.position})
			targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return shot.previous_position.distance_squared_to(a.at) < shot.previous_position.distance_squared_to(b.at))
			for target in targets:
				if not projectiles.has(shot):
					break
				var id: int = target.actor.get_instance_id()
				if shot.hit_ids.has(id):
					continue
				shot.hit_ids[id] = true
				damage_target(target.actor, target.type, shot.damage)
				if shot.blast_radius > 0.0:
					detonate_rocket(target.at, shot.blast_radius, target.actor)
				if not shot.piercing:
					if projectiles.has(shot):
						remove_projectile(shot)
					break
		if state != State.PLAYING:
			return
		if projectiles.has(shot) and (shot.expired or shot.position.y < -50 or shot.position.y > arena.y + 50 or shot.position.x < -80 or shot.position.x > arena.x + 80):
			remove_projectile(shot)

func damage_target(actor: Node2D, kind: String, amount: int) -> void:
	if kind == "rock" and asteroids.has(actor):
		hit_asteroid(actor, amount)
	elif kind == "boss" and actor == boss:
		boss.take_hit(amount)
	elif kind == "enemy" and enemies.has(actor):
		actor.health -= amount
		if actor.health <= 0:
			destroy_enemy(actor)

func detonate_rocket(at: Vector2, radius: float, direct_target: Node2D) -> void:
	burst(at, Color("ffb86a"), 24)
	for enemy in enemies.duplicate():
		if enemy != direct_target and enemy.position.distance_to(at) <= radius + Enemy.HIT_RADIUS:
			damage_target(enemy, "enemy", 2)
	for rock in asteroids.duplicate():
		if rock != direct_target and rock.position.distance_to(at) <= radius + rock.radius:
			hit_asteroid(rock, 2)
	if is_instance_valid(boss) and boss != direct_target and boss.body_position.distance_to(at) <= radius + Boss.HIT_RADIUS:
		boss.take_hit(2)
	sound.play_effect("burst")

func remove_projectile(shot: Node2D) -> void:
	projectiles.erase(shot)
	shot.queue_free()

func destroy_enemy(enemy: Node2D) -> void:
	if not enemies.has(enemy):
		return
	burst(enemy.position, enemy.tint, 18)
	maybe_drop_pickup(enemy.position)
	remove_enemy(enemy)
	add_score(POINTS_PER_ENEMY)
	sound.play_effect("burst")

func remove_enemy(enemy: Node2D) -> void:
	enemies.erase(enemy)
	enemy.queue_free()

func maybe_drop_pickup(at: Vector2) -> void:
	kills_since_drop += 1
	var roll := rng.randf()
	if roll < 0.19 or kills_since_drop >= 10:
		spawn_pickup(at, "weapon")
		kills_since_drop = 0
	elif roll < 0.28:
		spawn_pickup(at, "life")

func spawn_pickup(at: Vector2, kind: String) -> void:
	if pickups.size() >= 12:
		return
	var pickup = Pickup.new()
	pickup.kind = kind
	pickup.position = Vector2(clampf(at.x, 30.0, arena.x - 30.0), maxf(at.y, top_inset + 110.0))
	pickup.previous_position = pickup.position
	pickup.phase = rng.randf_range(0.0, TAU)
	add_child(pickup)
	pickups.append(pickup)

func update_pickups(delta: float) -> void:
	# Drops wait while gravity replaces steering with tapping.
	if is_instance_valid(boss) and boss.holds_steering():
		return
	for pickup in pickups.duplicate():
		pickup.advance(delta)
		if pickup.position.distance_to(ship.position) < 135.0:
			pickup.position = pickup.position.move_toward(ship.position, 210.0 * delta)
		var closest := Geometry2D.get_closest_point_to_segment(ship.position, pickup.previous_position, pickup.position)
		if closest.distance_to(ship.position) <= Ship.HIT_RADIUS + Pickup.HIT_RADIUS:
			collect_pickup(pickup)
		elif pickup.position.y > arena.y + 45.0:
			pickups.erase(pickup)
			pickup.queue_free()

func collect_pickup(pickup: Node2D) -> void:
	if not pickups.has(pickup):
		return
	if pickup.kind == "life":
		if lives < MAX_LIVES:
			lives += 1
			pickup_notice = "HULL RESTORED +1"
		else:
			add_score(100)
			pickup_notice = "FULL HULL  +100"
	else:
		if weapons.level < WeaponSystem.MAX_LEVEL:
			weapons.upgrade()
			shot_timer = 0.0
			pickup_notice = weapons.weapon_name() + " ONLINE"
		else:
			add_score(150)
			pickup_notice = "MAX WEAPON  +150"
	pickup_notice_time = 2.0
	burst(pickup.position, Color("7cf3b7") if pickup.kind == "life" else Color("ffc56e"), 14)
	pickups.erase(pickup)
	pickup.queue_free()
	sound.play_effect("pickup")
	interface.refresh()

func add_score(points: int) -> void:
	score += points
	progress.record_score(encounter, score)

func select_mode(mode: String) -> void:
	selected_mode = mode
	interface.refresh()

func spawn_asteroid(at: Vector2, velocity: Vector2, radius: float, health: int = 0, fold_origin: Vector2 = Vector2.INF, aim_offset: Vector2 = Vector2.ZERO) -> void:
	var rock = Asteroid.new()
	rock.position = at
	rock.previous_position = at
	rock.velocity = velocity
	rock.radius = radius
	if health <= 0:
		health = 3 if radius < 26.0 else (6 if radius < 37.0 else 10)
	rock.health = health
	rock.spin = rng.randf_range(-2, 2)
	if fold_origin != Vector2.INF:
		rock.begin_pull(fold_origin, aim_offset)
	add_child(rock)
	asteroids.append(rock)

func update_asteroids(delta: float) -> void:
	for rock in asteroids.duplicate():
		if not asteroids.has(rock):
			continue
		if is_instance_valid(boss) and boss.kind == "asteroid":
			rock.fold_origin = boss.body_position + Vector2(0, 42)
		rock.advance(delta, ship.position)
		var closest := Geometry2D.get_closest_point_to_segment(ship.position, rock.previous_position, rock.position)
		if closest.distance_to(ship.position) <= rock.radius + Ship.HIT_RADIUS:
			remove_asteroid(rock)
			damage_ship()
			if state != State.PLAYING:
				return
		elif rock.position.y > arena.y + 60:
			remove_asteroid(rock)

func hit_asteroid(rock: Node2D, amount: int = 1) -> void:
	rock.health -= amount
	rock.flash = 0.08
	if rock.health <= 0:
		burst(rock.position, Color("d6b899"), 15)
		remove_asteroid(rock)
		add_score(25)
		sound.play_effect("burst")

func remove_asteroid(rock: Node2D) -> void:
	asteroids.erase(rock)
	rock.queue_free()

func lose_ship(reason: String) -> void:
	if state != State.PLAYING:
		return
	lives = 0
	if use_emergency_life():
		return
	ship.visible = false
	loss_reason = reason
	burst(ship.position, Color("ff816f"), 42)
	sound.play_effect("hit")
	finish_run(false)

func damage_ship() -> void:
	if state != State.PLAYING or ship.invulnerable > 0.0:
		return
	lives -= 1
	damage_flash = 0.6
	burst(ship.position, Color("ff816f"), 28)
	sound.play_effect("hit")
	if lives == 0:
		if use_emergency_life():
			return
		ship.visible = false
		finish_run(false)
		return
	ship.invulnerable = 1.6
	for shot in projectiles.duplicate():
		if shot.hostile:
			remove_projectile(shot)

func use_emergency_life() -> bool:
	if weapons.level <= 0:
		return false
	weapons.level = 0
	lives = 1
	ship.visible = true
	ship.invulnerable = 2.5
	restore_cruise_position()
	clear_hazards()
	if is_instance_valid(boss):
		boss.return_to_firefight()
	shot_timer = 0.0
	pickup_notice = "EMERGENCY LIFE · SINGLE SHOT"
	pickup_notice_time = 3.0
	sound.play_effect("pickup")
	interface.refresh()
	return true

func finish_run(won: bool) -> void:
	if state != State.PLAYING:
		return
	if won:
		if is_instance_valid(boss):
			defeat_boss(boss)
		return
	state = State.LOST
	sound.silence()
	pointer_id = -1
	for shot in projectiles.duplicate():
		remove_projectile(shot)
	progress.save()
	interface.refresh()

func pause_run() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	pointer_id = -1
	ship.target_x = ship.position.x
	sound.set_paused(true)
	progress.save()
	interface.refresh()

func resume_run() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	sound.set_paused(false)
	pointer_id = -1
	interface.refresh()

func toggle_sound() -> void:
	progress.sound_enabled = not progress.sound_enabled
	sound.enabled = progress.sound_enabled
	sound.sync_enabled()
	progress.save()
	interface.refresh()

func burst(at: Vector2, tint: Color, count: int) -> void:
	for i in range(count):
		var duration := rng.randf_range(0.25, 0.75)
		particles.append({"position": at, "velocity": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 220),
			"life": duration, "duration": duration, "tint": tint, "radius": rng.randf_range(1.5, 4.0)})

func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and is_instance_valid(boss) and boss.holds_steering():
		var pressed_touch: bool = event is InputEventScreenTouch and event.pressed
		var pressed_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
		var pressed_space: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
		if pressed_touch or pressed_mouse or pressed_space:
			boss.resist()
		# Pause remains available during a gravity attack; dragging is suspended.
		if not (event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_P]):
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			if state == State.PLAYING:
				pause_run()
			elif state == State.PAUSED:
				resume_run()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and state in [State.MENU, State.WON, State.LOST]:
			start_run()
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -1 and event.position.y > top_inset + 110:
			pointer_id = event.index
			previous_pointer_x = event.position.x
		elif not event.pressed and event.index == pointer_id:
			pointer_id = -1
	elif event is InputEventScreenDrag and event.index == pointer_id:
		drag_to(event.position.x)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and pointer_id == -1 and event.position.y > top_inset + 110:
			pointer_id = -2
			previous_pointer_x = event.position.x
		elif not event.pressed and pointer_id == -2:
			pointer_id = -1
	elif event is InputEventMouseMotion and pointer_id == -2:
		drag_to(event.position.x)

func drag_to(x: float) -> void:
	ship.target_x = clampf(ship.target_x + x - previous_pointer_x, 35.0, arena.x - 35.0)
	previous_pointer_x = x

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if is_instance_valid(interface) and interface.is_inside_tree():
			pause_run()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		progress.save()

func _draw() -> void:
	if state == State.MENU:
		var center := Vector2(arena.x * 0.5, arena.y * 0.475)
		draw_arc(center, 106, 0.0, TAU, 90, Color("203248"), 1, true)
		draw_arc(center, 130, visual_time * 0.15, visual_time * 0.15 + PI * 1.15, 80, Color("284856"), 1, true)
		draw_circle(center + Vector2.from_angle(visual_time * 0.15) * 130, 3, Color("55e8d0"))
	for particle in particles:
		var tint: Color = particle.tint
		tint.a = particle.life / particle.duration
		draw_circle(particle.position, particle.radius, tint)
