extends Node2D

var radius := 24.0
var health := 2
var velocity := Vector2(0, 240)
var previous_position := Vector2.ZERO
var spin := 1.0
var outline := PackedVector2Array()
var flash := 0.0
var max_health := 2
var fold_origin := Vector2.ZERO
var fold_life := 1.4

func _ready() -> void:
	for i in range(9):
		outline.append(Vector2.from_angle(i * TAU / 9.0) * radius * (0.8 if i % 3 == 0 else 1.0))
	max_health = max(health, 1)

func advance(delta: float) -> void:
	previous_position = position
	position += velocity * delta
	rotation += spin * delta
	flash = maxf(0, flash - delta)
	fold_life = maxf(0, fold_life - delta)
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
	var alpha := fold_life / 1.4
	var start := fold_origin - position
	for lane in range(5):
		var points := PackedVector2Array()
		var offset := float(lane - 2) * radius * 0.23
		var side := start.orthogonal().normalized() if start.length() > 0.001 else Vector2.RIGHT
		for i in range(24):
			var t := float(i) / 23.0
			var base := start.lerp(Vector2.ZERO, t)
			var wave := side * (offset + sin(t * TAU * 2.4 + lane + rotation) * radius * 0.12)
			points.append(base + wave)
		draw_polyline(points, Color("b9f8ff", alpha * 0.14), 1.0, true)
