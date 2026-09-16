extends SceneTree
## Exercises finite gravity lifetimes across real frame boundaries. In particular,
## queued enemies must be freed during the pull, and shield contact must never
## prevent an otherwise expired boss field from ending.

var game: Node2D
var passed := 0
var failed := 0

## Defer construction until the root viewport has entered the tree.
func _initialize() -> void:
	call_deferred("run")

## Keep each independent scenario visible in the test log.
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)

## Disable random arrivals, but use the real game update order.
func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000
	game.boss_timer = 1000
	game.asteroid_timer = 1000
	game.progress.vibration_enabled = false

## Create a fully charged well at the end of its rocket's travel.
func maximum_well(at: Vector2) -> Node2D:
	var well = game.PlayerWell.new()
	well.game = game
	well.charge = 5.0
	well.well_position = at
	well.cannon_position = at
	game.add_child(well)
	game.lingering_wells.append(well)
	well.step(0.0)
	return well

## Advance real deletion boundaries without waiting for wall-clock gameplay time.
func frames(count: int, resist: bool = false) -> void:
	for frame in range(count):
		if resist:
			for well in game.lingering_wells:
				well.resist()
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
		await process_frame

## Build a residual boss field whose core or edge contact is protected by shield.
func protected_field(kind: String, at: Vector2) -> Node2D:
	var well = game.Boss.new()
	well.game = game
	well.kind = kind
	well.lingering = true
	well.phase = "active"
	well.well_position = at
	well.well_duration = 0.1
	game.add_child(well)
	game.lingering_wells.append(well)
	game.combat.shield_time = 10
	return well

## Run against a disposable save and exercise the maximum size, death, revival,
## merging, and timer completion without depending on rendering performance.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("large-well-review-record.cfg"):
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	fresh()
	game.combat.shield_time = 30
	for i in range(14):
		game.spawn_enemy(Vector2(50 + (i % 7) * 70, 250 + (i / 7) * 200), Vector2.ZERO)
	var well := maximum_well(Vector2(270, 420))
	check(is_equal_approx(well.remaining, 7.5), "maximum charge lasts 7.5 seconds")
	await frames(660)
	check(game.state == game.State.PLAYING and game.lingering_wells.is_empty() and game.combat.returns.is_empty(), "maximum field frees swallowed actors and completes restoration")
	fresh()
	well = maximum_well(game.ship.position)
	await frames(125)
	check(game.state == game.State.LOST and game.death_time == 0 and game.interface.primary.visible, "unprotected maximum core completes loss animation instead of hanging")
	fresh()
	game.weapons.level = 2
	game.ship.position = Vector2(270, 500)
	well = maximum_well(Vector2(270, 500))
	for i in range(5):
		game.spawn_enemy(Vector2(240 + i * 10, 520), Vector2.ZERO)
	await frames(1)
	check(game.state == game.State.PLAYING and game.lives == 1 and game.weapons.level == 0, "maximum core consumes one emergency upgrade without invalid actors")
	await frames(660, true)
	check(game.state == game.State.PLAYING and game.lingering_wells.is_empty() and game.combat.returns.is_empty(), "revived pilot can resist until field and restoration finish")
	fresh()
	game.combat.shield_time = 30
	well = maximum_well(Vector2(270, 420))
	game.begin_boss("black")
	game.boss.phase = "active"
	game.boss.well_position = Vector2(285, 420)
	game.boss.phase_time = 0.0
	game.gravity_fields.step(0.0)
	check(is_equal_approx(well.remaining, 11.5) and game.boss.phase == "firefight", "live boss merger preserves combined lifetime and boss identity")
	game.boss.cooldown = 1000
	game.boss.shot_timer = 1000
	await frames(850)
	check(game.state == game.State.PLAYING and game.lingering_wells.is_empty() and game.combat.returns.is_empty(), "merged maximum field finishes without trapping the director")
	fresh()
	well = protected_field("black", game.ship.position)
	well.step(0.2)
	check(not game.lingering_wells.has(well), "shielded black core contact cannot prolong an expired field")
	fresh()
	game.ship.position.y = game.arena.y - 5
	well = protected_field("white", game.ship.position - Vector2(0, 200))
	well.step(0.2)
	check(not game.lingering_wells.has(well), "shielded white edge contact cannot prolong an expired field")
	game.free()
	await process_frame
	print("LARGE WELL REVIEW: %d passed; %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
