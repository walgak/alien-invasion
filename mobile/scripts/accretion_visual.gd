extends Node2D
## A reusable 2D accretion sprite. A monochrome texture supplies the fine plasma
## detail; the shader recolours and advects it using the game's pause-aware clock.
const AccretionShader = preload("res://shaders/accretion.gdshader")
const AccretionTexture = preload("res://assets/effects/accretion-vortex.png")
var half_extent := 140.0
var effect_material := ShaderMaterial.new()

func _init() -> void:
	# Plasma sits behind ships. The owning gravity layer draws opaque cores over
	# all ships and death fragments, so nothing leaks through a black horizon.
	z_as_relative = false
	z_index = -5
	effect_material.shader = AccretionShader
	material = effect_material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Size grows more slowly outside the core, containing maximum-charge overdraw.
func configure(at: Vector2, radius: float, white: bool, tint: Color, clock: float) -> void:
	position = at
	half_extent = radius + 108.0 * sqrt(maxf(radius / 31.0, 0.1))
	var hot := tint.lightened(0.77)
	if tint.r > 0.8 and tint.b < 0.35:
		hot = Color("ffe8a1")
	elif tint.b > 0.7 and tint.r < 0.4:
		hot = Color("bcfaff")
	effect_material.set_shader_parameter("core_radius", radius)
	effect_material.set_shader_parameter("half_extent", half_extent)
	effect_material.set_shader_parameter("energy_color", tint)
	effect_material.set_shader_parameter("hot_color", hot)
	effect_material.set_shader_parameter("white_hole", white)
	effect_material.set_shader_parameter("visual_time", clock)
	visible = true
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(AccretionTexture, Rect2(-Vector2.ONE * half_extent, Vector2.ONE * half_extent * 2.0), false)
