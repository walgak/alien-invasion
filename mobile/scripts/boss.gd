extends Node2D
## A repeating firefight, random special attack, and return to the firefight.

const HIT_RADIUS := 54.0
const WARNING_SECONDS := 1.25
const ACTIVE_SECONDS := 4.0
const FIREFIGHT_MIN_SECONDS := 5.0
const FIREFIGHT_MAX_SECONDS := 9.0
const TAP_NEUTRALISE_SECONDS := 0.22
const EDGE_COLLISION_DISTANCE := 26.0
const RIFT_CANNON_SPEED := 1225.0
const ASTEROID_SIZES := [
	{"radius": 20.0, "health": 3},
	{"radius": 31.0, "health": 6},
	{"radius": 43.0, "health": 10}
]
var game: Node2D
var kind := "black"
var health := 60
var max_health := 60
var body_position := Vector2.ZERO
var phase := "firefight"
var phase_time := 0.0
var cooldown := 0.0
var shot_timer := 0.8
var asteroid_timer := 0.0
var well_position := Vector2.ZERO
var white_push_direction := Vector2.DOWN
var neutralise_time := 0.0
var cannon_active := false
var cannon_position := Vector2.ZERO
var cannon_previous_position := Vector2.ZERO
var cannon_velocity := Vector2.ZERO
var tap_flash := 0.0
var hit_flash := 0.0
var animation_time := 0.0

func _ready() -> void:
	return_to_firefight()

func step(delta: float) -> void:
	if health <= 0 or game.state != game.State.PLAYING:
		return
	animation_time += delta
	phase_time += delta
	tap_flash = maxf(0.0, tap_flash - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	body_position = Vector2(game.arena.x * 0.5 + sin(animation_time * 0.63) * 80, game.top_inset + 250)
	if phase == "firefight":
		cooldown -= delta
		shot_timer -= delta
		if cooldown <= 0:
			begin_special()
		elif shot_timer <= 0:
			fire_volley()
			shot_timer += 1.35
	elif phase == "warning":
		if kind == "white":
			# Track the nearest edge while forming, then keep the active hole fixed.
			position_white_hole()
			if cannon_active:
				aim_cannon_at_hole()
		if cannon_active:
			cannon_previous_position = cannon_position
			cannon_position += cannon_velocity * delta
			if Geometry2D.get_closest_point_to_segment(well_position, cannon_previous_position, cannon_position).distance_to(well_position) <= 18.0:
				activate_special()
		elif phase_time >= WARNING_SECONDS:
			activate_special()
	elif phase == "active" and kind == "asteroid":
		asteroid_timer -= delta
		if phase_time >= ACTIVE_SECONDS:
			phase = "clearing"
			phase_time = 0.0
		elif asteroid_timer <= 0:
			summon_asteroid()
			asteroid_timer += 0.82
	elif phase == "clearing":
		if game.asteroids.is_empty():
			return_to_firefight()
	elif phase == "active":
		var force_blocked := neutralise_time > 0.0
		neutralise_time = maxf(0.0, neutralise_time - delta)
		var previous_position: Vector2 = game.ship.position
		if not force_blocked:
			var direction: Vector2 = (well_position - previous_position).normalized()
			if kind == "white":
				direction = -direction
			var strength := (58.0 if kind == "black" else 88.0) + phase_time * 9.0
			game.ship.position += direction * strength * delta
		game.ship.target_x = game.ship.position.x
		var closest := Geometry2D.get_closest_point_to_segment(well_position, previous_position, game.ship.position)
		if kind == "black" and closest.distance_to(well_position) < 29:
			game.lose_ship("Caught in the black hole.")
			return
		if kind == "white" and touches_screen_edge():
			game.lose_ship("The white hole pushed you into the boundary.")
			return
		if phase_time >= ACTIVE_SECONDS:
			return_to_firefight()
	queue_redraw()

func fire_volley() -> void:
	var muzzle := body_position + Vector2(0, 45)
	var aim: Vector2 = (game.ship.position - muzzle).normalized()
	for angle in [-0.2, 0.0, 0.2]:
		game.spawn_hostile_shot(muzzle, aim.rotated(angle) * 245.0)

func return_to_firefight() -> void:
	phase = "firefight"
	phase_time = 0.0
	cooldown = game.rng.randf_range(FIREFIGHT_MIN_SECONDS, FIREFIGHT_MAX_SECONDS)
	shot_timer = 0.8
	neutralise_time = 0.0
	cannon_active = false
	game.pointer_id = -1
	game.ship.target_x = game.ship.position.x
	queue_redraw()

func begin_special() -> void:
	phase = "warning"
	phase_time = 0.0
	neutralise_time = 0.0
	if kind == "white":
		position_white_hole()
		launch_rift_cannon()
	elif kind == "black":
		var side := 1.0 if game.ship.position.x < game.arena.x * 0.5 else -1.0
		well_position = Vector2(clampf(game.ship.position.x + side * 130.0, 45, game.arena.x - 45), game.ship.position.y)
		launch_rift_cannon()
	else:
		cannon_active = false
	queue_redraw()

func activate_special() -> void:
	cannon_active = false
	phase = "active"
	phase_time = 0.0
	neutralise_time = 0.0
	asteroid_timer = 0.0
	game.sound.play_effect("rift" if kind != "asteroid" else "burst")
	if kind != "asteroid":
		game.burst(well_position, Color("b9f8ff") if kind == "white" else Color("baa3ff"), 34)
		# Steering changes to tapping, so clear bullets that can no longer be dodged.
		for shot in game.projectiles.duplicate():
			if shot.hostile:
				game.remove_projectile(shot)
		game.pointer_id = -1
		game.ship.target_x = game.ship.position.x

func launch_rift_cannon() -> void:
	cannon_active = true
	cannon_position = body_position + Vector2(0, 46)
	cannon_previous_position = cannon_position
	aim_cannon_at_hole()

func aim_cannon_at_hole() -> void:
	var aim := well_position - cannon_position
	cannon_velocity = aim.normalized() * RIFT_CANNON_SPEED if aim.length() > 0.001 else Vector2.ZERO

func summon_asteroid() -> void:
	var choice: Dictionary = ASTEROID_SIZES[game.rng.randi_range(0, ASTEROID_SIZES.size() - 1)]
	var radius: float = choice.radius
	var side: int = game.rng.randi_range(0, 2)
	var start := Vector2.ZERO
	if side == 0:
		start = Vector2(game.rng.randf_range(radius, game.arena.x - radius), -radius - 18.0)
	elif side == 1:
		start = Vector2(-radius - 18.0, game.rng.randf_range(game.top_inset + 145.0, game.arena.y - 260.0))
	else:
		start = Vector2(game.arena.x + radius + 18.0, game.rng.randf_range(game.top_inset + 145.0, game.arena.y - 260.0))
	var aim_offset := Vector2(game.rng.randf_range(-65, 65), 0)
	var velocity: Vector2 = Vector2.DOWN * game.rng.randf_range(225, 305)
	game.spawn_asteroid(start, velocity, radius, int(choice.health), body_position + Vector2(0, 42), aim_offset)
	game.sound.play_effect("rift")

func position_white_hole() -> void:
	var at: Vector2 = game.ship.position
	# Bottom wins an exact tie; otherwise select the true shortest distance.
	var distances := [game.arena.y - at.y, at.x, game.arena.x - at.x, at.y]
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
	var nearest := 0
	for i in range(1, distances.size()):
		if distances[i] < distances[nearest]:
			nearest = i
	white_push_direction = directions[nearest]
	well_position = at - white_push_direction * 130.0

func touches_screen_edge() -> bool:
	var at: Vector2 = game.ship.position
	return at.x <= EDGE_COLLISION_DISTANCE or at.x >= game.arena.x - EDGE_COLLISION_DISTANCE \
		or at.y <= EDGE_COLLISION_DISTANCE or at.y >= game.arena.y - EDGE_COLLISION_DISTANCE

func neutralisation() -> float:
	return 1.0 if neutralise_time > 0.0 else 0.0

func resist() -> void:
	if phase == "active" and kind != "asteroid":
		neutralise_time = TAP_NEUTRALISE_SECONDS
		tap_flash = 0.18
		queue_redraw()

func take_hit() -> void:
	# Called only by a friendly projectile collision in the game controller.
	if health <= 0 or game.state != game.State.PLAYING:
		return
	health -= 1
	hit_flash = 0.07
	if health == 0:
		game.burst(body_position, Color("ffca8d"), 60)
		game.add_score(1000)
		visible = false
		game.finish_run(true)

func holds_steering() -> bool:
	return phase == "active" and kind != "asteroid"

func _draw() -> void:
	var tint := Color("baa3ff") if kind == "black" else (Color("b9f8ff") if kind == "white" else Color("ffb86a"))
	draw_set_transform(body_position)
	draw_circle(Vector2.ZERO, 74, Color(tint, 0.035))
	draw_arc(Vector2.ZERO, 64, animation_time * 0.3, animation_time * 0.3 + TAU * 0.85, 60, Color(tint, 0.35), 2, true)
	for i in range(6):
		var angle := i * TAU / 6 + animation_time * 0.12
		var outer := Vector2.from_angle(angle) * 55
		var wing := PackedVector2Array([outer + Vector2.from_angle(angle) * 10, Vector2.from_angle(angle - 0.3) * 33, Vector2.from_angle(angle + 0.3) * 33])
		draw_colored_polygon(wing, tint.darkened(0.3))
	draw_circle(Vector2.ZERO, 36, Color("202d43"))
	draw_arc(Vector2.ZERO, 36, 0, TAU, 60, tint, 2, true)
	draw_circle(Vector2.ZERO, 23, Color("f0fcff") if kind == "white" else Color("050714"))
	if kind == "black":
		draw_arc(Vector2.ZERO, 26, 0, TAU, 48, Color("c0a4ff"), 3, true)
	elif kind == "asteroid":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-18), Vector2(20,10),Vector2(-20,10)]), tint)
		draw_circle(Vector2(0, 3), 5, Color("33283c"))
	if hit_flash > 0:
		draw_circle(Vector2.ZERO, 38, Color(1, 1, 1, 0.55))
	draw_set_transform(Vector2.ZERO)
	if phase == "firefight" or kind == "asteroid":
		return
	var active := phase == "active"
	var radius := 31.0 if active else 25.0
	if cannon_active:
		draw_rift_cannon(tint)
	draw_space_folds(well_position, radius, tint, active)
	if active:
		if kind == "white":
			for layer in range(8, 0, -1):
				var fraction := float(layer) / 8.0
				draw_circle(well_position, radius * fraction, Color("a5d9ef").lerp(Color("ffffff"), 1.0 - fraction))
		else:
			draw_circle(well_position, radius, Color("01030a"))
		draw_arc(well_position, radius, 0, TAU, 56, Color(tint, 0.6), 2, true)
		draw_arc(well_position + Vector2(-1, -1), radius + 1.5, -2.8, -0.3, 40, Color("e6ecff"), 1.4, true)
	else:
		draw_arc(well_position, radius, animation_time, animation_time + PI * 1.65, 48, tint, 2, true)
		draw_line(well_position - Vector2(9,0), well_position + Vector2(9,0), tint, 1, true)
		draw_line(well_position - Vector2(0,9), well_position + Vector2(0,9), tint, 1, true)
	if tap_flash > 0:
		draw_arc(game.ship.position, 42 + (0.18 - tap_flash) * 110, 0, TAU, 56, Color("6cf4d4"), 2, true)

func draw_space_folds(center: Vector2, core_radius: float, tint: Color, active: bool) -> void:
	# The background shader bends the sky. These sparse glints sit on its ridges.
	var direction := 1.0 if kind == "white" else -1.0
	var spacing := TAU / 0.255
	var offset := fposmod(animation_time * direction * 5.5 / 0.255, spacing)
	var outer := 164.0 if active else 112.0
	for i in range(6):
		var ring_radius := core_radius + offset + i * spacing
		if ring_radius > outer:
			break
		var envelope := (1.0 - smoothstep(outer * 0.66, outer, ring_radius)) * smoothstep(core_radius, core_radius + 12.0, ring_radius)
		var points := PackedVector2Array()
		for n in range(33):
			var angle := -2.9 + float(n) / 32.0 * 1.7
			points.append(center + Vector2(cos(angle), sin(angle) * 0.83) * ring_radius)
		draw_polyline(points, Color(tint, envelope * (0.17 if active else 0.05)), 1.0, true)

func draw_rift_cannon(tint: Color) -> void:
	var trail := PackedVector2Array()
	var direction := cannon_velocity.normalized()
	var side := direction.orthogonal()
	for i in range(18):
		var t := float(i) / 17.0
		var base := cannon_position - direction * t * 86.0
		var wave := side * sin(animation_time * 24.0 + t * 16.0) * (10.0 * (1.0 - t))
		trail.append(base + wave)
	draw_polyline(trail, Color(tint, 0.24), 7.0, true)
	draw_polyline(trail, Color(tint, 0.55), 2.4, true)
	draw_circle(cannon_position, 9.5, Color("f5ffff") if kind == "white" else Color("f0e5ff"))
	draw_circle(cannon_position, 17.0, Color(tint, 0.25))
