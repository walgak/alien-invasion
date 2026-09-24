extends Node2D
## The real hull flexes as a connected mesh, tears, ignites, then releases a
## screen-sized pressure wave. Everything stays below the opaque horizon mask.
const DURATION := 2.6
const Artwork = preload("res://scripts/ship_artwork.gd")
const Fire = preload("res://shaders/death_fire.gdshader")
var game: Node2D
var pieces: Array[Dictionary] = []
var cause := "shot"
var exploded := false
var explosion_at := Vector2.ZERO
var explosion_age := -1.0
var fire: ColorRect

func _init() -> void:
	z_index = 30

## Build the bounded fire surface once; it cannot receive touches or leak in
## front of the gravity field's z=32 event-horizon mask.
func _ready() -> void:
	fire = ColorRect.new()
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire.size = Vector2.ONE * 420.0
	fire.material = ShaderMaterial.new()
	fire.material.shader = Fire
	fire.visible = false
	add_child(fire)

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
			0: explosion_at.x = 3.0
			1: explosion_at.x = game.arena.x-3.0
			2: explosion_at.y = 3.0
			3: explosion_at.y = game.arena.y-3.0
	if is_instance_valid(fire):
		fire.visible = false
		fire.position = explosion_at - fire.size * 0.5
	game.ship.visible = false
	queue_redraw()

## UVs retain the armor, canopy, blue lights and upgrade hardpoints. Shared
## vertices bend together until the tear phase, preventing an early tile effect.
## Exactly 240 triangles are reused for the full animation at every tier.
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
				pieces.append({"shape": points, "uv": uv, "offset": center, "spin": sin(float(pieces.size())*13.7)*3.5})

func animation_age() -> float:
	return clampf(DURATION-game.death_time, 0.0, DURATION)

## Gunfire ignites immediately; impacts and horizons visibly stress the metal
## first. A black-hole fireball is still masked by its opaque horizon.
func step(_delta: float) -> void:
	if game.death_time <= 0.0:
		if is_instance_valid(fire):
			fire.visible = false
		queue_redraw()
		return
	var delay := 0.0 if cause == "shot" else 0.40
	if not exploded and animation_age() >= delay:
		exploded = true
		explosion_age = 0.0
		game.sound.play_effect("burst")
		game.combat.vibrate("hit")
	if exploded:
		explosion_age = animation_age()-delay
	if is_instance_valid(fire):
		fire.visible = exploded and explosion_age < 1.2
		fire.material.set_shader_parameter("age", maxf(explosion_age, 0.0))
	queue_redraw()

func clear() -> void:
	pieces.clear()
	exploded = false
	explosion_age = -1.0
	if is_instance_valid(fire):
		fire.visible = false
	queue_redraw()

## The background refraction pass consumes this expanding wave. Its front
## travels beyond the farthest corner before the menu appears, never stopping
## at an arbitrary visible ring. No outline is drawn over the game objects.
func warp_state() -> Dictionary:
	if game == null or game.death_time <= 0.0:
		return {}
	var progress := clampf((animation_age()-0.90)/(DURATION-0.90), 0.0, 1.0)
	if progress <= 0.0:
		return {}
	var farthest := 0.0
	for corner in [Vector2.ZERO, Vector2(game.arena.x,0), game.arena, Vector2(0,game.arena.y)]:
		farthest = maxf(farthest, explosion_at.distance_to(corner))
	return {"at": explosion_at, "radius": 20.0 + pow(progress,0.8)*farthest*1.45,
		"strength": 24.0*(1.0-smoothstep(0.70,1.0,progress)), "fade": 1.0-progress}

## A continuous mapping bends the whole hull before any triangle separates.
## Black holes stretch the nose and bow the metal toward the core; ramming
## folds the impacted hull across its width before the explosion pulls it apart.
func strained_vertex(point: Vector2, age: float) -> Vector2:
	var stress := smoothstep(0.0,0.46,age)
	var axis: Vector2 = (game.death_target-game.death_origin).normalized() if cause == "black" else Vector2.UP.rotated(game.ship.rotation)
	if axis.length_squared() < 0.1:
		axis = Vector2.UP.rotated(game.ship.rotation)
	var side: Vector2 = axis.orthogonal()
	var along := point.dot(axis)
	var across := point.dot(side)
	if cause == "black":
		return axis*(along*(1.0+stress*1.3)+across*across*stress*0.022)+side*across*(1.0-stress*0.5)
	return axis*(along*(1.0-stress*0.32)+sin(across*0.07)*stress*8.0)+side*across*(1.0+stress*0.18)

func _draw() -> void:
	if game == null or game.death_time <= 0.0:
		return
	var age := animation_age()
	for i in range(pieces.size()):
		# A fully consumed panel has zero area. Omit it instead of asking the
		# renderer to triangulate three identical points at the event horizon.
		if cause == "black" and age >= 1.32+float(i%5)*0.020:
			continue
		var piece: Dictionary = pieces[i]
		var offset: Vector2 = piece.offset
		var snap := maxf(0.0,age-0.30-float(i%7)*0.018)
		var bent_center := strained_vertex(offset,age)
		var transformed := PackedVector2Array()
		var alpha := 1.0
		for point in piece.shape:
			var vertex := strained_vertex(offset+point,age)
			# The fold is continuous up to the snap; individual panels then curl
			# around their own center as their newly torn edges become visible.
			vertex = bent_center+(vertex-bent_center).rotated(piece.spin*snap)
			if cause == "black":
				var swallow := clampf((age-0.24-float(i%5)*0.020)/1.08,0.0,1.0)
				var relative: Vector2 = game.death_origin+vertex-game.death_target
				vertex = game.death_target+relative.rotated(swallow*0.42)*(1.0-swallow*swallow)
			else:
				var crush := clampf(age/0.40,0.0,1.0)
				var direction := (offset+Vector2(0.001,0)).normalized()
				vertex += game.death_origin.lerp(explosion_at,crush)+direction*snap*snap*(75.0+float(i%7)*24.0)
				alpha = 1.0-smoothstep(0.75,1.75,age)
			transformed.append(vertex)
		# Just before complete swallowing, float precision can make a tiny
		# triangle collinear. Subpixel plates are invisible and must not reach
		# the renderer's polygon triangulator as degenerate geometry.
		if absf((transformed[1]-transformed[0]).cross(transformed[2]-transformed[0])) < 0.02:
			continue
		# Triangulate around a local origin: world-sized coordinates otherwise
		# lose precision while the remaining plate is only a fraction of a pixel.
		var center := (transformed[0]+transformed[1]+transformed[2])/3.0
		for vertex_index in range(3):
			transformed[vertex_index] -= center
		draw_set_transform(center)
		draw_polygon(transformed,PackedColorArray([Color(1,1,1,alpha)]),piece.uv,Artwork.FIGHTER_TEXTURE)
	draw_set_transform(Vector2.ZERO)
