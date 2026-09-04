extends Node2D
## A repeating firefight, random special attack, and return to the firefight.

const HIT_RADIUS := 54.0
const WARNING_SECONDS := 1.25
const ACTIVE_SECONDS := 4.0
const FIREFIGHT_MIN_SECONDS := 5.0
const FIREFIGHT_MAX_SECONDS := 9.0
const TAP_NEUTRALISE_SECONDS := 0.22
const EDGE_COLLISION_DISTANCE := 26.0
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
		if phase_time >= WARNING_SECONDS:
			phase = "active"
			phase_time = 0.0
			neutralise_time = 0.0
			asteroid_timer = 0.0
			if kind != "asteroid":
				# Steering changes to tapping, so clear bullets that can no longer be dodged.
				for shot in game.projectiles.duplicate():
					if shot.hostile:
						game.remove_projectile(shot)
				game.pointer_id = -1
				game.ship.target_x = game.ship.position.x
	elif phase == "active" and kind == "asteroid":
		asteroid_timer -= delta
		if phase_time >= ACTIVE_SECONDS:
			phase = "clearing"
			phase_time = 0.0
		elif asteroid_timer <= 0:
			var target := Vector2(clampf(game.ship.position.x + game.rng.randf_range(-120, 120), 35, game.arena.x - 35), game.ship.position.y)
			game.spawn_asteroid(body_position + Vector2(0, 42), (target - body_position).normalized() * game.rng.randf_range(195, 275), game.rng.randf_range(20, 32))
			asteroid_timer += 0.65
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
	game.pointer_id = -1
	game.ship.target_x = game.ship.position.x
	queue_redraw()

func begin_special() -> void:
	phase = "warning"
	phase_time = 0.0
	neutralise_time = 0.0
	if kind == "white":
		position_white_hole()
	elif kind == "black":
		var side := 1.0 if game.ship.position.x < game.arena.x * 0.5 else -1.0
		well_position = Vector2(clampf(game.ship.position.x + side * 130.0, 45, game.arena.x - 45), game.ship.position.y)
	queue_redraw()

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
	for i in range(5):
		var ring := fmod(animation_time * (35 if kind == "white" else -35) + i * 15, 75)
		if ring < 0:
			ring += 75
		draw_arc(well_position, radius + ring, 0, TAU, 56, Color(tint, (1.0 - ring / 75.0) * (0.4 if active else 0.15)), 1.2, true)
	if active:
		draw_circle(well_position, radius, Color("f2fdff") if kind == "white" else Color("01030a"))
		draw_arc(well_position, radius, 0, TAU, 56, tint, 3, true)
	else:
		draw_arc(well_position, radius, animation_time, animation_time + PI * 1.65, 48, tint, 2, true)
		draw_line(well_position - Vector2(9,0), well_position + Vector2(9,0), tint, 1, true)
		draw_line(well_position - Vector2(0,9), well_position + Vector2(0,9), tint, 1, true)
	if tap_flash > 0:
		draw_arc(game.ship.position, 42 + (0.18 - tap_flash) * 110, 0, TAU, 56, Color("6cf4d4"), 2, true)
