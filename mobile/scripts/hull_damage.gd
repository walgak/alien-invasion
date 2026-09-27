extends Node2D
## One pooled procedural smoke surface per fighter. No per-frame particles or
## physics are created; repairs simply hide the existing surface again.
const Smoke = preload("res://shaders/hull_smoke.gdshader")
var cloud: ColorRect
var cloud_surface: ShaderMaterial
var stage := 0
var clock := 0.0
var hull_size := Vector2(88,88)
var alien := false

func _init() -> void:
	z_index = 1

func _ready() -> void:
	cloud = ColorRect.new()
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_surface = ShaderMaterial.new()
	cloud_surface.shader = Smoke
	cloud.material = cloud_surface
	add_child(cloud)
	configure(hull_size, alien)
	cloud.visible = false

func configure(dimensions: Vector2, is_alien: bool) -> void:
	hull_size = dimensions
	alien = is_alien
	if not is_instance_valid(cloud):
		return
	position = hull_size * (Vector2(0.17,-0.07) if alien else Vector2(-0.19,0.04))
	rotation = PI if alien else 0.0
	cloud.size = Vector2(hull_size.x * 0.66, hull_size.y * 1.05)
	cloud.position = Vector2(-cloud.size.x * 0.5,-5.0)

## Damage is whole lives/hits lost. Clock advances only during game simulation.
func advance(delta: float, damage_stage: int) -> void:
	clock += delta
	stage = clampi(damage_stage,0,2)
	if not is_instance_valid(cloud):
		return
	cloud.visible = stage >= 2
	cloud_surface.set_shader_parameter("visual_time", clock)

func clear() -> void:
	clock = 0.0
	stage = 0
	if is_instance_valid(cloud):
		cloud.visible = false
