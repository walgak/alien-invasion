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
		draw_circle(Vector2.ZERO, 12, Color("03020c"))
		draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color("b894ff"), 4, true)
		return
	if kind == "laser":
		draw_laser()
		return
	if kind == "rocket":
		draw_rocket()
		return
	var tint := Color("ff816f") if hostile else Color("63f2d2")
	var tail := -velocity.normalized() * (13.0 if hostile else 20.0)
	draw_line(-tail * 0.3, tail, Color(tint, 0.09), 12, true)
	draw_line(-tail * 0.3, tail, Color(tint, 0.3), 5, true)
	draw_line(Vector2.ZERO, tail * 0.7, tint, 2.5, true)
	draw_circle(Vector2.ZERO, 2.5, Color("e8fff6"))

## Render the beam's glow and core; continuous beams remain bright instead of fading like short pulses.
func draw_laser() -> void:
	var brightness := visual_brightness
	var segments := beam_segments
	if segments.is_empty():
		segments = [beam_start, position]
	# Three liquid filaments follow the same collision path. Their small visual
	# sway never changes damage, and endpoints stay pinned to muzzle/impact.
	for lane in range(3):
		var points := PackedVector2Array()
		for i in range(0, segments.size(), 2):
			var a: Vector2 = segments[i]-position
			var b: Vector2 = segments[i+1]-position
			var normal := (b-a).normalized().orthogonal()
			for j in range(5):
				var t := float(j)/4.0
				var along := float(i/2)*24.0+(b-a).length()*t
				var envelope := 1.0
				if i == 0:
					envelope *= smoothstep(0,1,t)
				if i == segments.size()-2:
					envelope *= 1.0-smoothstep(0,1,t)
				var sway := (sin(along*0.07-age*12.0+lane*2.1)*2.0 + sin(along*0.16+age*17)*0.7)*envelope
				points.append(a.lerp(b,t)+normal*sway)
		if lane == 0:
			draw_polyline(points,Color(0.25,0.6,1,0.08 * brightness),24,true)
			draw_polyline(points,Color(0.3,0.75,1,0.22 * brightness),10,true)
		draw_polyline(points,Color(0.55+lane*0.18,0.85+lane*0.06,1,0.9 * brightness),2.2-float(lane)*0.5,true)
	if absorbed:
		var at := contact_point-position
		var pulse := 0.85+sin(age*31)*0.15
		for layer in range(4,0,-1):
			draw_circle(at,float(layer)*6*pulse,Color(0.35,0.8,1,0.075*float(5-layer) * brightness))
		draw_circle(at,4.0,Color(0.92, 1.0, 1.0, brightness))
		for spark in range(6):
			var direction := Vector2.from_angle(float(spark)*TAU/6.0+age*2)
			draw_line(at+direction*6,at+direction*(12+sin(age*25+spark)*4),Color(0.65,0.9,1,0.6),1.3,true)

## Draw the rocket body and animated exhaust around its current velocity direction.
func draw_rocket() -> void:
	var forward := velocity.normalized()
	var side := Vector2(-forward.y, forward.x)
	var flame_length := 22.0 + sin(age * 70.0) * 5.0
	draw_line(-forward * 7.0, -forward * flame_length, Color(1.0, 0.37, 0.1, 0.15), 18.0, true)
	draw_line(-forward * 7.0, -forward * flame_length, Color("ffb067"), 5.0, true)
	draw_line(-forward * 7.0, -forward * (flame_length - 4.0), Color("fff3cc"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		forward * 13.0, side * 5.0 + forward * 3.0,
		side * 8.0 - forward * 9.0, -forward * 6.0,
		-side * 8.0 - forward * 9.0, -side * 5.0 + forward * 3.0
	]), Color("dbe8f0"))
	draw_line(forward * 8.0, -forward * 4.0, Color("ff9c73"), 3.0, true)
