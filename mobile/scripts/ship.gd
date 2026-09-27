extends Node2D
## A 2D fighter with baked metallic detail. Only the visual hull grows with
## upgrades; steering, touch acquisition and the collision radius stay constant.
const SPEED := 640.0
const HIT_RADIUS := 15.0
const Artwork = preload("res://scripts/ship_artwork.gd")
const EngineBurn = preload("res://scripts/engine_burn.gd")
const HullDamage = preload("res://scripts/hull_damage.gd")
var damage_visual: Node2D
var hull_health := 3
var damage_clock := 0.0
var target_x := 270.0
var invulnerable := 0.0
var animation_time := 0.0
var lean := 0.0
var weapon_level := 0
var engine_burn: Node2D
var hull_surface := Artwork.surface_for(0)

## Engine children sit beneath the hull, beginning at its actual blue nozzles.
func _ready() -> void:
	material = hull_surface
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	engine_burn = EngineBurn.new()
	add_child(engine_burn)
	engine_burn.configure(Artwork.nozzles(weapon_level), Color("258dff"), 5.6)
	damage_visual = HullDamage.new()
	add_child(damage_visual)
	damage_visual.configure(Artwork.size_for(weapon_level), false)
	set_hull_health(hull_health)

## Root game owns the three lives. Repairs restore plating and stop smoke;
## visual damage never changes control speed, hit radius or emitter positions.
func set_hull_health(lives: int) -> void:
	hull_health = clampi(lives,0,3)
	update_damage_visual(0.0)

func update_damage_visual(delta: float) -> void:
	damage_clock += delta
	var stage := clampi(3-hull_health,0,2)
	hull_surface.set_shader_parameter("hull_damage",float(stage))
	hull_surface.set_shader_parameter("damage_time",damage_clock)
	if is_instance_valid(damage_visual):
		damage_visual.configure(Artwork.size_for(weapon_level),false)
		damage_visual.advance(delta,stage)
	queue_redraw()

## Return an arena-space origin even while leaning or resisting gravity.
func muzzle_position(level: int, lane: int = 0, special: bool = false) -> Vector2:
	return to_global(Artwork.muzzle_local(level, lane, special))

## Move at constant speed toward the drag/keyboard target, independent of FPS.
func move_ship(delta: float, direction: float, width: float) -> void:
	target_x = clampf(target_x + direction * SPEED * delta, 35.0, width - 35.0)
	var old_x := position.x
	position.x = move_toward(position.x, target_x, SPEED * delta)
	lean = lerpf(lean, (position.x - old_x) / maxf(delta, 0.001) / SPEED, 12.0 * delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	animate(delta)

## Redrawing applies upgrades without creating new textures or engine nodes.
func animate(delta: float) -> void:
	animation_time += delta
	queue_redraw()

## Recovery after a boss uses movement elsewhere; this reset is for a new run.
func reset_ship(at: Vector2) -> void:
	position = at
	target_x = at.x
	invulnerable = 0.0
	rotation = 0.0
	lean = 0.0
	weapon_level = 0
	hull_health = 3
	damage_clock = 0.0
	set_hull_health(3)
	if is_instance_valid(damage_visual):
		damage_visual.clear()
	scale = Vector2.ONE
	visible = true
	if is_instance_valid(engine_burn):
		engine_burn.reset_load()
	queue_redraw()

func _draw() -> void:
	Artwork.update_surface(hull_surface, weapon_level, animation_time, invulnerable > 0.0)
	if is_instance_valid(engine_burn):
		engine_burn.set_nozzles(Artwork.nozzles(weapon_level), 5.6 * Artwork.WIDTHS[clampi(weapon_level,0,4)])
	draw_texture_rect(Artwork.FIGHTER_TEXTURE, Artwork.rect_for(weapon_level), false)
