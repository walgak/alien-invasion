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
const ENEMY_COUNT := 15
const POINTS_PER_ENEMY := 100
enum State { MENU, PLAYING, PAUSED, WON, LOST }

var state := State.MENU
var selected_mode := "fleet"
var encounter := "fleet"
var loss_reason := "The next run starts with a clean slate."
var boss: Node2D
var asteroids: Array[Node2D] = []
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
	pointer_id = -1
	ship.reset_ship(Vector2(arena.x * 0.5, arena.y * 0.475))
	ship.scale = Vector2.ONE * 1.65
	interface.refresh()

func start_run(mode: String = "") -> void:
	clear_actors()
	encounter = selected_mode if mode.is_empty() else mode
	selected_mode = encounter
	loss_reason = "The next run starts with a clean slate."
	score = 0
	lives = 3
	elapsed = 0.0
	shot_timer = 0.22
	enemy_shot_timer = 2.4
	damage_flash = 0.0
	pointer_id = -1
	best_at_start = progress.best_for(encounter)
	state = State.PLAYING
	ship.reset_ship(Vector2(arena.x * 0.5, arena.y - bottom_inset - 152))
	if encounter != "fleet":
		boss = Boss.new()
		boss.game = self
		boss.kind = encounter
		add_child(boss)
		boss.step(0.0)
		interface.refresh()
		return
	for row in range(3):
		for column in range(5):
			var enemy = Enemy.new()
			enemy.formation_offset = Vector2((column - 2) * 76, row * 73)
			enemy.phase = column * 0.45 + row * 0.7
			enemy.tint = [Color("ffb86a"), Color("f1958d"), Color("baacf5")][row]
			add_child(enemy)
			enemies.append(enemy)
	update_enemies(0.0)
	interface.refresh()

func clear_actors() -> void:
	for actor in enemies + projectiles + asteroids:
		actor.queue_free()
	if is_instance_valid(boss):
		boss.queue_free()
		boss = null
	enemies.clear()
	projectiles.clear()
	asteroids.clear()
	particles.clear()

func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
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
		fire_player_shot()
		shot_timer += 0.19
	if is_instance_valid(boss):
		boss.step(delta)
		if state != State.PLAYING:
			return
		update_asteroids(delta)
	else:
		update_enemies(delta)
	if state != State.PLAYING:
		return
	enemy_shot_timer -= delta
	if enemy_shot_timer <= 0.0 and not enemies.is_empty():
		fire_enemy_shot()
		enemy_shot_timer += maxf(0.62, 1.2 - elapsed * 0.008)
	update_projectiles(delta)
	interface.queue_redraw()

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

func update_enemies(_delta: float) -> void:
	var spacing_scale := minf(1.0, (arena.x - 160.0) / 304.0)
	for enemy in enemies:
		enemy.position = Vector2(arena.x * 0.5 + enemy.formation_offset.x * spacing_scale + sin(elapsed * 0.8) * 38.0,
			top_inset + 183.0 + enemy.formation_offset.y + elapsed * 4.0 + sin(elapsed * 1.8 + enemy.phase) * 7.0)
		if enemy.position.y + Enemy.HIT_RADIUS >= ship.position.y - 30.0:
			finish_run(false)
			return

func fire_player_shot() -> void:
	var shot = Projectile.new()
	shot.position = ship.position + Vector2(0, -36)
	shot.previous_position = shot.position
	add_child(shot)
	projectiles.append(shot)
	sound.play_effect("shot")

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
			var absorbed := false
			for rock in asteroids.duplicate():
				if shot.intersects(rock.position, rock.radius):
					remove_projectile(shot)
					hit_asteroid(rock)
					absorbed = true
					break
			if absorbed:
				continue
			if is_instance_valid(boss) and shot.intersects(boss.body_position, Boss.HIT_RADIUS):
				remove_projectile(shot)
				boss.take_hit()
				if state != State.PLAYING:
					return
				continue
			for enemy in enemies.duplicate():
				if shot.intersects(enemy.position, Enemy.HIT_RADIUS):
					remove_projectile(shot)
					destroy_enemy(enemy)
					break
		if state != State.PLAYING:
			return
		if projectiles.has(shot) and (shot.position.y < -50 or shot.position.y > arena.y + 50):
			remove_projectile(shot)

func remove_projectile(shot: Node2D) -> void:
	projectiles.erase(shot)
	shot.queue_free()

func destroy_enemy(enemy: Node2D) -> void:
	if not enemies.has(enemy):
		return
	burst(enemy.position, enemy.tint, 18)
	enemies.erase(enemy)
	enemy.queue_free()
	add_score(POINTS_PER_ENEMY)
	sound.play_effect("burst")
	if enemies.is_empty():
		finish_run(true)

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

func hit_asteroid(rock: Node2D) -> void:
	rock.health -= 1
	rock.flash = 0.08
	if rock.health == 0:
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
		ship.visible = false
		finish_run(false)
		return
	ship.invulnerable = 1.6
	for shot in projectiles.duplicate():
		if shot.hostile:
			remove_projectile(shot)

func finish_run(won: bool) -> void:
	if state != State.PLAYING:
		return
	state = State.WON if won else State.LOST
	pointer_id = -1
	for shot in projectiles.duplicate():
		remove_projectile(shot)
	progress.save()
	if won:
		sound.play_effect("win")
	interface.refresh()

func pause_run() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	pointer_id = -1
	ship.target_x = ship.position.x
	sound.silence()
	progress.save()
	interface.refresh()

func resume_run() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	pointer_id = -1
	interface.refresh()

func toggle_sound() -> void:
	progress.sound_enabled = not progress.sound_enabled
	sound.enabled = progress.sound_enabled
	if not sound.enabled:
		sound.silence()
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
