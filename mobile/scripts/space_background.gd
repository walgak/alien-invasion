extends Node2D
## An opaque, textured sky behind the actors and the space-fold refraction pass.

const SKY_SHADER = preload("res://shaders/space_background.gdshader")

var arena_size := Vector2(540.0, 960.0)
var sky_material := ShaderMaterial.new()

func _init() -> void:
	sky_material.shader = SKY_SHADER
	material = sky_material
	update_background(arena_size, 0.0)

func update_background(arena: Vector2, time: float) -> void:
	arena_size = arena
	sky_material.set_shader_parameter("arena_size", arena_size)
	sky_material.set_shader_parameter("visual_time", time)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color.WHITE)
