extends Node2D

var radius := 24.0
var health := 2
var velocity := Vector2(0, 240)
var previous_position := Vector2.ZERO
var spin := 1.0
var outline := PackedVector2Array()
var flash := 0.0

func _ready() -> void:
	for i in range(9):
		outline.append(Vector2.from_angle(i * TAU / 9.0) * radius * (0.8 if i % 3 == 0 else 1.0))

func advance(delta: float) -> void:
	previous_position = position
	position += velocity * delta
	rotation += spin * delta
	flash = maxf(0, flash - delta)
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(outline, Color("fff0d5") if flash > 0 else Color("495065"))
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color("caa48c"), 1.5, true)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.25), radius * 0.25, Color("2d3449"))
	draw_circle(Vector2(radius * 0.28, radius * 0.1), radius * 0.16, Color("333c50"))
	if health == 1:
		draw_polyline(PackedVector2Array([Vector2(-radius, 0), Vector2(0, -5), Vector2(5, 9), Vector2(radius, radius * 0.4)]), Color("ffb86a"), 2, true)
