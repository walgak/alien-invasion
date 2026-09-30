extends Node2D
## Render stars behind gas and worlds in one reusable offscreen sky texture.
## SpaceFolds refracts that composite, so even the distant stars lens correctly.
## Physical tides remain subtle and independent from this optical displacement.
const SKY_SHADER = preload("res://shaders/space_background.gdshader")
const STAR_SHADER = preload("res://shaders/distant_stars.gdshader")
const MAX_FIELDS := 4
var arena_size := Vector2(540.0,960.0)
var sky_material := ShaderMaterial.new()
var star_material := ShaderMaterial.new()
var celestial_viewport: SubViewport
var celestial_surface: ColorRect
var star_surface: ColorRect
var wind_strength := 0.45
var previous_time := 0.0

func _init() -> void:
	star_material.shader = STAR_SHADER
	sky_material.shader = SKY_SHADER
	celestial_viewport = SubViewport.new()
	celestial_viewport.transparent_bg = false
	celestial_viewport.disable_3d = true
	celestial_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	celestial_viewport.handle_input_locally = false
	add_child(celestial_viewport)
	star_surface = ColorRect.new()
	star_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_surface.material = star_material
	celestial_viewport.add_child(star_surface)
	celestial_surface = ColorRect.new()
	celestial_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celestial_surface.material = sky_material
	celestial_viewport.add_child(celestial_surface)
	update_background(arena_size,0.0)

## Existing light/jitter callers keep using sky_material. Supplying the game
## additionally exposes a bounded set of active tides and sector wind strength.
func update_background(arena: Vector2, time: float, game: Node2D = null) -> void:
	arena_size = arena
	var logical_size := Vector2i(ceili(arena.x),ceili(arena.y))
	if celestial_viewport.size != logical_size:
		celestial_viewport.size = logical_size
		celestial_surface.size = arena
		star_surface.size = arena
	star_material.set_shader_parameter("arena_size",arena)
	star_material.set_shader_parameter("visual_time",time)
	sky_material.set_shader_parameter("arena_size",arena)
	sky_material.set_shader_parameter("visual_time",time)
	var fields := PackedVector4Array()
	if game != null:
		for well in game.gravity_fields.active_wells():
			if fields.size() >= MAX_FIELDS:
				break
			fields.append(Vector4(well.well_position.x,well.well_position.y,-1.0 if well.kind == "black" else 1.0,well.well_scale))
		# Four solar-weather levels vary by sector, easing rather than flashing
		# when a boss dies. Wind never shares the stationary star coordinates.
		var weather := [0.85,0.34,0.10,0.012]
		var target: float = weather[(game.bosses_defeated*3)%4]
		wind_strength = lerpf(wind_strength,target,1.0-exp(-maxf(0.0,time-previous_time)*0.3))
	sky_material.set_shader_parameter("field_count",fields.size())
	fields.resize(MAX_FIELDS)
	sky_material.set_shader_parameter("gravity_fields",fields)
	previous_time = time
	queue_redraw()

func celestial_texture() -> ViewportTexture:
	return celestial_viewport.get_texture()
