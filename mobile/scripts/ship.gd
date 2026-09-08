extends Node2D
## Movement is measured in pixels per second; input only changes the target.

const SPEED := 640.0
const HIT_RADIUS := 15.0
var target_x := 270.0
var invulnerable := 0.0
var animation_time := 0.0
var lean := 0.0
var weapon_level := 0

## Move toward the drag/keyboard target at a fixed speed; delta is elapsed seconds, so motion is frame-rate independent.
func move_ship(delta: float, direction: float, width: float) -> void:
	target_x = clampf(target_x + direction * SPEED * delta, 35.0, width - 35.0)
	var old_x := position.x
	position.x = move_toward(position.x, target_x, SPEED * delta)
	lean = lerpf(lean, (position.x - old_x) / maxf(delta, 0.001) / SPEED, 12.0 * delta)
	rotation = lean * 0.12
	invulnerable = maxf(0.0, invulnerable - delta)
	animate(delta)

## Advance visual time and request a redraw; this does not change collision state.
func animate(delta: float) -> void:
	animation_time += delta
	queue_redraw()

## Reset position, steering, scale and visibility for a new run. Ordinary boss victory uses smooth return instead.
func reset_ship(at: Vector2) -> void:
	position = at
	target_x = at.x
	invulnerable = 0.0
	rotation = 0.0
	lean = 0.0
	scale = Vector2.ONE
	visible = true

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	# Add wider equipment without changing the small, predictable collision hull.
	var width: float = [1.0, 1.13, 1.28, 1.45, 1.38][clampi(weapon_level, 0, 4)]
	draw_set_transform(Vector2.ZERO, 0, Vector2(width, 1.0))
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
	draw_set_transform(Vector2.ZERO)
	var barrels := [0.0]
	if weapon_level == 1:
		barrels = [-11.0, 11.0]
	elif weapon_level == 2:
		barrels = [-17.0, 0.0, 17.0]
	elif weapon_level == 4:
		barrels = [-13.0, 13.0]
	for x in barrels:
		draw_rect(Rect2(x - 3.0, -37.0, 6.0, 23.0), Color("607d94"))
		draw_line(Vector2(x, -37), Vector2(x, -21), Color("7ff8e4"), 2.0)
	if weapon_level == 3:
		for y in [-31.0, -23.0, -15.0]:
			draw_arc(Vector2(0, y), 10, PI, TAU, 16, Color("9fdcff"), 3.0)
		draw_circle(Vector2(0, -40), 7, Color("d0f7ff"))
