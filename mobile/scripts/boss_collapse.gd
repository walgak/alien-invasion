extends Node2D
## A frozen copy of the defeated 2D hull becomes its death well. The source boss
## can be freed immediately while its separately detached attack stays alive.
var game: Node2D
var kind := "black"
var tint := Color("a45cff")
var size := 1.8
var age := 0.0
var opened := false
var hull: Node2D
const OPEN_TIME := 0.65
const DURATION := 1.05

func configure(source: Node2D) -> void:
	position = source.body_position
	kind = source.kind
	tint = source.hole_color
	size = source.well_scale * 1.8
	z_as_relative = false
	z_index = 28
	hull = game.Boss.new()
	hull.game = game
	hull.kind = kind
	hull.hole_color = tint
	hull.animation_time = source.animation_time
	hull.collapse_snapshot = true
	add_child(hull)
	hull.queue_redraw()

## The simulation clock drives deformation; pausing never skips the collapse.
func step(delta: float) -> void:
	age += delta
	var progress := clampf(age / OPEN_TIME, 0.0, 1.0)
	if kind == "black":
		hull.rotation = progress * progress * 1.4
		hull.scale = Vector2(maxf(0.015, 1.0 - pow(progress, 0.7)), maxf(0.015, 1.0 + sin(progress * PI) * 0.5 - progress))
	else:
		hull.rotation = sin(progress * PI) * 0.1
		hull.scale = Vector2.ONE * (1.0 + progress * progress * 0.75)
		hull.modulate.a = 1.0 - pow(progress, 3.0)
	if age >= OPEN_TIME and not opened:
		opened = true
		hull.visible = false
		var well = game.Boss.new()
		well.game = game
		well.kind = kind
		well.hole_color = tint
		well.lingering = true
		well.phase = "active"
		well.body_position = position
		well.well_position = position
		well.well_scale = size
		well.well_duration = game.Boss.ACTIVE_SECONDS * 2.0
		game.add_child(well)
		game.lingering_wells.append(well)
		game.combat.vibrate(kind + "_spawn")
		game.sound.play_effect("rift")
	if age >= DURATION:
		game.gravity_fields.collapses.erase(self)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var progress := clampf(age / OPEN_TIME, 0.0, 1.0)
	var light := Color("d6faff") if kind == "white" else tint
	var radius := 20.0 + progress * progress * 135.0 if kind == "white" else 110.0 * (1.0 - progress) + 8.0
	var alpha := sin(progress * PI) * 0.045
	for layer in range(6, 0, -1):
		draw_circle(Vector2.ZERO, radius * float(layer) / 6.0, Color(light, alpha))
