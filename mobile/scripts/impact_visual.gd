extends Node2D
## Brief electrical contact discharges explain why a rammed alien dies. Four
## reusable plasma surfaces bound both draw calls and memory during swarms.
const Discharge = preload("res://shaders/impact_discharge.gdshader")
const DURATION := 0.38
const CAPACITY := 4
var game: Node2D
var surfaces: Array[ColorRect] = []
var ages: Array[float] = []
var next_slot := 0

func _init() -> void:
	z_index = 18

func _ready() -> void:
	for index in range(CAPACITY):
		var surface := ColorRect.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.material = ShaderMaterial.new()
		surface.material.shader = Discharge
		surface.visible = false
		add_child(surface)
		surfaces.append(surface)
		ages.append(DURATION)

## Coordinates are arena-local. The surface rotates with the contact vector,
## so its two bright roots stay attached to the ships instead of the screen.
func play_collision(from: Vector2, to: Vector2) -> void:
	if surfaces.is_empty():
		return
	var index := next_slot
	next_slot = (next_slot+1)%CAPACITY
	var surface := surfaces[index]
	var length := maxf(from.distance_to(to),18.0)
	surface.size = Vector2(length+56.0,96.0)
	surface.rotation = (to-from).angle()
	surface.position = from+Vector2(-28.0,-48.0).rotated(surface.rotation)
	surface.material.set_shader_parameter("aspect",surface.size.x/surface.size.y)
	surface.material.set_shader_parameter("seed",float(index)*7.3)
	surface.material.set_shader_parameter("age",0.0)
	surface.visible = true
	ages[index] = 0.0

func step(delta: float) -> void:
	for index in range(surfaces.size()):
		ages[index] += delta
		surfaces[index].visible = ages[index] < DURATION
		if surfaces[index].visible:
			surfaces[index].material.set_shader_parameter("age",ages[index])

func clear() -> void:
	for index in range(surfaces.size()):
		ages[index] = DURATION
		surfaces[index].visible = false
