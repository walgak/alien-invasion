extends Button
## A decorative circular control. Interface owns raw pointer routing; this node
## deliberately ignores GUI hit testing so a steering finger can cross it.
const Glass = preload("res://shaders/glass_button.gdshader")
var action := "gravity"
var count := ""
var available := false
var selected := false
var progress := 0.0
var clock := 0.0
var surface: ShaderMaterial
var lens: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	lens = ColorRect.new()
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface = ShaderMaterial.new()
	surface.shader = Glass
	lens.material = surface
	lens.show_behind_parent = true
	add_child(lens)

## The transparent square corners never acquire touches.
func contains_point(at: Vector2) -> bool:
	return at.distance_squared_to(global_position + size * 0.5) <= pow(size.x * 0.5, 2.0)

func present(stock: String, enabled: bool, active: bool, amount: float, visual_clock: float) -> void:
	count = stock
	available = enabled
	selected = active
	progress = clampf(amount, 0.0, 1.0)
	clock = visual_clock
	if surface:
		lens.size = size
		surface.set_shader_parameter("visual_time", clock)
		surface.set_shader_parameter("available", 1.0 if available else 0.0)
		surface.set_shader_parameter("selected", 1.0 if selected else 0.0)
		surface.set_shader_parameter("charge", progress)
	queue_redraw()

## Icons describe the four weapons without text over the playfield. Brightness
## conveys readiness; a small count and rim fill carry the necessary inventory.
func _draw() -> void:
	var center := size * 0.5
	var ink := Color(0.78, 0.93, 1.0, 1.0 if available else 0.43)
	if selected:
		ink = Color("d8efff")
	draw_set_transform(center, 0.0, Vector2.ONE)
	match action:
		"pause":
			draw_rect(Rect2(-7, -8, 4, 16), ink)
			draw_rect(Rect2(3, -8, 4, 16), ink)
		"gravity":
			draw_circle(Vector2(0, -3), 5.7, Color(0.015, 0.045, 0.11, 0.92))
			draw_arc(Vector2(0, -3), 8.0, -0.25, 2.55, 20, ink, 2.4, true)
			draw_arc(Vector2(0, -3), 10.5, 2.85, 5.7, 20, ink, 2.0, true)
		"laser":
			draw_colored_polygon(PackedVector2Array([Vector2(-2, 10), Vector2(-2, -7), Vector2(0, -17), Vector2(2, -7), Vector2(2, 10)]), ink)
			draw_circle(Vector2(0, 8), 4.5, ink)
			draw_line(Vector2(-8, -6), Vector2(-5, -8), ink, 1.5, true)
			draw_line(Vector2(8, -6), Vector2(5, -8), ink, 1.5, true)
		"cannon":
			for lane in [-1, 0, 1]:
				var x := float(lane) * 8.0
				var y := -4.0 if lane == 0 else 0.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, y-12), Vector2(x+3, y-6), Vector2(x+3, y+7), Vector2(x-3, y+7), Vector2(x-3, y-6)]), ink)
		"electron":
			draw_colored_polygon(PackedVector2Array([Vector2(4,-18),Vector2(-10,-1),Vector2(-2,0),Vector2(-7,12),Vector2(11,-5),Vector2(2,-5)]), ink)
	if not count.is_empty():
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(-width * 0.5, 23), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_set_transform(Vector2.ZERO)
