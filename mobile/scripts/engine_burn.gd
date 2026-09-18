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
	for i in range(mini(jets.size(), nozzles.size())):
		jets[i].size = Vector2(width*4.8, 116.0)
		jets[i].position = nozzles[i] - Vector2(width*2.4, 2.0)

func set_load(amount: float) -> void:
	load_target = clampf(amount, 0.0, 1.0)

func reset_load() -> void:
	load_target = 0.0
	load_amount = 0.0
	advance(0.0)

## Supplied gameplay time makes pausing freeze the plume too.
func advance(delta: float) -> void:
	clock += delta
	load_amount = lerpf(load_amount, load_target, 1.0-exp(-delta*8.0))
	for jet in jets:
		jet.material.set_shader_parameter("engine_load", load_amount)
		jet.material.set_shader_parameter("visual_time", clock)
