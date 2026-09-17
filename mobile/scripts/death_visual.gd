extends Node2D
## Cause-specific hull destruction, drawn below the opaque event-horizon layer.
## Debris is created once from the real ship silhouette; no per-frame nodes.
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
	var width: float = [1.0, 1.13, 1.28, 1.45, 1.38][clampi(game.weapons.level, 0, 4)]
	var hull := PackedVector2Array([Vector2(0,-35),Vector2(16,-2),Vector2(33,23),Vector2(13,18),Vector2(0,27),Vector2(-13,18),Vector2(-33,23),Vector2(-16,-2)])
	add_panel(hull, Color("bacfdd"), width)
	add_panel(PackedVector2Array([Vector2(0,-24),Vector2(7,1),Vector2(0,13),Vector2(-7,1)]), Color("55e8d0"), width)
	for x in ([-17, 0, 17] if game.weapons.level >= 2 else ([-11, 11] if game.weapons.level == 1 else [0])):
		add_panel(PackedVector2Array([Vector2(x-3,-37),Vector2(x+3,-37),Vector2(x+3,-14),Vector2(x-3,-14)]), Color("607d94"), 1.0)
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

## Split each triangle around its centroid so the ship cracks into small plates.
func add_panel(polygon: PackedVector2Array, tint: Color, width: float) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index in range(0, indices.size(), 3):
		var triangle := PackedVector2Array([polygon[indices[index]], polygon[indices[index+1]], polygon[indices[index+2]]])
		var middle := (triangle[0] + triangle[1] + triangle[2]) / 3.0
		for edge in range(3):
			var points := PackedVector2Array([triangle[edge], triangle[(edge+1)%3], middle])
			for j in range(3):
				points[j].x *= width
				points[j] = points[j].rotated(game.ship.rotation)
			var center := (points[0]+points[1]+points[2])/3.0
			for j in range(3):
				points[j] -= center
			pieces.append({"shape": points, "offset": center, "tint": tint.darkened(float(pieces.size()%4)*0.08), "spin": sin(float(pieces.size())*13.7)*3.5})

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
		draw_colored_polygon(piece.shape, Color(piece.tint, alpha))
		draw_polyline(piece.shape, Color(0.05,0.12,0.17,alpha*0.8), 0.7, true)
	draw_set_transform(Vector2.ZERO)
	if exploded:
		var t := clampf(explosion_age/0.65, 0, 1)
		for layer in range(5,0,-1):
			draw_circle(explosion_at, (12+sqrt(t)*70)*float(layer)/5.0, Color(1,0.3+float(5-layer)*0.12,0.08,(1-t)*0.18))
		draw_arc(explosion_at, 12+t*140, 0, TAU, 64, Color(1,0.68,0.3,(1-t)*0.6), 2, true)
