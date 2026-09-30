extends Node2D
## A finite chain travels as a visible plasma stream. Damage happens at the
## advancing tip, never when a target is selected or a ribbon starts drawing.
const StreamShader = preload("res://shaders/electron_stream.gdshader")
const TIP_SPEED := 340.0
const TRACE_LIFE := 1.1
const MAX_LINKS := 10
const MAX_POINTS := 180
const MAX_SPARKS := 18
const MAX_HOP_TIME := 4.0
var game: Node2D
var pending: Array[Dictionary] = []
var links: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var active: Dictionary = {}
var last_point := Vector2.ZERO
var tip := Vector2.ZERO
var age := 0.0
var hop_time := 0.0
var serial := 0
var stream: MeshInstance2D
var stream_material: ShaderMaterial
var cores: Array = []

func _init() -> void:
	z_index = 24

func _ready() -> void:
	stream = MeshInstance2D.new()
	stream_material = ShaderMaterial.new()
	stream_material.shader = StreamShader
	stream.material = stream_material
	add_child(stream)

func clear() -> void:
	pending.clear()
	links.clear()
	sparks.clear()
	active.clear()
	cores.clear()
	hop_time = 0.0
	if is_instance_valid(stream): stream.mesh = null
	queue_redraw()

## Select the nearest forward gun column first, then visit nearest neighbors.
## The boss is last so surviving guards have time to lose their shield gate.
func fire() -> bool:
	if not pending.is_empty() or not active.is_empty():
		return false
	var candidates: Array[Dictionary] = []
	for actor in game.enemies + game.asteroids:
		var kind := "enemy" if game.enemies.has(actor) else "rock"
		if game.target_is_exposed(actor, kind):
			candidates.append({"id": actor.get_instance_id(), "kind": kind, "at": actor.position})
	var first: Array = candidates.filter(func(item: Dictionary) -> bool: return item.kind == "enemy")
	if first.is_empty(): first = candidates.duplicate()
	last_point = game.ship.muzzle_position(game.weapons.level, 0, true)
	if not first.is_empty():
		first.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ax: float = absf(a.at.x-last_point.x)
			var bx: float = absf(b.at.x-last_point.x)
			return ax < bx if not is_equal_approx(ax,bx) else a.at.distance_squared_to(last_point) < b.at.distance_squared_to(last_point))
		pending.append(first[0])
		candidates.erase(first[0])
		var point: Vector2 = first[0].at
		while not candidates.is_empty():
			candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.at.distance_squared_to(point) < b.at.distance_squared_to(point))
			var next: Dictionary = candidates.pop_front()
			pending.append(next)
			point = next.at
	if is_instance_valid(game.boss) and game.target_is_exposed(game.boss, "boss"):
		pending.append({"id": game.boss.get_instance_id(), "kind": "boss", "at": game.boss.body_position})
	if pending.is_empty(): return false
	age = 0.0
	tip = last_point
	game.sound.play_effect("rift")
	game.combat.vibrate("enemy")
	return true

## Identity plus current collection membership prevents a destroyed/recycled
## actor from receiving a late hit. A moving target is pursued from the current
## tip, so its movement never teleports an already visible section of plasma.
func live_target(entry: Dictionary) -> Node2D:
	var actor = instance_from_id(entry.id)
	if not is_instance_valid(actor) or actor.is_queued_for_deletion(): return null
	if entry.kind == "enemy" and not game.enemies.has(actor): return null
	if entry.kind == "rock" and not game.asteroids.has(actor): return null
	if entry.kind == "boss" and actor != game.boss: return null
	return actor if game.target_is_exposed(actor,entry.kind) else null

func begin_hop() -> bool:
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_front()
		if not is_instance_valid(live_target(entry)): continue
		active = entry
		hop_time = 0.0
		serial += 1
		tip = last_point
		links.append({"points": [tip], "life": TRACE_LIFE, "serial": serial})
		if links.size() > MAX_LINKS: links.pop_front()
		return true
	return false

## One inventory item powers the original finite target list. The tip advances
## at a fixed readable speed; distance, not a timer, decides the time of impact.
func step(delta: float) -> void:
	age += delta
	cores = game.gravity_fields.active_wells()
	for spark in sparks.duplicate():
		spark.life -= delta
		if spark.life <= 0.0: sparks.erase(spark)
	for link in links.duplicate():
		if not active.is_empty() and link.serial == serial: continue
		link.life -= delta
		if link.life <= 0.0: links.erase(link)
	if active.is_empty(): begin_hop()
	if not active.is_empty():
		var actor := live_target(active)
		hop_time += delta
		if not is_instance_valid(actor) or hop_time > MAX_HOP_TIME:
			# Continue from the visible tip if another weapon removed this target.
			last_point = tip
			active.clear()
		else:
			advance_tip(actor,delta)
	refresh_mesh()
	queue_redraw()

## Each short pursuit segment bends gently toward a moving target while the
## steering wave rolls slowly. The resulting trail is a smooth roaming hose,
## rather than instant straight lightning links. Core detours keep their exact
## geometry: decorative curves are reserved for open space.
func advance_tip(actor: Node2D, delta: float) -> void:
	var target: Vector2 = actor.body_position if active.kind == "boss" else actor.position
	var route: Array[Vector2] = game.route_energy_link(tip,target)
	if route.is_empty():
		finish_blocked()
		return
	var budget := TIP_SPEED * delta
	var points: Array = links.back().points
	var radius: float = game.target_radius(actor,active.kind)
	var target_reachable: bool = route.back().distance_to(target) < 1.0
	for index in range(0,route.size()-1,2):
		var from: Vector2 = route[index]
		var end: Vector2 = route[index+1]
		var vector := end-from
		var distance := vector.length()
		if distance < 0.001: continue
		# Long clear segments get a broad curl; near-horizon arc chords remain
		# unchanged. A fixed subdivision cap keeps crowded fields inexpensive.
		var subdivisions := clampi(ceili(distance/10.0),1,96)
		var amplitude := minf(40.0,distance*0.065) if route.size() == 2 and distance > 55.0 else 0.0
		var side := vector.normalized().orthogonal()
		var previous := from
		for subdivision in range(1,subdivisions+1):
			var t := float(subdivision)/subdivisions
			var bend := sin(t*PI)*sin(t*TAU*1.35-age*4.0+serial*0.83)*amplitude
			var candidate := from+vector*t+side*bend
			var step_length := previous.distance_to(candidate)
			if step_length > budget:
				candidate = previous.move_toward(candidate,budget)
				step_length = budget
			var obstruction: Dictionary = game.EnergyOptics.first_core(previous,candidate,cores)
			if not obstruction.is_empty():
				tip = obstruction.at
				points.append(tip)
				finish_blocked()
				return
			# Contact is measured against the visible swept tip, not a target's
			# stale launch-time position. No damage travels ahead of the light.
			var contact := Geometry2D.get_closest_point_to_segment(target,previous,candidate)
			if target_reachable and contact.distance_to(target) <= radius:
				tip = contact
				points.append(tip)
				contact_target(actor,target)
				return
			tip = candidate
			if points.back().distance_to(tip) > 2.5: points.append(tip)
			if points.size() > MAX_POINTS: points.pop_front()
			budget -= step_length
			if budget <= 0.001: return
			previous = candidate
	# A gravity route may end at an absorbing horizon, not at the target.
	if not target_reachable: finish_blocked()

func finish_blocked() -> void:
	last_point = tip
	active.clear()
	# An absorbed stream has no energy to emerge on the far side and continue
	# chaining. Keep only its fading trail; no hidden target receives damage.
	pending.clear()

## Melt through the existing asteroid removal path, explicitly suppressing
## fragments. Boss damage stays one cannon hit and still honors alien guards.
func contact_target(actor: Node2D, target: Vector2) -> void:
	sparks.append({"at": tip, "life": 0.62, "seed": float(serial)*1.37})
	if sparks.size() > MAX_SPARKS: sparks.pop_front()
	last_point = target
	var kind: String = active.kind
	active.clear()
	if kind == "rock": game.hit_asteroid(actor,actor.health,false)
	elif kind == "enemy": game.damage_target(actor,"enemy",actor.health)
	elif actor == game.boss: game.damage_target(actor,"boss",3)

## A single reusable surface renders all filled plasma ribbons. Explicit
## triangles stay valid when two curls overlap; no polygon triangulation or
## per-segment draw call explosion occurs on a busy phone screen.
func refresh_mesh() -> void:
	if not is_instance_valid(stream): return
	stream_material.set_shader_parameter("clock",age)
	var field_data := PackedVector4Array()
	for index in range(8):
		if index < cores.size():
			var well: Node2D = cores[index]
			field_data.append(Vector4(well.well_position.x,well.well_position.y,game.gravity_fields.core_radius(well),0.0))
		else: field_data.append(Vector4.ZERO)
	stream_material.set_shader_parameter("cores",field_data)
	stream_material.set_shader_parameter("core_count",mini(8,cores.size()))
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for link in links:
		var points: Array = link.points
		var along := 0.0
		var opacity := clampf(float(link.life)/0.65,0.0,1.0)
		for index in range(points.size()-1):
			var from: Vector2 = points[index]
			var to: Vector2 = points[index+1]
			var direction := (to-from).normalized()
			var before := (from-Vector2(points[index-1])).normalized() if index > 0 else direction
			var after := (Vector2(points[index+2])-to).normalized() if index+2 < points.size() else direction
			var from_side := (before+direction).normalized().orthogonal()*13.0
			var to_side := (direction+after).normalized().orthogonal()*13.0
			var length := from.distance_to(to)/70.0
			var quad := [from-from_side,from+from_side,to-to_side,to-to_side,from+from_side,to+to_side]
			var uv := [Vector2(along,0),Vector2(along,1),Vector2(along+length,0),Vector2(along+length,0),Vector2(along,1),Vector2(along+length,1)]
			for corner in range(6):
				vertices.append(Vector3(quad[corner].x,quad[corner].y,0))
				uvs.append(uv[corner])
				colors.append(Color(1,1,1,opacity))
			along += length
	if vertices.is_empty():
		stream.mesh = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	stream.mesh = mesh

## Contact blooms and little hot fragments linger after the target melts. They
## are cosmetic, deterministic, and capped separately from gameplay particles.
func _draw() -> void:
	if not active.is_empty():
		draw_circle(tip,12.0,Color(0.32,0.42,1.0,0.14))
		draw_circle(tip,5.0,Color(0.35,0.92,1.0,0.64))
		draw_circle(tip,2.5,Color(0.9,1.0,1.0,0.94))
	for spark in sparks:
		var elapsed: float = 0.62-spark.life
		var fade: float = spark.life/0.62
		draw_circle(spark.at,18.0*fade,Color(0.33,0.65,1.0,0.17*fade))
		draw_circle(spark.at,5.0*fade,Color(0.9,1.0,1.0,fade))
		for index in range(14):
			var direction := Vector2.from_angle(float(index)*2.39996+spark.seed)
			var distance := elapsed*(45.0+float(index%4)*21.0)
			var at: Vector2 = spark.at+direction*distance
			var side := direction.orthogonal()
			var hot := Color(0.5+0.45*fade,0.85,1.0,fade)
			draw_colored_polygon(PackedVector2Array([at+direction*(2.0+4.0*fade),at+side*1.4*fade,at-direction*3.0*fade,at-side*1.4*fade]),hot)
