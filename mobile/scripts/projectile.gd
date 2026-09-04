extends Node2D

var velocity := Vector2(0, -850)
var hostile := false
var previous_position := Vector2.ZERO

func advance(delta: float) -> void:
	previous_position = position
	position += velocity * delta

func intersects(center: Vector2, radius: float) -> bool:
	# Swept collision catches targets even when a shot crosses them in one frame.
	var closest := Geometry2D.get_closest_point_to_segment(center, previous_position, position)
	return closest.distance_squared_to(center) <= radius * radius

func _draw() -> void:
	var tint := Color("ff816f") if hostile else Color("63f2d2")
	var tail := Vector2(0, -13 if hostile else 20)
	draw_line(-tail * 0.3, tail, Color(tint, 0.09), 12, true)
	draw_line(-tail * 0.3, tail, Color(tint, 0.3), 5, true)
	draw_line(Vector2.ZERO, tail * 0.7, tint, 2.5, true)
	draw_circle(Vector2.ZERO, 2.5, Color("e8fff6"))
