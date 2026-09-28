extends Node2D
## One reusable screen-space quad joins two opaque horizons with a liquid neck.
## Physics remains on the owning wells; the shared radius cache follows this
## same area-preserving lobe shape, so swallowing and beam contact stay aligned.
const Surface = preload("res://shaders/blackhole_coalescence.gdshader")
var extent := Vector2.ONE
var surface := ShaderMaterial.new()

func _init() -> void:
	z_as_relative = false
	z_index = 33
	surface.shader = Surface
	material = surface

func configure(first: Vector2, second: Vector2, radius_a: float, radius_b: float, tint: Color, clock: float) -> void:
	var padding := maxf(radius_a, radius_b) + 22.0
	var low := first.min(second) - Vector2.ONE * padding
	var high := first.max(second) + Vector2.ONE * padding
	position = low
	extent = high - low
	surface.set_shader_parameter("extent", extent)
	surface.set_shader_parameter("first", first - low)
	surface.set_shader_parameter("second", second - low)
	surface.set_shader_parameter("radii", Vector2(radius_a, radius_b))
	surface.set_shader_parameter("energy", tint)
	surface.set_shader_parameter("clock", clock)
	visible = true
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, extent), Color.WHITE)
