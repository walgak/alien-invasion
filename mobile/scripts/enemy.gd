extends Node2D

const HIT_RADIUS := 24.0
var formation_offset := Vector2.ZERO
var phase := 0.0
var tint := Color("ffb86a")

func _draw() -> void:
	draw_circle(Vector2.ZERO, 29, Color(tint, 0.045))
	draw_colored_polygon(PackedVector2Array([Vector2(-27,-9),Vector2(-14,-3),Vector2(-8,12),Vector2(-22,19),Vector2(-19,4),Vector2(-29,2)]), tint.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(27,-9),Vector2(14,-3),Vector2(8,12),Vector2(22,19),Vector2(19,4),Vector2(29,2)]), tint.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-19),Vector2(17,-9),Vector2(13,9),Vector2(0,18),Vector2(-13,9),Vector2(-17,-9)]), Color("303247"))
	draw_polyline(PackedVector2Array([Vector2(-13,9),Vector2(-17,-9),Vector2(0,-19),Vector2(17,-9),Vector2(13,9)]), tint, 2, true)
	draw_line(Vector2(-9,-3),Vector2(-3,1),tint,3,true)
	draw_line(Vector2(9,-3),Vector2(3,1),tint,3,true)
	draw_circle(Vector2(0,11),2,Color("fff3d7"))
