extends Node2D
## Movement is measured in pixels per second; input only changes the target.

const SPEED := 640.0
const HIT_RADIUS := 15.0
const HullFinish = preload("res://scripts/hull_finish.gd")
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
	# Layered bright alloy armor and inset cyan conduits share the alien fleet's sharp
	# design language, while cyan keeps the player readable against violet enemies.
	var width: float = [1.0, 1.13, 1.28, 1.45, 1.38][clampi(weapon_level, 0, 4)]
	draw_set_transform(Vector2.ZERO, 0, Vector2(width, 1.0))
	if invulnerable > 0.0:
		draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 64, Color(0.35, 0.91, 0.95, 0.45), 2.0, true)
		# Keep the full hull visible during recovery; a refreshed immunity timer
		# must never pin the ship inside the invisible portion of a blink cycle.
	var flame := 33.0 + sin(animation_time * 32.0) * 6.0
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side*5,20),Vector2(side*2,flame+15),Vector2(side*9,23)]),Color(0.15,0.85,1.0,0.22))
		draw_colored_polygon(PackedVector2Array([Vector2(side*5,21),Vector2(side*4,flame),Vector2(side*8,22)]),Color("8ff7ff"))
	draw_circle(Vector2.ZERO, 40, Color(0.12, 0.8, 1.0, 0.055))
	# Swept outer blades.
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side*7,-17),Vector2(side*22,-7),Vector2(side*37,21),Vector2(side*29,17),Vector2(side*17,4),Vector2(side*13,24),Vector2(side*4,18)])
		HullFinish.plate(self, wing, Color("425c73"), Color("75eeff"), animation_time)
		var plate := PackedVector2Array([Vector2(side*14,-8),Vector2(side*23,-1),Vector2(side*31,15),Vector2(side*22,10),Vector2(side*15,2)])
		HullFinish.plate(self, plate, Color("7199ae"), Color("75eeff"), animation_time + side * 0.3)
		draw_line(Vector2(side*14,-6),Vector2(side*27,14),Color("54e9ee"),2.2,true)
	# Spear-shaped central hull and raised armor facets.
	var hull := PackedVector2Array([Vector2(0,-39),Vector2(13,-13),Vector2(14,10),Vector2(7,27),Vector2(0,32),Vector2(-7,27),Vector2(-14,10),Vector2(-13,-13)])
	HullFinish.plate(self, hull, Color("587991"), Color("75eeff"), animation_time)
	HullFinish.plate(self, PackedVector2Array([Vector2(0,-37),Vector2(0,25),Vector2(-7,20),Vector2(-11,-10)]), Color("9dbbcd"), Color("75eeff"), animation_time)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-29),Vector2(7,-9),Vector2(4,13),Vector2(0,22),Vector2(-4,13),Vector2(-7,-9)]),Color("0a1522"))
	draw_polyline(PackedVector2Array([Vector2(0,-27),Vector2(4,-8),Vector2(0,16),Vector2(-4,-8),Vector2(0,-27)]),Color("6ff8ef"),2.0,true)
	# A narrow glass reflection sits inside the dark cockpit's cyan frame.
	draw_line(Vector2(-2,-18), Vector2(-1,-5), Color("d5fbff"), 1.1, true)
	draw_line(Vector2(-10,10),Vector2(0,27),Color("71879a"),1.2,true)
	draw_line(Vector2(10,10),Vector2(0,27),Color("24394c"),1.2,true)
	draw_set_transform(Vector2.ZERO)
	var barrels := [0.0]
	if weapon_level == 1:
		barrels = [-11.0, 11.0]
	elif weapon_level == 2:
		barrels = [-17.0, 0.0, 17.0]
	elif weapon_level == 4:
		barrels = [-13.0, 13.0]
	for x in barrels:
		HullFinish.plate(self, PackedVector2Array([Vector2(x-4,-39),Vector2(x+4,-39),Vector2(x+3,-16),Vector2(x-3,-16)]), Color("61768c"), Color("75eeff"), animation_time)
		draw_line(Vector2(x, -38), Vector2(x, -19), Color("7ff8f4"), 2.2)
	if weapon_level == 3:
		for y in [-31.0, -23.0, -15.0]:
			draw_arc(Vector2(0, y), 10, PI, TAU, 16, Color("9fdcff"), 3.0)
		draw_circle(Vector2(0, -40), 7, Color("d0f7ff"))
