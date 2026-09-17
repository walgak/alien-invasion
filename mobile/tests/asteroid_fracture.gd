extends SceneTree
## Exercise destruction through the game's public hit/update paths. Fragments
## must preserve the parent's ore and momentum without creating infinite debris.
var game: Node2D
var failures := 0
var passed := 0

## Defer setup until the root viewport and scene tree are available.
func _initialize() -> void:
	call_deferred("run")

## Report every behavior, allowing one run to expose independent regressions.
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

## Isolate each case from director spawns, previous fields, and earlier scores.
func fresh() -> void:
	game.start_run()
	game.wave_timer = 1000
	game.boss_timer = 1000
	game.asteroid_timer = 1000
	game.progress.vibration_enabled = false

## Build an actual player rocket and let its normal transition activate the well.
func player_field(at: Vector2) -> Node2D:
	var well = game.PlayerWell.new()
	well.game = game
	well.well_position = at
	well.cannon_position = at
	game.add_child(well)
	game.lingering_wells.append(well)
	well.step(0.0)
	return well

## Run deterministic gameplay checks with a disposable, explicitly named save.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("asteroid-fracture-record.cfg"):
		push_error("Use an isolated asteroid-fracture-record.cfg save for this test.")
		quit(1)
		return
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	fresh()
	var center := Vector2(270, 320)
	var velocity := Vector2(45, 170)
	var large: Node2D = game.spawn_asteroid(center, velocity, 43.0)
	check(large.health == 12, "large asteroid starts with its normal twelve-hit durability")
	game.hit_asteroid(large, large.health - 1)
	check(game.asteroids == [large] and large.health == 1 and game.score == 0,
		"nonfatal hits neither fracture nor award points")
	game.hit_asteroid(large)
	var mediums: Array = game.asteroids.duplicate()
	check(mediums.size() == 2 and large.is_queued_for_deletion(),
		"destroyed large asteroid is replaced by exactly two medium pieces")
	check(game.score == 25, "a destroyed parent awards twenty-five points once")
	game.hit_asteroid(large, 100)
	check(game.asteroids == mediums and game.score == 25,
		"duplicate same-frame hits cannot duplicate fragments or rewards")
	if mediums.size() == 2:
		var shape_ok := true
		var placement_ok := true
		var health_ok := true
		var material_ok := true
		var free_flight := true
		for child in mediums:
			shape_ok = shape_ok and is_equal_approx(child.radius, 31.0)
			placement_ok = placement_ok and child.position.distance_to(center) + child.radius <= 43.001
			placement_ok = placement_ok and child.previous_position.is_equal_approx(child.position)
			health_ok = health_ok and child.health == 8 and child.max_health == 8
			material_ok = material_ok and child.visual_kind == "ice"
			free_flight = free_flight and child.motion_phase == "flight" and child.fold_life == 0.0
		check(shape_ok and placement_ok, "medium pieces fit within the old footprint with valid swept-collision origins")
		check(health_ok, "medium fragments receive full size-based health rather than the parent's damage")
		check(material_ok, "ice ore stays ice when it fractures into smaller pieces")
		check(free_flight, "fragments immediately fly without replaying a boss tether")
		var average_velocity: Vector2 = (mediums[0].velocity + mediums[1].velocity) * 0.5
		var first_impulse: Vector2 = mediums[0].velocity - velocity
		var second_impulse: Vector2 = mediums[1].velocity - velocity
		check(average_velocity.is_equal_approx(velocity) and first_impulse.length() > 0.0
			and first_impulse.is_equal_approx(-second_impulse)
			and absf(first_impulse.normalized().dot(velocity.normalized())) < 0.001,
			"opposing sideways impulses separate fragments while preserving average momentum")

	# Destroy every generation with a hard bound so faulty recursive splitting fails
	# safely rather than hanging the test runner.
	var destroyed := 1
	var medium_count := 0
	var small_count := 0
	var descendants_ok := true
	while not game.asteroids.is_empty() and destroyed < 15:
		var rock: Node2D = game.asteroids.front()
		medium_count += int(is_equal_approx(rock.radius, 31.0))
		small_count += int(is_equal_approx(rock.radius, 20.0))
		descendants_ok = descendants_ok and rock.visual_kind == "ice"
		if rock.radius < 26.0:
			descendants_ok = descendants_ok and rock.health == 5 and rock.max_health == 5
		game.hit_asteroid(rock, rock.health)
		destroyed += 1
	check(game.asteroids.is_empty() and destroyed == 7 and medium_count == 2 and small_count == 4,
		"breakup ends after one large, two medium, and four small asteroids")
	check(descendants_ok and game.score == 175,
		"all descendants retain their material and each destroyed piece awards exactly twenty-five points")

	# Size determines durability, but explicit ore identity survives every tier.
	for material in ["ash", "magma", "ice"]:
		fresh()
		game.bosses_defeated = 6
		large = game.spawn_asteroid(center, velocity, 43.0, 0, Vector2.INF, Vector2.ZERO, material)
		var progressed_ok: bool = large.health == 15 and large.visual_kind == material
		game.hit_asteroid(large, large.health)
		for medium in game.asteroids.duplicate():
			progressed_ok = progressed_ok and medium.health == 11 and medium.max_health == 11
			progressed_ok = progressed_ok and medium.visual_kind == material
			game.hit_asteroid(medium, medium.health)
		progressed_ok = progressed_ok and game.asteroids.size() == 4
		for small in game.asteroids:
			progressed_ok = progressed_ok and small.health == 8 and small.max_health == 8
			progressed_ok = progressed_ok and small.visual_kind == material
		check(progressed_ok, "%s fragments preserve ore and receive progressed health at every size" % material)

	# Tethered parents have zero velocity until release; fracture must still fan
	# outward without inheriting the pull state or a dangling boss anchor.
	fresh()
	large = game.spawn_asteroid(center, velocity, 43.0, 0, Vector2(270, 150))
	game.hit_asteroid(large, large.health)
	var released_ok: bool = game.asteroids.size() == 2
	var released_velocity := Vector2.ZERO
	for child in game.asteroids:
		released_ok = released_ok and child.motion_phase == "flight" and child.fold_life == 0.0
		released_velocity += child.velocity
	check(released_ok and released_velocity.is_zero_approx(),
		"fracturing a tethered rock releases free fragments with balanced stationary-parent momentum")

	fresh()
	var well := player_field(center)
	large = game.spawn_asteroid(center + Vector2(4, 0), velocity, 43.0)
	well.step(0.016)
	game.update_asteroids(0.016)
	check(game.asteroids.is_empty() and game.score == 25 and game.state == game.State.PLAYING,
		"an active player black hole swallows a large asteroid whole without spawning fragments")

	fresh()
	game.spawn_asteroid(Vector2(270, game.arena.y + 100), Vector2.DOWN * 40, 43.0)
	game.update_asteroids(0.0)
	check(game.asteroids.is_empty() and game.score == 0 and game.state == game.State.PLAYING,
		"an asteroid leaving the bottom is removed without splitting, scoring, or ending the run")
	game.spawn_asteroid(game.ship.position, Vector2.DOWN * 40, 43.0)
	game.update_asteroids(0.0)
	check(game.asteroids.is_empty() and game.score == 0 and game.state == game.State.LOST,
		"fatal ship collision removes the asteroid without creating extra fragments or rewards")

	fresh()
	large = game.spawn_asteroid(center, velocity, 43.0)
	game.hit_asteroid(large, large.health)
	var survivors: Array = game.asteroids.duplicate()
	game.clear_actors()
	var cleanup_ok: bool = game.asteroids.is_empty()
	for child in survivors:
		cleanup_ok = cleanup_ok and child.is_queued_for_deletion()
	check(cleanup_ok, "leaving a run clears every surviving fragment")
	# Deferred frees must complete before the final scene teardown.
	await process_frame
	game.free()
	await process_frame
	print("ASTEROID FRACTURE: %d passed, %d failed" % [passed, failures])
	quit(0 if failures == 0 else 1)
