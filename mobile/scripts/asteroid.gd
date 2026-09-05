extends Node2D

const PULL_SECONDS := 0.7
const WINDUP_SECONDS := 0.22
const RELEASE_FADE_SECONDS := 0.24

var radius := 24.0
var health := 2
var velocity := Vector2(0, 240)
var previous_position := Vector2.ZERO
var spin := 1.0
var outline := PackedVector2Array()
var flash := 0.0
var max_health := 2
var fold_origin := Vector2.ZERO
var fold_life := 0.0
var motion_phase := "flight"
var phase_time := 0.0
var pull_start := Vector2.ZERO
var pull_offset := Vector2.ZERO
var aim_offset := Vector2.ZERO
var launch_speed := 260.0
var swing_direction := 1.0

func _ready() -> void:
	for i in range(9):
		outline.append(Vector2.from_angle(i * TAU / 9.0) * radius * (0.8 if i % 3 == 0 else 1.0))
	max_health = max(health, 1)

func begin_pull(origin: Vector2, target_offset: Vector2) -> void:
	fold_origin = origin
	pull_start = position
	pull_offset = (position - origin).normalized() * (85.0 + radius)
	swing_direction = 1.0 if pull_offset.x < 0.0 else -1.0
	aim_offset = target_offset
	launch_speed = velocity.length()
	velocity = Vector2.ZERO
	motion_phase = "pull"
	phase_time = 0.0
	fold_life = RELEASE_FADE_SECONDS

func advance(delta: float, target: Vector2 = Vector2.ZERO) -> void:
	previous_position = position
	var remaining := delta
	if motion_phase == "pull":
		var step := minf(remaining, PULL_SECONDS - phase_time)
		phase_time += step
		remaining -= step
		position = pull_start.lerp(fold_origin + pull_offset, smoothstep(0.0, PULL_SECONDS, phase_time))
		if phase_time >= PULL_SECONDS:
			motion_phase = "windup"
			phase_time = 0.0
	if motion_phase == "windup":
		var step := minf(remaining, WINDUP_SECONDS - phase_time)
		phase_time += step
		remaining -= step
		var swing := swing_direction * smoothstep(0.0, WINDUP_SECONDS, phase_time) * 0.65
		position = fold_origin + pull_offset.rotated(swing)
		if phase_time >= WINDUP_SECONDS:
			motion_phase = "flight"
			velocity = (target + aim_offset - position).normalized() * launch_speed
	if motion_phase == "flight":
		position += velocity * remaining
		fold_life = maxf(0.0, fold_life - remaining)
	rotation += spin * delta
	flash = maxf(0, flash - delta)
	queue_redraw()

func _draw() -> void:
	draw_fold_lines()
	draw_colored_polygon(outline, Color("fff0d5") if flash > 0 else Color("495065"))
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color("caa48c"), 1.5, true)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.25), radius * 0.25, Color("2d3449"))
	draw_circle(Vector2(radius * 0.28, radius * 0.1), radius * 0.16, Color("333c50"))
	var damage_ratio := 1.0 - float(health) / float(max_health)
	if damage_ratio > 0.28:
		draw_polyline(PackedVector2Array([Vector2(-radius, 0), Vector2(0, -5), Vector2(5, 9), Vector2(radius, radius * 0.4)]), Color("ffb86a"), 2, true)
	if damage_ratio > 0.62:
		draw_polyline(PackedVector2Array([Vector2(-radius * 0.25, -radius), Vector2(-radius * 0.05, -radius * 0.2), Vector2(radius * 0.32, radius * 0.1)]), Color("ffd19d"), 1.6, true)

func draw_fold_lines() -> void:
	if fold_life <= 0:
		return
	var alpha := fold_life / RELEASE_FADE_SECONDS
	var start := to_local(fold_origin)
	var side := start.orthogonal().normalized() if start.length() > 0.001 else Vector2.RIGHT
	for lane in range(7):
		var points := PackedVector2Array()
		var lane_offset := float(lane - 3) * radius * 0.18
		var boss_hook := side * lane_offset * 0.3
		var rock_hook := Vector2.from_angle(lane * TAU / 7.0) * radius * 0.72
		for i in range(28):
			var t := float(i) / 27.0
			var base := (start + boss_hook).lerp(rock_hook, t)
			var wave := side * sin(t * TAU * 2.8 + lane * 0.9 + rotation) * radius * 0.11 * sin(t * PI)
			points.append(base + wave)
		var line_alpha := alpha * (0.5 if lane == 3 else 0.25)
		draw_polyline(points, Color("b9f8ff", line_alpha), 1.8 if lane == 3 else 1.0, true)
	draw_circle(start, 5.0, Color("b9f8ff", alpha * 0.22))
