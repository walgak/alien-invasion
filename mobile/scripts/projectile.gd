extends Node2D

var velocity := Vector2(0, -850)
var hostile := false
var previous_position := Vector2.ZERO
var kind := "bullet"
var damage := 1
var piercing := false
var hit_ids: Dictionary = {}
var blast_radius := 0.0
var expired := false
var age := 0.0
var lifetime := 8.0
var beam_start := Vector2.ZERO

func setup_laser(from: Vector2, to: Vector2) -> void:
	kind = "laser"
	piercing = true
	damage = 2
	lifetime = 0.13
	beam_start = from
	previous_position = from
	position = to
	velocity = Vector2.ZERO

func advance(delta: float) -> void:
	age += delta
	expired = age >= lifetime
	if kind == "laser":
		# Keep the entire beam available to swept collision for its short pulse.
		previous_position = beam_start
	else:
		previous_position = position
		position += velocity * delta
	queue_redraw()

func intersects(center: Vector2, radius: float) -> bool:
	# Swept collision catches targets even when a shot crosses them in one frame.
	var closest := Geometry2D.get_closest_point_to_segment(center, previous_position, position)
	var collision_radius := radius + (5.0 if kind == "laser" else 0.0)
	return closest.distance_squared_to(center) <= collision_radius * collision_radius

func _draw() -> void:
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

func draw_laser() -> void:
	var muzzle := beam_start - position
	var brightness := clampf((lifetime - age) / 0.055, 0.0, 1.0)
	draw_line(muzzle, Vector2.ZERO, Color(0.39, 0.74, 1.0, 0.08 * brightness), 36.0, true)
	draw_line(muzzle, Vector2.ZERO, Color(0.39, 0.77, 1.0, 0.22 * brightness), 18.0, true)
	draw_line(muzzle, Vector2.ZERO, Color(0.52, 0.88, 1.0, 0.85 * brightness), 7.0, true)
	draw_line(muzzle, Vector2.ZERO, Color(0.92, 1.0, 1.0, brightness), 2.5, true)
	draw_circle(muzzle, 13.0, Color(0.42, 0.84, 1.0, 0.18 * brightness))
	draw_circle(muzzle, 5.0, Color(0.86, 0.99, 1.0, brightness))

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
