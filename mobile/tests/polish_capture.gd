extends SceneTree
## Actual rendered frames for depth ordering, disintegration and laser contacts.
var game: Node2D
var directory: String

## Wait for root setup.
func _initialize() -> void:
	call_deferred("run")

## Capture all layers after the render server has completed the frame.
func shot(label: String) -> void:
	game.interface.refresh()
	game.refresh_space()
	game.queue_redraw()
	game.combat.queue_redraw()
	game.gravity_fields.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))

## Stage representative states without changing the real save or score.
func run() -> void:
	directory=OS.get_environment("ALIEN_CAPTURE_DIR")
	if directory.is_empty() or not OS.get_environment("ALIEN_SAVE_PATH").ends_with("polish-capture-record.cfg"):
		quit(1)
		return
	root.size=Vector2i(540,960)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled=false
	game.progress.vibration_enabled=false
	game.start_run()
	for i in range(4):
		game.spawn_enemy(Vector2(160+i*70,300),Vector2.ZERO)
	game.begin_boss("black")
	game.boss.step(1.5)
	game.update_enemies(0.3)
	game.combat.equip_laser()
	game.combat.press(0,game.ship.position)
	game.update_laser(0.01)
	await shot("guard-shield-laser")
	game.combat.shield_time=10
	await shot("shield-warp-ring")
	game.start_run("white")
	game.boss.phase="active"
	game.boss.well_position=Vector2(180,600)
	game.combat.update_attitudes(0.5)
	await shot("white-resistance")
	game.start_run()
	var well=game.PlayerWell.new()
	well.game=game
	well.well_position=Vector2(270,650)
	well.cannon_position=well.well_position
	game.add_child(well)
	game.lingering_wells.append(well)
	well.step(0)
	game.ship.position=Vector2(290,720)
	game.instant_loss("Caught in a black hole.")
	game._process(0.2)
	await shot("black-crumbling")
	game._process(0.35)
	await shot("black-horizon")
	for reason in ["An alien collided with your ship.","The white hole pushed you into the boundary."]:
		game.start_run()
		if "white" in reason:
			game.ship.position.y=game.arena.y-20
		game.instant_loss(reason)
		game._process(0.25)
		await shot("crumble-"+("white" if "white" in reason else "ram"))
		game._process(0.35)
		await shot("explosion-"+("white" if "white" in reason else "ram"))
	game.start_run()
	game.sector_light=Vector3(-0.4,-0.4,1).normalized()
	for index in range(6):
		game.visual_time=(float(index)*(game.arena.y+2200)+430-game.arena.y*0.4)/22
		await shot("planet-"+str(index))
	game.gravity_fields.add_exit(Vector2(170,400),"black",1.8)
	game.gravity_fields.add_exit(Vector2(370,600),"white",1.8)
	game.gravity_fields.visual_step(0.25)
	await shot("exit-pulses")
	game.start_run()
	for enemy in game.enemies.duplicate():
		game.remove_enemy(enemy)
	for rock in game.asteroids.duplicate():
		game.remove_asteroid(rock)
	game.spawn_asteroid(Vector2(125,430),Vector2.ZERO,20)
	game.spawn_asteroid(Vector2(270,430),Vector2.ZERO,31)
	game.spawn_asteroid(Vector2(420,430),Vector2.ZERO,43)
	await shot("asteroid-materials")
	game.free()
	await process_frame
	quit()
