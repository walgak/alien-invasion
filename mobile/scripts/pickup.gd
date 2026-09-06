extends Node2D
## Collection and attraction are handled by the game, so drops pause with play.

const HIT_RADIUS := 20.0
var kind := "weapon"
var previous_position := Vector2.ZERO
var age := 0.0
var velocity := Vector2(0.0, 82.0)
var phase := 0.0

func advance(delta: float) -> void:
	previous_position = position
	var sway_before := sin(age * 2.1 + phase)
	age += delta
	position += velocity * delta
	# Integrating the offset keeps the same gentle path at every frame rate.
	position.x += (sin(age * 2.1 + phase) - sway_before) * 8.0
	queue_redraw()

func _draw() -> void:
	var tint := Color("7cf3b7") if kind == "life" else Color("ffc56e")
	var pulse := 0.5 + 0.5 * sin(age * 4.5)
	draw_circle(Vector2.ZERO, 29.0 + pulse * 3.0, Color(tint, 0.045))
	draw_circle(Vector2.ZERO, 23.0, Color(tint, 0.08))
	var diamond := PackedVector2Array([
		Vector2(0.0, -20.0), Vector2(20.0, 0.0),
		Vector2(0.0, 20.0), Vector2(-20.0, 0.0), Vector2(0.0, -20.0)
	])
	draw_colored_polygon(diamond, Color("102338"))
	draw_polyline(diamond, Color(tint, 0.9), 1.8, true)
	draw_arc(Vector2.ZERO, 25.0, age * 1.2, age * 1.2 + 1.1, 16, Color(tint, 0.65), 1.5, true)
	draw_arc(Vector2.ZERO, 25.0, age * 1.2 + PI, age * 1.2 + PI + 1.1, 16, Color(tint, 0.35), 1.5, true)
	if kind == "life":
		draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), tint, 5.0, true)
		draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), tint, 5.0, true)
	else:
		# Paired upward chevrons read as a weapon upgrade at small phone sizes.
		draw_polyline(PackedVector2Array([
			Vector2(-7.0, -1.0), Vector2(0.0, -8.0), Vector2(7.0, -1.0)
		]), tint, 3.0, true)
		draw_polyline(PackedVector2Array([
			Vector2(-7.0, 7.0), Vector2(0.0, 0.0), Vector2(7.0, 7.0)
		]), tint, 3.0, true)
