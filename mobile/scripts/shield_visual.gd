extends Node2D
## Two reusable, touch-transparent optical domes. Their surfaces are cosmetic;
## Combat owns immunity and collision radius. Only a collected, live shield
## draws this mesh; physical resistance taps use the separate warp pass alone.
const Dome = preload("res://shaders/shield_dome.gdshader")
var game: Node2D
var player_surface: ColorRect
var boss_surface: ColorRect
var hit_age := 10.0
var hit_position := Vector2.ZERO

func _init() -> void:
	z_index = 16

func _ready() -> void:
	player_surface = make_surface()
	boss_surface = make_surface()

func make_surface() -> ColorRect:
	var surface := ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.material = ShaderMaterial.new()
	surface.material.shader = Dome
	surface.visible = false
	add_child(surface)
	return surface

## Called at the physical contact point. The ripple starts on that location
## and sweeps across the curved mesh, without changing any projectile state.
func hit_ripple(at: Vector2) -> void:
	hit_age = 0.0
	hit_position = at

func clear() -> void:
	hit_age = 10.0
	if is_instance_valid(player_surface):
		player_surface.visible = false
	if is_instance_valid(boss_surface):
		boss_surface.visible = false

func place(surface: ColorRect, at: Vector2, radius: float, strength: float, clock: float) -> void:
	surface.size = Vector2.ONE*radius*2.36
	surface.position = at-surface.size*0.5
	surface.material.set_shader_parameter("strength",strength)
	surface.material.set_shader_parameter("visual_time",clock)
	surface.material.set_shader_parameter("logical_radius",radius)

func step(delta: float) -> void:
	if game == null or not is_instance_valid(player_surface):
		return
	hit_age += delta
	player_surface.visible = game.death_time <= 0.0 and game.ship.visible and game.combat.shield_time > 0.0
	if player_surface.visible:
		var radius: float = game.combat.shield_radius()
		place(player_surface,game.ship.position,radius,1.0,game.visual_time)
		player_surface.material.set_shader_parameter("hit_age",hit_age)
		player_surface.material.set_shader_parameter("hit_position",(hit_position-game.ship.position)/radius)
	var boss: Node2D = game.boss
	boss_surface.visible = is_instance_valid(boss) and boss.visible and (game.boss_is_shielded() or boss.has_player_gravity_threat())
	if boss_surface.visible:
		var guards: Array = game.enemies.filter(func(enemy: Node2D) -> bool: return enemy.shield_guard)
		var strength := 1.0 if boss.has_player_gravity_threat() else 0.3+0.7*float(guards.size())/maxf(1.0,boss.guard_total)
		place(boss_surface,boss.body_position,boss.shield_radius(),strength,game.visual_time)
