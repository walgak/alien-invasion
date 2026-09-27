extends Node2D
## Reusable plasma surfaces extend the engine light itself. No line trails or
## particles are allocated when gravity becomes intense.
const Flame = preload("res://shaders/engine_burn.gdshader")
var jets: Array[ColorRect] = []
var nozzle_positions := PackedVector2Array()
var nozzle_width := 5.6
var tint := Color("258dff")
var load_target := 0.0
var load_amount := 0.0
var clock := 0.0
var gravity_tail_direction := Vector2.DOWN
var gravity_tail_strength := 0.0
var gravity_tail_target := 0.0
var gravity_tail_aim := Vector2.DOWN

func _init() -> void:
	z_index = -1

## Called once per actor; tier changes later only reposition the rectangles.
func configure(nozzles: PackedVector2Array, color: Color, width: float) -> void:
	tint = color
	for i in range(nozzles.size()):
		var jet := ColorRect.new()
		jet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jet.material = ShaderMaterial.new()
		jet.material.shader = Flame
		jet.material.set_shader_parameter("engine_color", tint)
		jet.material.set_shader_parameter("phase", float(i)*2.71)
		add_child(jet)
		jets.append(jet)
	set_nozzles(nozzles, width)
	advance(0.0)

func set_nozzles(nozzles: PackedVector2Array, width: float) -> void:
	nozzle_positions = nozzles
	nozzle_width = width
	update_layout()

## Expand only toward the borrowed-gravity wisps. The luminous nozzle keeps its
## original physical width, irrespective of the extra transparent drawing room.
func update_layout() -> void:
	var reach := 280.0 * gravity_tail_strength
	var half_width := nozzle_width * 3.4 + absf(gravity_tail_direction.x) * reach
	var top := 2.0 + maxf(0.0, -gravity_tail_direction.y) * reach
	var height := top + maxf(226.0, gravity_tail_direction.y * reach + 36.0)
	for i in range(mini(jets.size(), nozzle_positions.size())):
		jets[i].size = Vector2(half_width * 2.0, height)
		jets[i].position = nozzle_positions[i] - Vector2(half_width, top)
		jets[i].material.set_shader_parameter("surface_size", jets[i].size)
		jets[i].material.set_shader_parameter("nozzle_pixel", Vector2(half_width, top))
		jets[i].material.set_shader_parameter("nozzle_width", nozzle_width)

## Public local-space override for previews; ordinary actors sample their game
## automatically, so this effect does not add dependencies to movement code.
func set_gravity_tail(local_direction: Vector2, strength: float) -> void:
	gravity_tail_aim = local_direction.normalized() if local_direction.length_squared() > 0.0001 else Vector2.DOWN
	gravity_tail_target = clampf(strength, 0.0, 1.0)

func sample_gravity_tail() -> void:
	var actor := get_parent() as Node2D
	if not is_instance_valid(actor):
		return
	var game := actor.get_parent() as Node2D
	if not is_instance_valid(game) or not game.has_method("gravity_is_active") or not is_instance_valid(game.gravity_fields) or not game.gravity_fields.is_inside_tree():
		return
	var nearest: Node2D
	var distance := INF
	for well in game.gravity_fields.active_wells():
		if well.kind != "black" or (actor != game.ship and well.get_script() != game.PlayerWell):
			continue
		var rim: float = actor.position.distance_to(well.well_position) - 31.0 * well.well_scale
		if rim < distance:
			distance = rim
			nearest = well
	if nearest == null:
		set_gravity_tail(gravity_tail_direction, 0.0)
	else:
		set_gravity_tail(to_local(game.to_global(nearest.well_position)), (1.0 - clampf(distance / 600.0, 0.0, 1.0)) * load_target)

func set_load(amount: float) -> void:
	load_target = clampf(amount, 0.0, 1.0)

func reset_load() -> void:
	load_target = 0.0
	load_amount = 0.0
	gravity_tail_strength = 0.0
	gravity_tail_target = 0.0
	advance(0.0)

## Supplied gameplay time makes pausing freeze the plume too.
func advance(delta: float) -> void:
	clock += delta
	load_amount = lerpf(load_amount, load_target, 1.0-exp(-delta*8.0))
	sample_gravity_tail()
	gravity_tail_direction = gravity_tail_direction.slerp(gravity_tail_aim, 1.0 - exp(-delta * 9.0)).normalized()
	gravity_tail_strength = lerpf(gravity_tail_strength, gravity_tail_target, 1.0 - exp(-delta * 7.0))
	update_layout()
	for jet in jets:
		jet.material.set_shader_parameter("engine_load", load_amount)
		jet.material.set_shader_parameter("visual_time", clock)
		jet.material.set_shader_parameter("gravity_tail_direction", gravity_tail_direction)
		jet.material.set_shader_parameter("gravity_tail_strength", gravity_tail_strength)
