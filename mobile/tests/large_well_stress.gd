extends SceneTree
## Maximum-charge regression with real frame boundaries, so swallowed nodes are
## actually freed before the next physics update. Optional GPU run uses the same scene.
var game: Node2D

## Begin once the scene tree is ready.
func _initialize() -> void:
	call_deferred("run")

## Exercise the entire field lifetime and restoration, recording CPU update cost.
func run() -> void:
	if not OS.get_environment("ALIEN_SAVE_PATH").ends_with("large-well-stress-record.cfg"):
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.progress.vibration_enabled = false
	game.start_run()
	game.wave_timer = 1000
	game.boss_timer = 1000
	game.asteroid_timer = 1000
	game.combat.shield_time = 30
	for i in range(14):
		game.spawn_enemy(Vector2(60 + (i % 7) * 65, 250 + (i / 7) * 200), Vector2.ZERO)
	for i in range(8):
		game.spawn_asteroid(Vector2(55 + i * 55, 310), Vector2.DOWN * 20, 20)
	game.combat.press(0, Vector2(270, 420))
	game.combat.step(5)
	game.combat.release(0, Vector2(270, 420))
	var max_cpu_us := 0
	var cpu_us := 0
	for frame in range(660):
		var began := Time.get_ticks_usec()
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
		var cost := Time.get_ticks_usec() - began
		max_cpu_us = maxi(max_cpu_us, cost)
		cpu_us += cost
		await process_frame
		if frame % 120 == 0:
			print("STRESS frame=%d fields=%d enemies=%d rocks=%d" % [frame, game.lingering_wells.size(), game.enemies.size(), game.asteroids.size()])
	var ok: bool = game.state == game.State.PLAYING and game.lingering_wells.is_empty() and game.combat.returns.is_empty()
	print("LARGE WELL: complete=%s mean_cpu_us=%d max_cpu_us=%d" % [ok, cpu_us / 660, max_cpu_us])
	game.free()
	await process_frame
	quit(0 if ok else 1)
