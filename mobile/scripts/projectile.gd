extends Node2D

var velocity := Vector2(0, -850)
var hostile := false
var previous_position := Vector2.ZERO
var kind := "bullet"
var continuous := false
var damage := 1
var piercing := false
var hit_ids: Dictionary = {}
var blast_radius := 0.0
var expired := false
var age := 0.0
var lifetime := 8.0
var beam_start := Vector2.ZERO
var homing_target: Node2D
var beam_segments: Array[Vector2] = []
var absorbed := false
var contact_point := Vector2.ZERO
var visual_brightness := 1.0

## Set the beam endpoints for rendering and segment collision; game.gd owns continuous exposure timing.
func setup_laser(from: Vector2, to: Vector2) -> void:
	kind = "laser"
	piercing = true
	damage = 2
	lifetime = 0.13
	beam_start = from
	previous_position = from
	position = to
	velocity = Vector2.ZERO

## Advance this actor by delta seconds and retain its previous position for swept collision checks.
func advance(delta: float) -> void:
	age += delta
	expired = age >= lifetime
	if kind == "laser":
		# Keep the entire beam available to swept collision for its short pulse.
		previous_position = beam_start
	else:
		previous_position = position
		position += velocity * delta
	if kind != "bullet":
		queue_redraw()

## Test the entire traveled segment against a target circle to prevent fast shots tunneling between frames.
func intersects(center: Vector2, radius: float) -> bool:
	if kind == "laser" and not beam_segments.is_empty():
		for i in range(0, beam_segments.size(), 2):
			if Geometry2D.get_closest_point_to_segment(center, beam_segments[i], beam_segments[i + 1]).distance_to(center) <= radius + 5.0:
				return true
		return false
	# Swept collision catches targets even when a shot crosses them in one frame.
	var closest := Geometry2D.get_closest_point_to_segment(center, previous_position, position)
	var collision_radius := radius + (5.0 if kind == "laser" else 0.0)
	return closest.distance_squared_to(center) <= collision_radius * collision_radius

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	if kind == "doom":
		for layer in range(5, 0, -1):
			draw_circle(Vector2.ZERO, 11.0 + layer * 2.0, Color(0.63, 0.3, 1.0, 0.065))
		draw_circle(Vector2.ZERO, 12, Color("03020c"))
		for fleck in range(9):
			var angle := float(fleck) * TAU / 9.0 + age * 4.0
			draw_circle(Vector2.from_angle(angle) * 14.0, 1.4, Color("c59aff"))
		return
	if kind == "laser":
		draw_laser()
		return
	if kind == "rocket":
		draw_rocket()
		return
	var tint := Color("ff816f") if hostile else Color("63cfff")
	var enhanced := kind == "plasma"
	var forward := velocity.normalized()
	var side := forward.orthogonal()
	var length := 13.0 if hostile else 20.0
	var width := 5.0 if enhanced else 3.1
	# Three nested filled droplets replace the old straight strokes. Keeping a
	# small fixed draw count matters when triple guns fill the screen with shots.
	for layer in range(3, 0, -1):
		var breadth := width * (1.0 + float(layer - 1) * 0.65)
		var vertices := PackedVector2Array([
			forward * width,
			forward * (width * 0.4) + side * breadth,
			-forward * (length * 0.45) + side * breadth * 0.48,
			-forward * length,
			-forward * (length * 0.45) - side * breadth * 0.48,
			forward * (width * 0.4) - side * breadth
		])
		draw_colored_polygon(vertices, Color(tint, 0.9 if layer == 1 else 0.075))
	draw_circle(Vector2(-0.35, -0.35), width * 0.62, Color("e9faff"))

## Each bent optical segment carries a filled fluid ribbon with traveling bulges.
## The short individual polygons stay monotonic even at sharp reflections, which
## avoids triangulation stalls from one self-intersecting screen-sized polygon.
func draw_laser() -> void:
	var brightness := visual_brightness
	var segments := beam_segments
	if segments.is_empty():
		segments = [beam_start, position]
	var traveled := 0.0
	for index in range(0, segments.size(), 2):
		var a: Vector2 = segments[index] - position
		var b: Vector2 = segments[index + 1] - position
		var length := a.distance_to(b)
		if length <= 0.01:
			continue
		var normal := (b - a).normalized().orthogonal()
		var samples := clampi(ceili(length / 18.0), 2, 32)
		for layer in range(3):
			var polygon := PackedVector2Array()
			var reverse := PackedVector2Array()
			for sample in range(samples + 1):
				var t := float(sample) / float(samples)
				var along := traveled + length * t
				var wave := sin(along * 0.09 - age * 17.0)
				var pulse := 0.8 + 0.2 * sin(along * 0.14 + age * 23.0)
				var sway := wave * 2.1 * sin(t * PI)
				var half_width: float = [10.0, 3.6, 1.25][layer] * pulse
				var center := a.lerp(b, t) + normal * sway
				polygon.append(center + normal * half_width)
				reverse.append(center - normal * half_width)
			reverse.reverse()
			polygon.append_array(reverse)
			var tint: Color = [Color(0.2, 0.56, 1.0, 0.12), Color(0.35, 0.77, 1.0, 0.65), Color(0.88, 0.97, 1.0, 0.96)][layer]
			tint.a *= brightness
			draw_colored_polygon(polygon, tint)
		traveled += length
	if absorbed:
		var at := contact_point - position
		var pulse := 0.85 + sin(age * 31.0) * 0.15
		for layer in range(4, 0, -1):
			draw_circle(at, float(layer) * 6.0 * pulse, Color(0.35, 0.8, 1.0, 0.075 * float(5 - layer) * brightness))
		draw_circle(at, 4.0, Color(0.92, 1.0, 1.0, brightness))
		for spark in range(8):
			var phase := fmod(age * 2.0 + float(spark) / 8.0, 1.0)
			var direction := Vector2.from_angle(float(spark) * 2.39996)
			draw_circle(at + direction * (5.0 + phase * 22.0), 2.5 * (1.0 - phase), Color(0.65, 0.9, 1.0, (1.0 - phase) * brightness))

## Draw the rocket body and animated exhaust around its current velocity direction.
func draw_rocket() -> void:
	var forward := velocity.normalized()
	var side := Vector2(-forward.y, forward.x)
	var flame_length := 22.0 + sin(age * 70.0) * 5.0
	for bead in range(8, -1, -1):
		var fraction := float(bead) / 8.0
		var at := -forward * (7.0 + flame_length * fraction)
		var radius := (4.0 + sin(age * 60.0 + bead) * 0.6) * (1.0 - fraction * 0.7)
		draw_circle(at, radius * 2.4, Color(0.24, 0.64, 1.0, 0.065 * (1.0 - fraction)))
		draw_circle(at, radius, Color(0.45, 0.83, 1.0, 1.0 - fraction * 0.8))
		draw_circle(at, radius * 0.45, Color(0.92, 0.98, 1.0, 1.0 - fraction))
	# Painted metal facets suggest a cylinder without adding 3D meshes or lights.
	# Keep the reflection on the screen's upper-left side even as a rocket turns.
	var lit_side := side if side.dot(Vector2(-0.6, -0.8)) >= 0.0 else -side
	for wing in [-1.0, 1.0]:
		var fin := PackedVector2Array([
			side * wing * 3.0 + forward * 1.0,
			side * wing * 8.0 - forward * 9.0,
			side * wing * 2.0 - forward * 6.0
		])
		draw_colored_polygon(fin, Color("718cad") if side.dot(lit_side) * wing > 0.0 else Color("354966"))
		draw_line(fin[0], fin[1], Color("c0d9ed"), 0.9, true)
	var nose := forward * 13.0
	var base := -forward * 6.0
	draw_colored_polygon(PackedVector2Array([
		nose, lit_side * 4.5 + forward * 3.0, base + lit_side * 3.0, base
	]), Color("c8e0ef"))
	draw_colored_polygon(PackedVector2Array([
		nose, -lit_side * 4.5 + forward * 3.0, base - lit_side * 3.0, base
	]), Color("5b7696"))
	draw_line(nose - forward * 3.0, base + lit_side * 0.7, Color("f0faff"), 1.3, true)
	draw_line(forward * 3.0 + lit_side * 2.0, -forward * 3.5 + lit_side * 1.8, Color("ffac73"), 1.7, true)
	draw_line(base - lit_side * 3.0, base + lit_side * 3.0, Color("263447"), 1.5, true)
