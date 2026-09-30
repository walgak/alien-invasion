extends SceneTree
## Visible-tip timing, moving/deleted targets and bounded filled-plasma geometry.
var game: Node2D
var failures := 0
var checks := 0
var directory: String
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures += 1
func fresh() -> void:
	game.start_run()
	game.wave_timer = 10000
	game.asteroid_timer = 10000
	game.boss_timer = 10000
func advance(seconds: float) -> void:
	for frame in range(ceili(seconds*60.0)): game.electron_beam.step(1.0/60.0)
func capture(label: String) -> void:
	if directory.is_empty(): return
	game.refresh_space()
	game.queue_redraw()
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))
func field(kind: String, at: Vector2) -> Node2D:
	var well: Node2D = game.Boss.new()
	well.game = game
	well.kind = kind
	well.phase = "active"
	well.lingering = true
	well.well_position = at
	well.phase_time = 20.0
	game.add_child(well)
	game.lingering_wells.append(well)
	return well
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("electron-stream-record.cfg"):
		quit(1)
		return
	directory = OS.get_environment("ALIEN_CAPTURE_DIR")
	root.size = Vector2i(540,960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	fresh()
	var enemy: Node2D = game.spawn_enemy(Vector2(270,230),Vector2.ZERO)
	check(game.fire_electron(),"visible target starts an electron chain")
	advance(0.6)
	check(game.enemies.has(enemy) and enemy.health == 3,"distant target takes no damage ahead of the advancing tip")
	check(not game.electron_beam.active.is_empty() and not game.fire_electron(),"a moving tip reserves its one active inventory chain")
	var trace: Array = game.electron_beam.links.back().points
	var curvature := 0.0
	for point in trace: curvature = maxf(curvature,absf(point.x-trace[0].x))
	check(curvature > 2.0,"plasma trail visibly curls instead of drawing a straight bolt")
	check(game.electron_beam.stream.mesh != null,"filled plasma triangle mesh exists during travel")
	await capture("01-curved-flight")
	for frame in range(240):
		game.electron_beam.step(1.0/60.0)
		if not game.enemies.has(enemy): break
	check(not game.enemies.has(enemy) and not game.electron_beam.sparks.is_empty(),"tip contact destroys the alien and creates persistent hot sparks")
	await capture("02-contact-sparks")
	advance(2.0)
	check(game.electron_beam.links.is_empty() and game.electron_beam.sparks.is_empty() and game.electron_beam.stream.mesh == null,"spent chain fades without leaving geometry or particles")
	fresh()
	game.begin_boss("asteroid")
	game.boss.phase = "firefight"
	game.boss.body_position = Vector2(270,180)
	var original: float = game.boss.health
	for at in [Vector2(270,500),Vector2(110,380),Vector2(410,330)]:
		enemy = game.spawn_enemy(at,Vector2.ZERO)
		enemy.shield_guard = true
	game.spawn_asteroid(Vector2(170,260),Vector2.ZERO,45,70)
	game.fire_electron()
	advance(10.0)
	check(game.enemies.is_empty() and game.asteroids.is_empty(),"one finite chain clears its aliens and melts rocks without fragments")
	check(game.boss.health == original-3,"boss is hit last exactly once for cannon damage after its guards")
	fresh()
	var moving: Node2D = game.spawn_enemy(Vector2(270,420),Vector2.ZERO)
	var trailing: Node2D = game.spawn_enemy(Vector2(370,230),Vector2.ZERO)
	game.fire_electron()
	advance(0.2)
	var old_tip: Vector2 = game.electron_beam.tip
	moving.position.x += 130.0
	game.electron_beam.step(1.0/60.0)
	check(game.electron_beam.tip.distance_to(old_tip) <= game.electron_beam.TIP_SPEED/60.0+0.1,"moving targets never teleport the advancing tip")
	game.enemies.erase(moving)
	moving.queue_free()
	await process_frame
	advance(5.0)
	check(not game.enemies.has(trailing),"deleted targets are skipped safely and the remaining chain continues")
	fresh()
	enemy = game.spawn_enemy(Vector2(270,220),Vector2.ZERO)
	var well := field("black",Vector2(270,470))
	game.fire_electron()
	advance(4.0)
	check(game.enemies.has(enemy),"black horizon absorbs the stream before it can damage a hidden target")
	check(game.electron_beam.active.is_empty() and game.electron_beam.pending.is_empty(),"absorbed stream cannot restart beyond the event horizon")
	fresh()
	for index in range(45):
		game.spawn_enemy(Vector2(55+(index%6)*83,150+(index/6)*78),Vector2.ZERO)
	game.fire_electron()
	var bounded := true
	for frame in range(2000):
		game.electron_beam.step(1.0/60.0)
		bounded = bounded and game.electron_beam.links.size() <= game.electron_beam.MAX_LINKS and game.electron_beam.sparks.size() <= game.electron_beam.MAX_SPARKS
		for link in game.electron_beam.links: bounded = bounded and link.points.size() <= game.electron_beam.MAX_POINTS
	check(bounded,"crowded chains keep trail and spark allocations within fixed caps")
	game.electron_beam.clear()
	check(game.electron_beam.active.is_empty() and game.electron_beam.pending.is_empty() and game.electron_beam.links.is_empty() and game.electron_beam.sparks.is_empty(),"reset clears every pending hit and visual")
	game.free()
	await process_frame
	print("ELECTRON STREAM: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
