extends Node2D
## Owns mutually exclusive gestures and timed equipment. All clocks use gameplay
## delta, so pausing never spends a shield, laser, or charged-well lifetime.

const PlayerWell = preload("res://scripts/player_well.gd")
var game: Node2D
var gesture := ""
var held := 0.0
var finger := -1
var aim := Vector2.ZERO
var target: Node2D
var shield_time := 0.0
var laser_time := 0.0
var previous_weapon := 0
var rocket_cooldown := 0.0
var haptic_cooldown := 0.0
var haptic_followup := 0.0
var returns: Dictionary[int, Vector2] = {}
var gravity_haptic := false
var gravity_haptic_delay := 0.0
var white_pops: Array[float] = []
var missiles := 30

## Forget run-owned state without changing saved sound/vibration preferences.
func reset() -> void:
	cancel()
	shield_time = 0.0
	laser_time = 0.0
	rocket_cooldown = 0.0
	haptic_cooldown = 0.0
	haptic_followup = 0.0
	returns.clear()
	stop_haptics()
	missiles = 30

## Stop all control immediately; the ship must not coast toward an old drag target.
func cancel() -> void:
	gesture = ""
	finger = -1
	held = 0.0
	target = null
	game.pointer_id = -1
	game.ship.target_x = game.ship.position.x

## Equipped weapons fire only while a ship-control gesture is held, outside gravity.
func firing() -> bool:
	return gesture == "control" and finger != -1 and not gravity_blocks_control()

## Shields allow movement, ordinary fire, and a charged gravity counterattack.
func gravity_blocks_control() -> bool:
	return game.gravity_is_active() and shield_time <= 0.0

## Tick equipment, charge display, haptics, and smooth restoration of surviving actors.
func step(delta: float) -> void:
	shield_time = maxf(0.0, shield_time - delta)
	rocket_cooldown = maxf(0.0, rocket_cooldown - delta)
	haptic_cooldown = maxf(0.0, haptic_cooldown - delta)
	if haptic_followup > 0.0:
		haptic_followup -= delta
		if haptic_followup <= 0.0 and game.progress.vibration_enabled:
			Input.vibrate_handheld(45, 1.0)
	if laser_time > 0.0 and firing():
		laser_time = maxf(0.0, laser_time - delta)
		if laser_time == 0.0:
			game.weapons.level = previous_weapon
	if gravity_blocks_control():
		cancel()
	elif finger != -1:
		held = minf(5.0, held + delta)
	for id in returns.keys():
		var actor = instance_from_id(id)
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			returns.erase(id)
			continue
		if game.gravity_is_active():
			continue
		var destination: Vector2 = returns[id]
		if actor == game.ship:
			destination.x = actor.position.x
		actor.position = actor.position.move_toward(destination, 260.0 * delta)
		if actor == game.ship:
			actor.target_x = actor.position.x
			actor.invulnerable = maxf(actor.invulnerable, 0.2)
		else:
			actor.previous_position = actor.position
		if actor.position.distance_to(destination) < 0.1:
			returns.erase(id)
	update_haptics(delta)
	queue_redraw()

## Capture one pointer only. Upper-field taps and holds never accidentally fire
## the equipped weapon; the lower flight area is exclusively for ship control.
func press(id: int, at: Vector2) -> void:
	if finger != -1 or at.y <= game.top_inset + 143 or not Rect2(Vector2.ZERO, game.arena).has_point(at):
		return
	if gravity_blocks_control():
		if is_instance_valid(game.boss):
			game.boss.resist()
		for well in game.lingering_wells:
			well.resist()
		return
	finger = id
	held = 0.0
	aim = at
	target = null
	for enemy in game.enemies:
		if game.target_is_exposed(enemy, "enemy") and at.distance_to(enemy.position) < 35.0:
			target = enemy
	if is_instance_valid(game.boss) and game.target_is_exposed(game.boss, "boss") and at.distance_to(game.boss.body_position) < game.Boss.HIT_RADIUS:
		target = game.boss
	gesture = "aim"
	if target == null and (at.y >= game.arena.y * 0.72 or at.distance_to(game.ship.position) < 75.0):
		gesture = "control"
		game.pointer_id = id
		game.previous_pointer_x = at.x

## Leaving the viewport cancels firing even if the OS has not sent a release yet.
func move(id: int, at: Vector2) -> void:
	# A real drag proves the finger is still down after a gravity transition.
	# Reacquire only ship control, never silently restart a charge or target tap.
	if finger == -1 and not gravity_blocks_control() and at.y >= game.arena.y * 0.72:
		press(id, at)
	if id != finger:
		return
	if not Rect2(Vector2.ZERO, game.arena).has_point(at):
		cancel()
	elif gesture == "control":
		game.drag_to(at.x)

## Short enemy taps launch a homing rocket; a stationary upper hold launches a
## gravity rocket on release. Charging is capped at five seconds, including size.
func release(id: int, at: Vector2, canceled: bool = false) -> void:
	if id != finger:
		return
	if not canceled and Rect2(Vector2.ZERO, game.arena).has_point(at) and not gravity_blocks_control() and gesture == "aim":
		if held >= 1.0 and not gravity_blocks_control() and aim.y < game.arena.y * 0.72 and aim.distance_to(game.ship.position) >= 75.0:
			var well = PlayerWell.new()
			well.game = game
			well.well_position = aim
			well.cannon_position = game.ship.position + Vector2(0, -44)
			well.charge = clampf(held, 1.0, 5.0)
			game.add_child(well)
			game.lingering_wells.append(well)
			game.sound.play_effect("rocket")
		elif held < 1.0 and is_instance_valid(target) and not target.is_queued_for_deletion() and rocket_cooldown <= 0.0 and missiles > 0:
			var shot = game.weapons.spawn_shot(game, game.ship.position + Vector2(0, -44), Vector2(0, -660))
			shot.kind = "rocket"
			shot.homing_target = target
			shot.damage = 3
			shot.blast_radius = 65.0
			missiles -= 1
			rocket_cooldown = 0.25
			game.sound.play_effect("rocket")
	cancel()

## Remember the real weapon once; another laser pickup refreshes its duration.
func equip_laser() -> void:
	if laser_time <= 0.0:
		previous_weapon = game.weapons.level
	laser_time = 10.0
	game.weapons.level = 3

## Limit death vibration spam and distinguish a hit's double pulse from gravity's
## long rumble and an enemy death's short tick. iOS supplies the hardware feedback.
func vibrate(event: String) -> void:
	if not game.progress.vibration_enabled:
		return
	if gravity_haptic:
		gravity_haptic = false
		gravity_haptic_delay = 0.26
	if event in ["black_spawn", "white_spawn"]:
		Input.vibrate_handheld(65 if event == "black_spawn" else 35, 0.85)
		gravity_haptic = false
		gravity_haptic_delay = 0.26
		if event == "white_spawn":
			white_pops.assign([0.07, 0.16])
	elif event == "hit":
		Input.vibrate_handheld(45, 1.0)
		haptic_followup = 0.11
	elif haptic_cooldown <= 0.0:
		Input.vibrate_handheld(110 if event == "gravity" else 20, 0.65 if event == "gravity" else 0.35)
		haptic_cooldown = 0.35 if event == "gravity" else 0.08

## Non-gravity actors pause their normal travel while a player well pulls them or
## while they return. Bosses never enter this list and remain immune to the pull.
func controls_actor(actor: Node2D) -> bool:
	if game.asteroids.has(actor) or (actor == game.ship and shield_time > 0.0):
		return false
	if returns.has(actor.get_instance_id()):
		return true
	for well in game.lingering_wells:
		if well is PlayerWell and well.holds_steering():
			return true
	return false

## Draw shield and charge feedback above the ship without allocating per-frame nodes.
func _draw() -> void:
	if game.state != game.State.PLAYING:
		return
	if shield_time > 0.0:
		draw_circle(game.ship.position, 43, Color(0.3, 0.8, 1.0, 0.08))
		draw_arc(game.ship.position, 43, 0, TAU, 64, Color(0.5, 0.9, 1.0, 0.8), 2, true)
	if gesture == "aim":
		draw_arc(aim, 24 + held * 5, -PI / 2, -PI / 2 + TAU * held / 5, 64, Color("c7a0ff"), 3, true)
	# Iterate live actor arrays, never object-key dictionaries: swallowed ships
	# may be freed between physics and drawing on the iPhone render callback.
	for actor in game.enemies + [game.ship]:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var well := gravity_for(actor)
		if well == null:
			continue
		var exhaust := Vector2.DOWN.rotated(actor.rotation)
		var start: Vector2 = actor.position + exhaust * 22.0
		draw_line(start, start + exhaust * (36 + sin(game.elapsed * 35) * 5), Color(0.3, 0.7, 1, 0.22), 12, true)
		draw_line(start, start + exhaust * 27, Color("b8eaff"), 3, true)

## Pick the strongest nearby field that actually controls this ship.
func gravity_for(actor: Node2D) -> Node2D:
	if actor == game.ship and shield_time > 0.0:
		return null
	var best: Node2D
	var nearest := INF
	for well in game.gravity_fields.active_wells():
		if actor != game.ship and not well is PlayerWell:
			continue
		var distance: float = actor.position.distance_squared_to(well.well_position)
		if distance < nearest:
			nearest = distance
			best = well
	return best

## The nose points against gravity; lerp_angle takes the shortest return turn.
func update_attitudes(delta: float) -> void:
	for actor in game.enemies + [game.ship]:
		var well := gravity_for(actor)
		var angle: float = game.ship.lean * 0.12 if actor == game.ship else 0.0
		if well != null:
			var nose: Vector2 = actor.position - well.well_position
			if well.kind == "white":
				nose = -nose
			angle = nose.angle() + PI / 2.0
		actor.rotation = lerp_angle(actor.rotation, angle, 1.0 - exp(-delta * 7.0))

## Cancel scheduled patterns on pause, death, restart, or vibration mute.
func stop_haptics() -> void:
	if gravity_haptic:
		Input.vibrate_handheld(0, 0.0)
	gravity_haptic = false
	gravity_haptic_delay = 0.0
	white_pops.clear()

## One long low-amplitude event gives a smooth continuous gravity rumble. Spawn
## transients finish first; there is no vibration allocation on every tap/frame.
func update_haptics(delta: float) -> void:
	if not game.progress.vibration_enabled:
		stop_haptics()
		return
	for i in range(white_pops.size() - 1, -1, -1):
		white_pops[i] -= delta
		if white_pops[i] <= 0.0:
			Input.vibrate_handheld(30, 0.6 + 0.15 * i)
			white_pops.remove_at(i)
	gravity_haptic_delay = maxf(0.0, gravity_haptic_delay - delta)
	var wells: Array = game.gravity_fields.active_wells()
	if wells.is_empty():
		if gravity_haptic:
			stop_haptics()
	elif not gravity_haptic and gravity_haptic_delay <= 0.0:
		var duration := 0.0
		for well in wells:
			duration = maxf(duration, game.gravity_fields.seconds_left(well))
		Input.vibrate_handheld(int(duration * 1000), 0.18)
		gravity_haptic = true
