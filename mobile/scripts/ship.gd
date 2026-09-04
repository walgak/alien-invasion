extends Node2D
## Movement is measured in pixels per second; input only changes the target.

const SPEED := 640.0
const HIT_RADIUS := 15.0
var target_x := 270.0
var invulnerable := 0.0
var animation_time := 0.0
var lean := 0.0

func move_ship(delta: float, direction: float, width: float) -> void:
	target_x = clampf(target_x + direction * SPEED * delta, 35.0, width - 35.0)
	var old_x := position.x
	position.x = move_toward(position.x, target_x, SPEED * delta)
	lean = lerpf(lean, (position.x - old_x) / maxf(delta, 0.001) / SPEED, 12.0 * delta)
	rotation = lean * 0.12
	invulnerable = maxf(0.0, invulnerable - delta)
	animate(delta)

func animate(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func reset_ship(at: Vector2) -> void:
	position = at
	target_x = at.x
	invulnerable = 0.0
	rotation = 0.0
	lean = 0.0
	scale = Vector2.ONE
	visible = true

func _draw() -> void:
	if invulnerable > 0.0:
		draw_arc(Vector2.ZERO, 41.0, 0.0, TAU, 48, Color(0.35, 0.91, 0.82, 0.35), 1.5, true)
		if fmod(invulnerable, 0.18) < 0.07:
			return
	var flame := 33.0 + sin(animation_time * 32.0) * 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 22), Vector2(0, flame + 15), Vector2(7, 22)]), Color("ff9a62"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 23), Vector2(0, flame), Vector2(3, 23)]), Color("fff3c0"))
	draw_circle(Vector2(0, 5), 37, Color(0.22, 0.75, 0.75, 0.04))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-35),Vector2(16,-2),Vector2(33,23),Vector2(13,18),Vector2(0,27),Vector2(-13,18),Vector2(-33,23),Vector2(-16,-2)]), Color("d8e9f0"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-35),Vector2(0,27),Vector2(-13,18),Vector2(-33,23),Vector2(-16,-2)]), Color("8ca8bc"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-24),Vector2(7,1),Vector2(0,13),Vector2(-7,1)]), Color("55e8d0"))
	draw_line(Vector2(-22,15),Vector2(-13,7),Color("31516b"),2,true)
	draw_line(Vector2(22,15),Vector2(13,7),Color("31516b"),2,true)
	draw_line(Vector2(-14,18),Vector2(-7,21),Color("55e8d0"),2,true)
	draw_line(Vector2(14,18),Vector2(7,21),Color("55e8d0"),2,true)
