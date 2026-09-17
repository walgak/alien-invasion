extends Node2D
## Renders the 2D simulation through one real 3D world. Physics remains in the
## proven portrait plane; these meshes mirror actor transforms every frame.

var game: Node2D
var viewport := SubViewport.new()
var world_root := Node3D.new()
var camera := Camera3D.new()
var screen := Sprite2D.new()
var models: Dictionary[int, Node3D] = {}
var particle_mesh := MultiMeshInstance3D.new()
var particle_multi := MultiMesh.new()
var materials: Dictionary = {}

## Build a transparent, orthographic 3D stage with physical lights and metallic materials.
func setup(owner_game: Node2D) -> void:
	game = owner_game
	z_index = 2
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(world_root)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025,0.035,0.075,0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.ambient_light_color = Color("44506b")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	world_root.add_child(environment_node)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0,0,520)
	camera.current = true
	world_root.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28,-34,18)
	key.light_color = Color("c9dcff")
	key.light_energy = 0.82
	key.shadow_enabled = true
	world_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(34,28,-22)
	fill.light_color = Color("8e62c7")
	fill.light_energy = 0.34
	fill.shadow_enabled = false
	world_root.add_child(fill)
	var violet := OmniLight3D.new()
	violet.position = Vector3(-170,250,120)
	violet.light_color = Color("9e54ff")
	violet.light_energy = 1.35
	violet.omni_range = 520.0
	world_root.add_child(violet)
	particle_multi.transform_format=MultiMesh.TRANSFORM_3D
	particle_multi.use_colors=true
	var spark:=SphereMesh.new(); spark.radius=1.0; spark.height=2.0; spark.radial_segments=6; spark.rings=3
	particle_multi.mesh=spark
	particle_mesh.multimesh=particle_multi
	var debris:=StandardMaterial3D.new(); debris.vertex_color_use_as_albedo=true; debris.metallic=0.35; debris.roughness=0.28
	particle_mesh.material_override=debris
	world_root.add_child(particle_mesh)
	add_child(screen)
	screen.texture = viewport.get_texture()
	screen.centered = true
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resize(game.arena)

## Match the device viewport and keep one world unit equal to one gameplay pixel.
func resize(size: Vector2) -> void:
	viewport.size = Vector2i(maxi(1,int(size.x)),maxi(1,int(size.y)))
	camera.size = size.y
	screen.position = size*0.5

## A physically shaded material supplies true specular response and emission.
func finish(name: String, color: Color, metallic := 0.82, roughness := 0.25, emission := Color.TRANSPARENT) -> StandardMaterial3D:
	if materials.has(name):
		return materials[name]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	if emission.a > 0.0:
		result.emission_enabled = true
		result.emission = Color(emission.r,emission.g,emission.b)
		result.emission_energy_multiplier = 1.25
	materials[name] = result
	return result

## Extrude a top-view polygon into a watertight 3D armor plate.
func extrude(points: PackedVector2Array, depth: float, surface: Material, z := 0.0) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(points)
	for index in range(0,triangles.size(),3):
		for order in [0,1,2]:
			var p: Vector2 = points[triangles[index+order]]
			tool.set_normal(Vector3(0,0,1))
			tool.add_vertex(Vector3(p.x,-p.y,z+depth*0.5))
		for order in [2,1,0]:
			var p: Vector2 = points[triangles[index+order]]
			tool.set_normal(Vector3(0,0,-1))
			tool.add_vertex(Vector3(p.x,-p.y,z-depth*0.5))
	for index in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index+1)%points.size()]
		var normal2 := (b-a).normalized().orthogonal()
		var normal := Vector3(normal2.x,-normal2.y,0)
		var vertices := [Vector3(a.x,-a.y,z-depth*0.5),Vector3(b.x,-b.y,z-depth*0.5),Vector3(b.x,-b.y,z+depth*0.5),Vector3(a.x,-a.y,z+depth*0.5)]
		for order in [0,1,2,0,2,3]:
			tool.set_normal(normal)
			tool.add_vertex(vertices[order])
	mesh = tool.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	return instance

func add_plate(root: Node3D, points: PackedVector2Array, depth: float, surface: Material, z := 0.0) -> void:
	root.add_child(extrude(points,depth,surface,z))

func add_orb(root: Node3D, at: Vector2, radius: float, surface: Material, z := 10.0) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius*2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	orb.mesh = sphere
	orb.material_override = surface
	orb.position = Vector3(at.x,-at.y,z)
	root.add_child(orb)
	return orb

## Assemble a layered player or alien fighter from extruded armor and emissive cores.
func fighter_model(player: bool) -> Node3D:
	var root := Node3D.new()
	root.rotation.x=0.13
	root.rotation.y=-0.08
	var armor := finish("player_armor" if player else "alien_armor",Color("405a73") if player else Color("3b3048"),0.9,0.24)
	var dark := finish("dark_armor",Color("242b3e"),0.92,0.2)
	var glow_color := Color("6ff8ef") if player else Color("bb63ff")
	var glow := finish("player_glow" if player else "alien_glow",Color("152a30") if player else Color("24122e"),0.25,0.22,glow_color)
	var hull := PackedVector2Array([Vector2(0,-38),Vector2(13,-11),Vector2(11,18),Vector2(0,31),Vector2(-11,18),Vector2(-13,-11)])
	add_plate(root,hull,10,armor,2)
	for side in [-1.0,1.0]:
		var wing := PackedVector2Array([Vector2(side*7,-14),Vector2(side*25,-22),Vector2(side*36,20),Vector2(side*26,15),Vector2(side*16,2),Vector2(side*12,25),Vector2(side*5,17)])
		add_plate(root,wing,7,dark,-1)
		add_plate(root,PackedVector2Array([Vector2(side*13,-7),Vector2(side*21,-12),Vector2(side*25,12),Vector2(side*18,7)]),4,glow,5)
	add_plate(root,PackedVector2Array([Vector2(0,-28),Vector2(5,-5),Vector2(3,17),Vector2(0,23),Vector2(-3,17),Vector2(-5,-5)]),5,glow,8)
	add_orb(root,Vector2(0,18),3.2,glow,11)
	return root

## Bosses use the same materials at a heavier scale and retain type-specific silhouettes.
func boss_model(kind: String) -> Node3D:
	var root := Node3D.new()
	root.rotation.x=0.11
	root.rotation.y=-0.06
	var accent := Color("a65cff") if kind in ["black","swarm"] else (Color("a9f4ff") if kind=="white" else Color("ff9a55"))
	var armor := finish("boss_"+kind,Color("44374f") if kind!="asteroid" else Color("574237"),0.93,0.23)
	var dark := finish("boss_dark",Color("29243a"),0.95,0.19)
	var glow := finish("boss_glow_"+kind,accent.darkened(0.72),0.35,0.18,accent)
	var hull := PackedVector2Array([Vector2(0,-64),Vector2(25,-28),Vector2(22,28),Vector2(0,59),Vector2(-22,28),Vector2(-25,-28)])
	add_plate(root,hull,18,armor,4)
	for side in [-1.0,1.0]:
		var reach := 92.0 if kind=="swarm" else 78.0
		var wing := PackedVector2Array([Vector2(side*14,-31),Vector2(side*(reach-23),-57),Vector2(side*reach,-37),Vector2(side*(reach-14),-8),Vector2(side*reach,31),Vector2(side*(reach-29),59),Vector2(side*43,13),Vector2(side*19,25)])
		add_plate(root,wing,13,dark,0)
		add_plate(root,PackedVector2Array([Vector2(side*23,-23),Vector2(side*(reach-28),-43),Vector2(side*(reach-34),-9),Vector2(side*(reach-27),28),Vector2(side*41,8)]),6,armor,9)
		add_orb(root,Vector2(side*32,10),9,glow,15)
	add_plate(root,PackedVector2Array([Vector2(0,-38),Vector2(8,-8),Vector2(7,29),Vector2(0,47),Vector2(-7,29),Vector2(-8,-8)]),7,glow,15)
	return root

## Low-poly displaced spheres give each rock genuine facets and specular crater rims.
func asteroid_model(radius: float, seed: int) -> Node3D:
	var root := Node3D.new()
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius*1.65
	sphere.radial_segments = 9
	sphere.rings = 5
	rock.mesh = sphere
	rock.scale = Vector3(1.0,0.92,0.72)
	rock.rotation = Vector3(0.45,float(seed%7)*0.31,0.18)
	rock.material_override = finish("rock",Color("514842"),0.18,0.78)
	root.add_child(rock)
	for i in range(3):
		var crater := add_orb(root,Vector2(cos(i*2.1+seed)*radius*0.42,sin(i*2.1+seed)*radius*0.38),radius*(0.12+i*0.025),finish("crater",Color("111118"),0.05,0.96),radius*0.55)
		crater.scale.z=0.25
	return root

func projectile_model(shot: Node2D) -> Node3D:
	var root := Node3D.new()
	var color := Color("ff624f") if shot.hostile else Color("65f9e0")
	if shot.kind=="doom": color=Color("a85cff")
	if shot.kind=="rocket": color=Color("ffad5e")
	add_orb(root,Vector2.ZERO,12.0 if shot.kind=="doom" else (5.0 if shot.kind=="rocket" else 3.4),finish("shot_"+shot.kind+str(shot.hostile),color.darkened(0.68),0.35,0.16,color),8)
	return root

## Create or reuse models, then mirror every simulation actor into the 3D stage.
func sync() -> void:
	if game==null: return
	var live: Dictionary[int,bool] = {}
	if game.ship.visible:
		sync_actor(game.ship,"ship",live)
	for enemy in game.enemies: sync_actor(enemy,"enemy",live)
	for rock in game.asteroids: sync_actor(rock,"rock",live)
	for shot in game.projectiles:
		if shot.kind!="laser": sync_actor(shot,"shot",live)
	if is_instance_valid(game.boss) and not game.boss.lingering:
		sync_actor(game.boss,"boss",live)
	for id in models.keys():
		if not live.has(id):
			models[id].queue_free()
			models.erase(id)
	sync_laser()
	sync_particles()

func sync_actor(actor: Node2D, type: String, live: Dictionary[int,bool]) -> void:
	var id := actor.get_instance_id()
	live[id]=true
	if not models.has(id):
		var model: Node3D
		if type=="ship": model=fighter_model(true)
		elif type=="enemy": model=fighter_model(false)
		elif type=="rock": model=asteroid_model(actor.radius,id)
		elif type=="boss": model=boss_model(actor.kind)
		else: model=projectile_model(actor)
		model.set_meta("render_type",type)
		world_root.add_child(model)
		models[id]=model
	var model: Node3D=models[id]
	var at: Vector2 = actor.body_position if type=="boss" else actor.position
	model.position=Vector3(at.x-game.arena.x*0.5,game.arena.y*0.5-at.y,12.0 if type in ["ship","enemy","boss"] else 8.0)
	model.rotation.z=-actor.rotation
	if type=="ship":
		var width: float=[1.0,1.13,1.28,1.45,1.38][clampi(game.weapons.level,0,4)]
		model.scale=Vector3(width,1.0,1.0)
	elif type=="shot":
		model.rotation.z=-actor.velocity.angle()-PI*0.5
		model.scale=Vector3.ONE*(1.0+0.08*sin(actor.age*28.0))

## The continuous laser is a chain of lit 3D cylinders, not a painted polyline.
func sync_laser() -> void:
	var id := -9001
	var active: bool = is_instance_valid(game.laser) and game.laser.visible and not game.laser.beam_segments.is_empty()
	if not active:
		if models.has(id): models[id].visible=false
		return
	if not models.has(id):
		var root:=Node3D.new(); root.set_meta("render_type","laser"); world_root.add_child(root); models[id]=root
	var root: Node3D=models[id]
	root.visible=true
	var segments: Array[Vector2]=game.laser.beam_segments
	var used:=0
	for i in range(0,mini(segments.size(),48),2):
		var a:Vector2=segments[i]; var b:Vector2=segments[i+1]
		var length:=a.distance_to(b)
		if length<0.5: continue
		var beam:MeshInstance3D
		if used<root.get_child_count():
			beam=root.get_child(used)
		else:
			beam=MeshInstance3D.new()
			var cylinder:=CylinderMesh.new()
			cylinder.top_radius=1.7; cylinder.bottom_radius=3.0; cylinder.radial_segments=8
			beam.mesh=cylinder; beam.material_override=finish("laser_3d",Color("bdfcff"),0.25,0.1,Color("68cfff"))
			root.add_child(beam)
		beam.visible=true
		(beam.mesh as CylinderMesh).height=length
		var mid:Vector2=a.lerp(b,0.5)
		beam.position=Vector3(mid.x-game.arena.x*0.5,game.arena.y*0.5-mid.y,15)
		beam.rotation.z=-(b-a).angle()+PI*0.5
		used+=1
	for index in range(used,root.get_child_count()):
		root.get_child(index).visible=false

## Existing deterministic explosion particles become lit 3D debris in one draw call.
func sync_particles() -> void:
	var count: int=game.particles.size()
	particle_multi.instance_count=count
	for i in range(count):
		var particle:Dictionary=game.particles[i]
		var at:Vector2=particle.position
		var radius:float=particle.radius
		particle_multi.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(radius*1.8,radius,radius)),Vector3(at.x-game.arena.x*0.5,game.arena.y*0.5-at.y,16)))
		var tint:Color=particle.tint; tint.a=particle.life/particle.duration
		particle_multi.set_instance_color(i,tint)
