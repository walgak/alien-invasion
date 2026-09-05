extends SceneTree

const Progress = preload("res://scripts/progress.gd")
const Projectile = preload("res://scripts/projectile.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		failures += 1
		return
	checks += 1
	print("PASS: " + description)

func run_checks() -> void:
	root.size = Vector2i(540, 960)
	var save_path := OS.get_environment("ALIEN_SAVE_PATH")
	if save_path.is_empty() or not save_path.ends_with("smoke-record.cfg"):
		push_error("Tests require ALIEN_SAVE_PATH ending in smoke-record.cfg.")
		quit(1)
		return
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	check(game.state == game.State.MENU, "opens on the title screen")
	game.start_run()
	check(game.enemies.size() == 15 and game.lives == 3 and game.score == 0, "a new run has 15 enemies, 3 lives, and zero score")
	var initial_x: float = game.ship.position.x
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(100, 750)
	game._unhandled_input(touch)
	check(game.ship.target_x == initial_x, "touching does not teleport the ship under the finger")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(180, 750)
	game._unhandled_input(drag)
	check(game.ship.target_x == initial_x + 80, "dragging moves the target by the finger displacement")
	drag.index = 1
	drag.position.x = 380
	game._unhandled_input(drag)
	check(game.ship.target_x == initial_x + 80, "a second finger cannot steal steering")
	game.pause_run()
	var before: float = game.elapsed
	game._physics_process(1.0)
	check(game.elapsed == before and game.pointer_id == -1, "pause freezes the simulation and releases the drag")
	game.resume_run()
	check(game.state == game.State.PLAYING, "resume returns to the same run")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == game.State.PAUSED, "losing app focus pauses the run")
	game.resume_run()
	game.destroy_enemy(game.enemies[0])
	check(game.score == 100 and game.enemies.size() == 14, "destroying an enemy gives exactly 100 points")
	game.damage_ship()
	game.damage_ship()
	check(game.lives == 2, "post-hit invulnerability prevents repeated damage")
	game.ship.invulnerable = 0
	game.damage_ship()
	game.ship.invulnerable = 0
	game.damage_ship()
	check(game.lives == 0 and game.state == game.State.LOST, "the third hit ends the run")
	game.start_run()
	check(game.score == 0 and game.lives == 3 and game.elapsed == 0 and game.enemies.size() == 15, "retry resets score, health, time, and enemies")
	for enemy in game.enemies.duplicate():
		game.destroy_enemy(enemy)
	check(game.state == game.State.WON and game.score == 1500, "clearing the wave wins with 1500 points")
	game.toggle_sound()
	var reopened = Progress.new()
	check(reopened.best_for("fleet") == 1500 and reopened.sound_enabled == game.progress.sound_enabled, "best score and sound preference survive a reload")
	# These accelerated checks exercise settings, not real-time audio playback.
	game.sound.enabled = false
	game.start_run()
	check(game.progress.best_for("fleet") == 1500 and game.score == 0, "a new run preserves only the personal best")
	var shot = Projectile.new()
	shot.previous_position = Vector2(100, 500)
	shot.position = Vector2(100, 100)
	check(shot.intersects(Vector2(100, 300), 20), "fast projectiles cannot tunnel through an enemy")
	check(not shot.intersects(Vector2(160, 300), 20), "near misses are not counted as hits")
	shot.free()
	game.ship.reset_ship(Vector2(50, 750))
	game.ship.target_x = 400
	for i in range(30):
		game.ship.move_ship(1.0 / 30.0, 0, 540)
	var at_30: float = game.ship.position.x
	game.ship.reset_ship(Vector2(50, 750))
	game.ship.target_x = 400
	for i in range(120):
		game.ship.move_ship(1.0 / 120.0, 0, 540)
	check(is_equal_approx(at_30, game.ship.position.x), "movement covers the same distance at 30 and 120 updates per second")
	game.ship.target_x = 10000
	game.ship.move_ship(1.0, 0, 540)
	check(game.ship.position.x <= 505, "steering clamps to the playfield")
	# Exercise real movement and shooting long enough to catch lifetime errors.
	game.start_run()
	game.rng.seed = 42
	for i in range(3600):
		if game.state != game.State.PLAYING:
			break
		game.ship.target_x = 270 + sin(i / 90.0) * 200
		game._physics_process(1.0 / 60.0)
	check(game.score % 100 == 0 and game.lives >= 0, "a simulated mission retains valid score and health")
	for mode in ["black", "white"]:
		game.start_run(mode)
		check(is_instance_valid(game.boss) and game.enemies.is_empty(), mode + " encounter starts with its own boss")
		game.boss.begin_special()
		check(game.boss.phase == "warning", mode + " hole warns before exerting force")
		for i in range(400):
			if game.state != game.State.PLAYING:
				break
			game.boss.step(1.0 / 60.0)
		check(game.state == game.State.LOST and game.lives == 0, mode + " hole is lethal when the pilot does not resist")
		game.start_run(mode)
		game.boss.begin_special()
		for i in range(330):
			if i % 12 == 0:
				game.boss.resist()
			game.boss.step(1.0 / 60.0)
		check(game.state == game.State.PLAYING and game.boss.phase == "firefight", mode + " hole can be survived with five taps per second")
		game.boss.phase = "active"
		game.boss.neutralise_time = 0
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		game._unhandled_input(click)
		check(game.boss.neutralisation() == 1.0, "mouse clicks neutralise the " + mode + " hole")
		var value: float = game.boss.neutralise_time
		click.device = InputEvent.DEVICE_ID_EMULATION
		game._unhandled_input(click)
		check(game.boss.neutralise_time == value, "emulated mouse input cannot double-count a touch")
	game.start_run("asteroid")
	game.spawn_asteroid(Vector2(270, 500), Vector2(0, 250), 20)
	var rock: Node2D = game.asteroids[0]
	game.hit_asteroid(rock)
	check(rock.health == 2 and game.asteroids.size() == 1, "the first shot cracks a small asteroid")
	game.hit_asteroid(rock)
	check(rock.health == 1 and game.asteroids.size() == 1, "the second shot leaves a small asteroid barely intact")
	game.hit_asteroid(rock)
	check(game.asteroids.is_empty() and game.score == 25, "the third shot destroys a small asteroid and scores 25")
	game.spawn_asteroid(Vector2(270, 500), Vector2(0, 250), 31)
	check(game.asteroids[0].health == 6, "medium asteroids need six shots")
	game.remove_asteroid(game.asteroids[0])
	game.spawn_asteroid(Vector2(270, 500), Vector2(0, 250), 43)
	check(game.asteroids[0].health == 10, "large asteroids need ten shots")
	game.remove_asteroid(game.asteroids[0])
	game.boss.summon_asteroid()
	rock = game.asteroids[0]
	var offscreen: bool = rock.position.x < 0 or rock.position.x > game.arena.x or rock.position.y < 0 or rock.position.y > game.arena.y
	check(offscreen and rock.health in [3, 6, 10] and rock.motion_phase == "pull", "asteroid boss pulls a three-class rock in from offscreen")
	game.boss.body_position = Vector2(180, 310)
	game.update_asteroids(0.0)
	check(rock.fold_origin == game.boss.body_position + Vector2(0, 42), "asteroid fold lines stay tethered to the boss")
	var initial_distance: float = rock.position.distance_to(rock.fold_origin)
	game.update_asteroids(0.7)
	check(rock.motion_phase == "windup" and rock.position.distance_to(rock.fold_origin) < initial_distance and rock.velocity == Vector2.ZERO, "asteroid reels in beside the boss before its throwing windup")
	game.ship.position.x = 400
	game.update_asteroids(0.22)
	var release_direction: Vector2 = (game.ship.position + rock.aim_offset - rock.position).normalized()
	check(rock.motion_phase == "flight" and rock.velocity.normalized().dot(release_direction) > 0.999, "asteroid is thrown toward the ship's position at release")
	var thrown_velocity: Vector2 = rock.velocity
	game.ship.position.x = 100
	game.update_asteroids(0.25)
	check(rock.velocity == thrown_velocity and rock.fold_life == 0.0, "released asteroid stays dodgeable and its web fades away")
	game.remove_asteroid(rock)
	game.spawn_asteroid(game.ship.position - Vector2(0, 100), Vector2(0, 1000), 24)
	game.update_asteroids(0.12)
	check(game.lives == 2, "an asteroid crossing the ship deals one hit")
	game.spawn_asteroid(game.ship.position + Vector2(100, -100), Vector2(0, 1000), 24)
	game.update_asteroids(0.12)
	check(game.lives == 2, "a dodged asteroid does not damage the ship")
	for i in range(game.boss.max_health):
		game.boss.take_hit()
	check(game.state == game.State.WON and game.score == 1025, "destroying the asteroid boss completes the encounter")
	check(game.progress.best_for("fleet") == 1500 and game.progress.best_for("asteroid") == 1025, "flight records are separate for each encounter")
	print("%d CHECKS PASSED; %d FAILED" % [checks, failures])
	game.free()
	DirAccess.remove_absolute(save_path)
	await process_frame
	quit(0 if failures == 0 else 1)
