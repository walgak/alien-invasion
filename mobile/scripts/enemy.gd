extends Node2D

const HIT_RADIUS := 24.0
var formation_offset := Vector2.ZERO
var phase := 0.0
var tint := Color("ffb86a")
const RELEASE_FADE_SECONDS := 0.24
var velocity := Vector2(0, 125)
var previous_position := Vector2.ZERO
var age := 0.0
var shot_timer := 2.0
var summoned := false
var health := 1
var zigzag := false
var motion_phase := "flight"
var fold_origin := Vector2.ZERO
var fold_life := 0.0
var pull_start := Vector2.ZERO
var pull_offset := Vector2.ZERO
var phase_time := 0.0
var launch_speed := 220.0

func begin_pull(origin: Vector2) -> void:
	fold_origin = origin
	pull_start = position
	pull_offset = (position - origin).normalized() * 105.0
	launch_speed = velocity.length()
	velocity = Vector2.ZERO
	motion_phase = "pull"
	fold_life = RELEASE_FADE_SECONDS

func advance(delta: float, target: Vector2 = Vector2.ZERO) -> void:
	previous_position = position
	var old_age := age
	age += delta
	var remaining := delta
	if motion_phase == "pull":
		var step := minf(remaining, 0.7 - phase_time)
		phase_time += step
		remaining -= step
		position = pull_start.lerp(fold_origin + pull_offset, smoothstep(0.0, 0.7, phase_time))
		if phase_time >= 0.7:
			motion_phase = "windup"
			phase_time = 0.0
	if motion_phase == "windup":
		var step := minf(remaining, 0.22 - phase_time)
		phase_time += step
		remaining -= step
		var direction := 1.0 if pull_offset.x < 0.0 else -1.0
		position = fold_origin + pull_offset.rotated(direction * smoothstep(0.0, 0.22, phase_time) * 0.65)
		if phase_time >= 0.22:
			motion_phase = "flight"
			velocity = (target - position).normalized() * launch_speed
	if motion_phase == "flight":
		position += velocity * remaining
		if not summoned:
			if zigzag:
				# Triangle wave gives clear alternating diagonal legs.
				position.x += (asin(sin(age * 2.8 + phase)) - asin(sin(old_age * 2.8 + phase))) * 60.0
			else:
				position.x += (sin(age * 1.8 + phase) - sin(old_age * 1.8 + phase)) * 22.0
		fold_life = maxf(0.0, fold_life - remaining)
	queue_redraw()

func _draw() -> void:
	if fold_life > 0.0:
		var anchor := to_local(fold_origin)
		var side := anchor.orthogonal().normalized()
		for lane in range(5):
			var points := PackedVector2Array()
			for i in range(25):
				var t := float(i) / 24.0
				points.append(anchor.lerp(Vector2((lane - 2) * 6, 0), t) + side * sin(t * TAU * 2 + age * 5 + lane) * 3.0 * sin(t * PI))
			draw_polyline(points, Color("91f5da", fold_life / RELEASE_FADE_SECONDS * 0.32), 1.2, true)
	draw_circle(Vector2.ZERO, 29, Color(tint, 0.045))
	draw_colored_polygon(PackedVector2Array([Vector2(-27,-9),Vector2(-14,-3),Vector2(-8,12),Vector2(-22,19),Vector2(-19,4),Vector2(-29,2)]), tint.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(27,-9),Vector2(14,-3),Vector2(8,12),Vector2(22,19),Vector2(19,4),Vector2(29,2)]), tint.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-19),Vector2(17,-9),Vector2(13,9),Vector2(0,18),Vector2(-13,9),Vector2(-17,-9)]), Color("303247"))
	draw_polyline(PackedVector2Array([Vector2(-13,9),Vector2(-17,-9),Vector2(0,-19),Vector2(17,-9),Vector2(13,9)]), tint, 2, true)
	draw_line(Vector2(-9,-3),Vector2(-3,1),tint,3,true)
	draw_line(Vector2(9,-3),Vector2(3,1),tint,3,true)
	draw_circle(Vector2(0,11),2,Color("fff3d7"))
