extends Node2D
## Cause-specific hull destruction, drawn below the opaque event-horizon layer.
## Debris is created once from the real ship silhouette; no per-frame nodes.
const Artwork = preload("res://scripts/ship_artwork.gd")
var game: Node2D
var pieces: Array[Dictionary] = []
var cause := "shot"
var exploded := false
var explosion_at := Vector2.ZERO
var explosion_age := -1.0

## Keep shards over normal actors and under gravity_fields' horizon masks.
func _init() -> void:
	z_index = 30

## Triangulate the hull and cockpit into recognizable pieces at their actual pose.
func begin(kind: String) -> void:
	cause = kind
	pieces.clear()
	exploded = false
	explosion_age = -1.0
	explosion_at = game.death_origin
	material = Artwork.surface_for(game.weapons.level, game.ship.animation_time)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_textured_panels(game.weapons.level)
	if cause == "white":
		var at: Vector2 = game.death_origin
		var distances := [at.x, game.arena.x-at.x, at.y, game.arena.y-at.y]
		match distances.find(distances.min()):
			0: explosion_at.x = 3
			1: explosion_at.x = game.arena.x-3
			2: explosion_at.y = 3
			3: explosion_at.y = game.arena.y-3
	game.ship.visible = false
	queue_redraw()

## A fixed triangular mesh preserves the real texture instead of substituting
## generic colored shards. Alpha keeps wing gaps empty; the horizon layer still
## masks every fragment. The mesh is bounded at 240 pieces, regardless of tier.
func add_textured_panels(level: int) -> void:
	var size := Artwork.size_for(level)
	for row in range(12):
		for column in range(10):
			var a := Vector2(float(column)/10.0, float(row)/12.0)
			var b := a + Vector2(0.1, 0.0)
			var c := a + Vector2(0.1, 1.0/12.0)
			var d := a + Vector2(0.0, 1.0/12.0)
			for uv in [PackedVector2Array([a,b,c]), PackedVector2Array([a,c,d])]:
				var points := PackedVector2Array()
				for point in uv:
					points.append(((point-Vector2.ONE*0.5)*size*game.ship.scale).rotated(game.ship.rotation))
				var center := (points[0]+points[1]+points[2])/3.0
				for index in range(3):
					points[index] -= center
				pieces.append({"shape":points, "uv":uv, "offset":center, "spin":sin(float(pieces.size())*13.7)*3.5})

## Shot deaths explode immediately; collisions crumble before the delayed blast.
func step(delta: float) -> void:
	queue_redraw()
	if game.death_time <= 0.0:
		return
	var age: float = 1.8-game.death_time
	var delay := 0.0 if cause == "shot" else 0.42
	if cause != "black" and not exploded and age >= delay:
		exploded = true
		explosion_age = 0.0
		game.sound.play_effect("burst")
		game.combat.vibrate("hit")
	if exploded:
		explosion_age += delta
	queue_redraw()

## Fragments spiral into black holes; collision fragments compact before erupting.
func _draw() -> void:
	if game == null or game.death_time <= 0.0:
		return
	var age: float = 1.8-game.death_time
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		var offset: Vector2 = piece.offset
		var at: Vector2 = game.death_origin + offset
		var shrink := 1.0
		var alpha := 1.0
		if cause == "black":
			var t := clampf((age-float(i%5)*0.035)/1.15, 0, 1)
			var relative: Vector2 = at-game.death_target
			at = game.death_target + relative.rotated(t*0.38)*(1.0-t*t)
			shrink = 1.0-t*0.7
			if at.distance_to(game.death_target) + 12.0*shrink < game.death_radius:
				continue
		else:
			var pre := clampf(age/0.42, 0, 1)
			at = game.death_origin.lerp(explosion_at, pre) + offset * (1.0-pre*0.28)
			if exploded:
				var direction := Vector2.from_angle(float(i)*2.39996)
				at = explosion_at + offset + direction * explosion_age * (45+i%7*18)
				alpha = maxf(0.0, 1.0-explosion_age/1.2)
		draw_set_transform(at, piece.spin*age, Vector2.ONE*shrink)
		draw_polygon(piece.shape, PackedColorArray([Color(1,1,1,alpha)]), piece.uv, Artwork.FIGHTER_TEXTURE)
	draw_set_transform(Vector2.ZERO)
	if exploded:
		var t := clampf(explosion_age/0.65, 0, 1)
		for layer in range(5,0,-1):
			draw_circle(explosion_at, (12+sqrt(t)*70)*float(layer)/5.0, Color(1,0.3+float(5-layer)*0.12,0.08,(1-t)*0.18))
		draw_arc(explosion_at, 12+t*140, 0, TAU, 64, Color(1,0.68,0.3,(1-t)*0.6), 2, true)
