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
var visual_kind := "magma"

## Godot calls this once after the node joins the scene; initialize child nodes and cached resources here.
func _ready() -> void:
	visual_kind = "ash" if radius < 26.0 else ("magma" if radius < 37.0 else "ice")
	var point_count := 11 if visual_kind == "ash" else 13
	for i in range(point_count):
		var angle := i * TAU / float(point_count)
		var variation: float = 0.76 + 0.20 * absf(sin(float(i) * 2.17 + radius * 0.13))
		# Small ash ore is sharper; the larger mineral bodies remain round enough
		# that their painted edge still agrees with the circular collision radius.
		if visual_kind == "ash" and i % 3 == 1:
			variation = 1.0
		outline.append(Vector2.from_angle(angle) * radius * variation)
	max_health = max(health, 1)

## Capture the offscreen starting point and boss anchor, then enter the pull/windup/throw state machine.
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

## Advance this actor by delta seconds and retain its previous position for swept collision checks.
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

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	draw_fold_lines()
	var glow := Color("ff641f") if visual_kind != "ice" else Color("38dfff")
	draw_circle(Vector2.ZERO, radius * 1.13, Color(glow,0.07))
	draw_colored_polygon(outline, Color("fff0d5") if flash > 0 else (Color("162947") if visual_kind == "ice" else Color("211d25")))
	if flash <= 0:
		var light := Vector2(-0.72, -0.68).rotated(-rotation)
		for i in range(outline.size()):
			var next := (i + 1) % outline.size()
			var facing := (outline[i] + outline[next]).normalized().dot(light)
			var center := Vector2(sin(float(i)*2.3),cos(float(i)*1.7))*radius*0.10
			var face := PackedVector2Array([center, outline[i], outline[next]])
			var shadow := Color("111a31") if visual_kind == "ice" else Color("17151c")
			var lit := Color("35cbe5") if visual_kind == "ice" else Color("65545a")
			draw_colored_polygon(face, shadow.lerp(lit, clampf((facing + 1.0) * 0.42,0.0,1.0)))
			if i % 2 == 0:
				draw_line(center.lerp(outline[i],0.3),outline[i],Color(glow,0.22),1.0,true)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color("63e9ff") if visual_kind == "ice" else Color("8b716a"), 1.5, true)
	if visual_kind == "ice":
		draw_ice_craters()
	else:
		draw_molten_seams(glow)
	var damage_ratio := 1.0 - float(health) / float(max_health)
	if damage_ratio > 0.28:
		var damage_path := PackedVector2Array([Vector2(-radius, 0), Vector2(0, -5), Vector2(5, 9), Vector2(radius, radius * 0.4)])
		draw_polyline(damage_path,Color(glow,0.34),5.5,true)
		draw_polyline(damage_path,Color("c9fbff") if visual_kind == "ice" else Color("ffd09a"),1.4,true)
	if damage_ratio > 0.62:
		draw_polyline(PackedVector2Array([Vector2(-radius * 0.25, -radius), Vector2(-radius * 0.05, -radius * 0.2), Vector2(radius * 0.32, radius * 0.1)]), Color("fff0cc"), 2.0, true)

## Permanent branching heat fissures make the dark ore readable before it is hit.
func draw_molten_seams(glow: Color) -> void:
	var paths := [
		PackedVector2Array([Vector2(-0.72,-0.34),Vector2(-0.22,-0.12),Vector2(0.02,0.18),Vector2(0.55,0.48)]),
		PackedVector2Array([Vector2(0.02,0.18),Vector2(0.28,-0.06),Vector2(0.63,-0.30)]),
		PackedVector2Array([Vector2(-0.22,-0.12),Vector2(-0.05,-0.55),Vector2(0.18,-0.78)])
	]
	for path in paths:
		var scaled := PackedVector2Array()
		for point in path:
			scaled.append(point*radius)
		draw_polyline(scaled,Color(glow,0.20),5.5,true)
		draw_polyline(scaled,Color("ffb12b"),1.4,true)
	for ember in [Vector2(-0.48,0.47),Vector2(0.45,-0.58),Vector2(0.66,0.18)]:
		draw_circle(ember*radius,1.2,Color("ffd35c"))

## Cold mineral bodies use layered crater bowls, cyan rims, and violet shadows.
func draw_ice_craters() -> void:
	for crater in [Vector3(-0.31,-0.27,0.24),Vector3(0.30,0.12,0.16),Vector3(0.08,-0.46,0.11),Vector3(-0.23,0.42,0.12)]:
		var at: Vector2 = Vector2(float(crater.x),float(crater.y))*radius
		var crater_radius: float = float(crater.z)*radius
		draw_circle(at,crater_radius,Color("101c3d"))
		draw_arc(at,crater_radius,0.15-rotation,2.5-rotation,20,Color(0.35,0.94,1.0,0.72),1.5,true)
		draw_arc(at,crater_radius*0.72,PI-rotation,TAU-rotation,16,Color(0.15,0.04,0.35,0.7),1.2,true)

## Draw boss-to-rock tethers in the rock's rotated local space; fade them after release.
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
