extends SceneTree
## Material-only damage must never alter simulation transforms or hardpoints.
const Alien = preload("res://scripts/enemy.gd")
const Ship = preload("res://scripts/ship.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		push_error("FAIL: " + description)

func run() -> void:
	root.size = Vector2i(540,960)
	var scene := Node2D.new()
	root.add_child(scene)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0a1222")
	backdrop.size = Vector2(540,960)
	scene.add_child(backdrop)
	var aliens: Array[Node2D] = []
	for row in range(3):
		for column in range(3):
			var alien := Alien.new()
			alien.position = Vector2(120+column*150,190+row*160)
			alien.health = 3-row
			scene.add_child(alien)
			alien.set_palette([Color("b34cff"),Color("ff754b"),Color("53ead3")][column])
			alien.update_damage_visual(0.8)
			aliens.append(alien)
	var alien: Node2D = aliens[6]
	var position: Vector2 = alien.position
	var rotation: float = alien.rotation
	var muzzle: Vector2 = alien.rear_muzzle_position()
	var old_count: int = get_node_count()
	for index in range(180):
		alien.update_damage_visual(1.0/60.0)
	check(alien.position == position and alien.rotation == rotation and alien.rear_muzzle_position() == muzzle, "damaged-alien wobble leaves physics and aft cannon unchanged")
	check(get_node_count() == old_count, "continuous wreckage/smoke creates no per-frame nodes")
	check(not aliens[3].damage_visual.cloud.visible and aliens[6].damage_visual.cloud.visible, "first hit chips armor; second hit adds smoke")
	check(aliens[1].hull_surface.get_shader_parameter("emission_color") == Color("ff754b"), "swarm palette reaches the alien hull material")
	check(aliens[1].engine_burn.jets[0].material.get_shader_parameter("engine_color") == Color("ff754b"), "engine emission matches the swarm hull fittings")
	var player := Ship.new()
	player.position = Vector2(270,740)
	player.weapon_level = 2
	scene.add_child(player)
	player.set_hull_health(1)
	player.update_damage_visual(0.7)
	var player_muzzle: Vector2 = player.muzzle_position(2,1)
	var player_position: Vector2 = player.position
	player.update_damage_visual(0.8)
	check(player.muzzle_position(2,1) == player_muzzle and player.position == player_position, "player damage leaves steering position and gun hardpoints unchanged")
	check(player.damage_visual.cloud.visible, "one remaining player life produces smoke")
	player.set_hull_health(3)
	check(not player.damage_visual.cloud.visible and player.hull_surface.get_shader_parameter("hull_damage") == 0.0, "health repair removes scars and smoke without replacing the ship")
	player.set_hull_health(1)
	player.reset_ship(player_position)
	check(player.hull_health == 3 and player.damage_visual.stage == 0, "a new run resets all damage presentation")
	player.weapon_level = 2
	player.set_hull_health(1)
	player.update_damage_visual(0.8)
	var capture := OS.get_environment("ALIEN_HULL_CAPTURE")
	if not capture.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture) == OK, "actual hull stages and swarm palettes captured")
	scene.free()
	await process_frame
	print("HULL DAMAGE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
