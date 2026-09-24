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
## Fragments inherit this material; empty means choose the initial size's ore.
var visual_kind := ""
var visual_seed := 1
var plates: Array[PackedVector2Array] = []
## Set only when the player actually changes this rock's momentum. Ambient and
## boss-thrown asteroids cannot damage their own fleet without that intervention.
var player_deflected := false

## Godot calls this once after the node joins the scene; initialize child nodes and cached resources here.
func _ready() -> void:
	if visual_kind.is_empty():
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
	build_plates()

## Cache irregular stone plates once, using clipped Voronoi cells. Unlike a fan
## of triangles, these interlocking surfaces read as a broken rounded shell.
func build_plates() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = visual_seed
	var sites: Array[Vector2] = [Vector2(-0.08, 0.06) * radius]
	for ring in [0, 1]:
		var count := 5 if ring == 0 else 9
		for i in range(count):
			var angle: float = TAU * float(i) / count + ring * 0.31 + random.randf_range(-0.12, 0.12)
			sites.append(Vector2.from_angle(angle) * radius * (0.37 if ring == 0 else 0.77) * random.randf_range(0.88, 1.1))
	for site in sites:
		var cell := outline.duplicate()
		for other in sites:
			if site == other:
				continue
			var normal := other - site
			var limit := (other.length_squared() - site.length_squared()) * 0.5
			cell = clip_plate(cell, normal, limit)
			if cell.size() < 3:
				break
		if cell.size() < 3:
			continue
		var center := Vector2.ZERO
		for vertex in cell:
			center += vertex
		center /= float(cell.size())
		for i in range(cell.size()):
			cell[i] = center.lerp(cell[i], 0.94)
		plates.append(cell)

## Clip a cell to the side nearest its seed; geometry never changes during play.
func clip_plate(points: PackedVector2Array, normal: Vector2, limit: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty():
		return result
	var previous := points[points.size() - 1]
	var previous_distance := previous.dot(normal) - limit
	for current in points:
		var distance := current.dot(normal) - limit
		if (distance <= 0.0) != (previous_distance <= 0.0):
			result.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance <= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result

## Sphere-like normals simulate rounded lighting and mineral reflections entirely
## in the 2D canvas. World-space light stays fixed while the stone tumbles.
func surface_color(point: Vector2, variation: float) -> Color:
	var xy := point / radius * 0.94
	var normal := Vector3(xy.x, xy.y, sqrt(maxf(0.04, 1.0 - xy.length_squared()))).normalized()
	var light_xy := Vector2(-0.45, -0.58).rotated(-rotation)
	var light := Vector3(light_xy.x, light_xy.y, 0.72).normalized()
	var diffuse := maxf(0.0, normal.dot(light))
	var half_light := (light + Vector3.FORWARD * -1.0).normalized()
	var specular := pow(maxf(0.0, normal.dot(half_light)), 22.0) * (0.72 if visual_kind == "ice" else 0.30)
	var base := Color("2785b0") if visual_kind == "ice" else Color("626779")
	var brightness := 0.24 + diffuse * 0.90 + variation
	return Color(minf(1.0, base.r * brightness + specular * 0.80),
		minf(1.0, base.g * brightness + specular * 0.92), minf(1.0, base.b * brightness + specular), 1.0)

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
	# Boss-connected pulls are rendered by the refractive space-fold layer.
	var glow := Color("ff641f") if visual_kind != "ice" else Color("38dfff")
	draw_circle(Vector2.ZERO, radius * 1.13, Color(glow,0.07))
	draw_colored_polygon(outline, Color("fff0d5") if flash > 0 else (Color("0d1a35") if visual_kind == "ice" else Color("6c2b17")))
	if flash <= 0:
		var light := Vector2(-0.72, -0.68).rotated(-rotation)
		for i in range(plates.size()):
			var plate := plates[i]
			var colors := PackedColorArray()
			for vertex in plate:
				colors.append(surface_color(vertex, sin(float(i) * 3.4) * 0.09))
			draw_polygon(plate, colors)
			# Lit bevels and dark opposing edges give every plate visible thickness.
			for edge in range(plate.size()):
				var a := plate[edge]
				var b := plate[(edge + 1) % plate.size()]
				var outward := Vector2((b-a).y, -(b-a).x).normalized()
				var facing := outward.dot(light)
				var tint := Color(0.76,0.93,1.0,0.18 + maxf(0.0,facing)*0.48) if facing > 0.0 else Color(0.02,0.02,0.06,0.62)
				draw_line(a,b,tint,0.8,true)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color("65c5dc") if visual_kind == "ice" else Color("8c8991"), 1.0, true)
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
