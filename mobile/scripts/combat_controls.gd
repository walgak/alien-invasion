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
var warp_pulses: Array[Dictionary] = []
var missiles := 30
## Special weapons are inventory, independent of the permanent primary gun tier.
var laser_stock := 0
var laser_active := false
var gravity_charge := 0.0
var gravity_armed := false
var pending_gravity_time := -1.0
var pending_gravity_target := Vector2.ZERO
var pending_gravity_charge := 0.0
var pending_gravity_units := 0.0
var aim_touches: Dictionary = {}
const GRAVITY_MIN_CHARGE := 10.0
const GRAVITY_MAX_CHARGE := 50.0
const GRAVITY_PREPARATION := 1.0 / 3.0

## Forget run-owned state without changing saved sound/vibration preferences.
func reset() -> void:
	cancel()
	shield_time = 0.0
	laser_time = 0.0
	rocket_cooldown = 0.0
	haptic_cooldown = 0.0
	haptic_followup = 0.0
	returns.clear()
	warp_pulses.clear()
	stop_haptics()
	missiles = 30
	laser_stock = 0
	laser_active = false
	previous_weapon = 0
	gravity_charge = 0.0

## Cancel a run-level action on pause, death or restart. Releasing a steering
## finger uses release_control instead, so it never cancels a queued special shot.
func cancel() -> void:
	release_control()
	aim_touches.clear()
	gravity_armed = false
	pending_gravity_time = -1.0
	pending_gravity_charge = 0.0
	pending_gravity_units = 0.0

## A pointer can own movement or an independent targeting tap, never both.
func owns_pointer(id: int) -> bool:
	return finger == id or aim_touches.has(id)

func release_control() -> void:
	gesture = ""
	finger = -1
	held = 0.0
	target = null
	game.pointer_id = -1
	game.ship.target_x = game.ship.position.x

## Forced gravity tapping grants protection from incoming hazards only. The
## complete collected shield additionally negates gravity and allows steering.
func hazards_protected() -> bool:
	return shield_time > 0.0 or gravity_blocks_control()

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
	for pulse in warp_pulses.duplicate():
		pulse.age += delta
		if pulse.age >= 0.42:
			warp_pulses.erase(pulse)
	if laser_active and laser_time > 0.0 and firing():
		laser_time = maxf(0.0, laser_time - delta)
		if laser_time == 0.0:
			laser_active = false
			game.weapons.level = previous_weapon
	if gravity_blocks_control():
		# If a boss opens a field during preparation, preserve the bank but
		# cancel this shot: tapping and firing must never overlap unshielded.
		cancel()
	elif finger != -1:
		held += delta
	for touch in aim_touches.values():
		touch.age += delta
	if pending_gravity_time >= 0.0:
		pending_gravity_time = maxf(0.0, pending_gravity_time - delta)
		if pending_gravity_time == 0.0:
			launch_gravity()
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

## Movement retains its own finger when a second finger targets an alien,
## chooses a gravity destination, or presses a special-weapon button.
func press(id: int, at: Vector2) -> void:
	if owns_pointer(id) or at.y <= game.top_inset + 143 or not Rect2(Vector2.ZERO, game.arena).has_point(at):
		return
	if gravity_blocks_control():
		warp_pulses.append({"at": game.ship.position, "age": 0.0})
		if warp_pulses.size() > 4:
			warp_pulses.pop_front()
		if is_instance_valid(game.boss):
			game.boss.resist()
		for well in game.lingering_wells:
			well.resist()
		return
	if gravity_armed:
		if valid_gravity_target(at):
			aim_touches[id] = {"at": at, "age": 0.0, "gravity": true, "target": null}
		return
	var tapped: Node2D
	for enemy in game.enemies:
		if game.target_is_exposed(enemy, "enemy") and at.distance_to(enemy.position) < 35.0:
			tapped = enemy
	if is_instance_valid(game.boss) and game.target_is_exposed(game.boss, "boss") and at.distance_to(game.boss.body_position) < game.Boss.HIT_RADIUS:
		tapped = game.boss
	if tapped != null:
		aim_touches[id] = {"at": at, "age": 0.0, "gravity": false, "target": tapped}
		return
	if finger == -1 and (at.y >= game.arena.y * 0.72 or at.distance_to(game.ship.position) < 75.0):
		finger = id
		held = 0.0
		gesture = "control"
		game.pointer_id = id
		game.previous_pointer_x = at.x

## The target may be anywhere visible beyond the player's hull and HUD. Keeping
## the minimum core away from the muzzle prevents an unavoidable self-hit.
func valid_gravity_target(at: Vector2) -> bool:
	var selected_size := clampf(gravity_charge / GRAVITY_MIN_CHARGE, 1.0, 5.0)
	var clear_distance := maxf(90.0, 31.0 * 1.8 * sqrt(selected_size) + game.Ship.HIT_RADIUS + 24.0)
	return Rect2(Vector2(0, game.top_inset + 143), Vector2(game.arena.x, game.arena.y - game.bottom_inset - game.top_inset - 217)).has_point(at) and at.distance_to(game.ship.position) >= clear_distance

func move(id: int, at: Vector2) -> void:
	if aim_touches.has(id):
		# Sliding away cancels a tap, never takes over a finger already steering.
		if at.distance_to(aim_touches[id].at) > 32.0 or not Rect2(Vector2.ZERO, game.arena).has_point(at):
			aim_touches.erase(id)
		return
	if finger == -1 and not gravity_blocks_control() and not gravity_armed and at.y >= game.arena.y * 0.72:
		press(id, at)
	if id != finger:
		return
	if not Rect2(Vector2.ZERO, game.arena).has_point(at):
		release_control()
	elif gesture == "control":
		game.drag_to(at.x)

## A selected destination queues the charge animation only after the target
## finger lifts. Releasing either finger never cancels the other's action.
func release(id: int, at: Vector2, canceled: bool = false) -> void:
	if aim_touches.has(id):
		var tap: Dictionary = aim_touches[id]
		aim_touches.erase(id)
		if canceled or gravity_blocks_control() or at.distance_to(tap.at) > 32.0:
			return
		if tap.gravity:
			if gravity_armed and valid_gravity_target(at) and gravity_charge >= GRAVITY_MIN_CHARGE:
				gravity_armed = false
				pending_gravity_units = gravity_charge
				pending_gravity_charge = clampf(gravity_charge / GRAVITY_MIN_CHARGE, 1.0, 5.0)
				pending_gravity_target = tap.at
				pending_gravity_time = GRAVITY_PREPARATION
		elif tap.age < 1.0 and is_instance_valid(tap.target) and not tap.target.is_queued_for_deletion() and rocket_cooldown <= 0.0 and missiles > 0:
			launch_cannon(tap.target)
			rocket_cooldown = 0.25
		return
	if id == finger:
		release_control()

## Eligible kills add charge. The game excludes kills caused by our own hole.
func add_gravity_charge(amount: float = 1.0) -> void:
	gravity_charge = clampf(gravity_charge + amount, 0.0, GRAVITY_MAX_CHARGE)

func arm_gravity() -> void:
	if gravity_blocks_control() or pending_gravity_time >= 0.0 or gravity_charge < GRAVITY_MIN_CHARGE:
		return
	gravity_armed = not gravity_armed
	if not gravity_armed:
		for id in aim_touches.keys():
			if aim_touches[id].gravity:
				aim_touches.erase(id)

## The reservation fixes the chosen size. Kills during the preparation remain
## banked for the next hole; canceling preparation does not spend any charge.
func launch_gravity() -> void:
	var well = PlayerWell.new()
	well.game = game
	well.well_position = pending_gravity_target
	well.cannon_position = game.ship.muzzle_position(game.weapons.level, 0, true)
	well.charge = pending_gravity_charge
	game.add_child(well)
	game.lingering_wells.append(well)
	gravity_charge = maxf(0.0, gravity_charge - pending_gravity_units)
	pending_gravity_time = -1.0
	pending_gravity_units = 0.0
	game.sound.play_effect("rocket")

func launch_cannon(enemy: Node2D, play_sound: bool = true) -> void:
	var shot = game.weapons.spawn_shot(game, game.ship.muzzle_position(game.weapons.level, 0, true), Vector2(0, -660))
	shot.kind = "rocket"
	shot.homing_target = enemy
	shot.damage = 3
	shot.blast_radius = 65.0
	missiles -= 1
	if play_sound:
		game.sound.play_effect("rocket")

## Five cannons enable the volley; only the necessary available ammunition is
## spent. Existing homing shots reserve their target's health to avoid overkill.
func fire_cannon_volley() -> int:
	if gravity_blocks_control() or missiles < 5:
		return 0
	var candidates: Array = []
	for enemy in game.enemies:
		if game.target_is_exposed(enemy, "enemy"):
			candidates.append(enemy)
	candidates.sort_custom(func(a, b): return a.position.y > b.position.y)
	var fired := 0
	for enemy in candidates:
		var reserved := 0
		for shot in game.projectiles:
			if is_instance_valid(shot) and not shot.is_queued_for_deletion() and not shot.hostile and shot.kind == "rocket" and shot.homing_target == enemy:
				reserved += shot.damage
		var needed := mini(missiles, maxi(0, ceili(float(enemy.health - reserved) / 3.0)))
		for index in range(needed):
			launch_cannon(enemy, false)
			fired += 1
		if missiles <= 0:
			break
	if fired > 0:
		game.sound.play_effect("rocket")
	return fired

## Laser pickups are inventory. A paused partial charge survives weapon toggles
## and costs no further pickup when selected again; charges never auto-chain.
func collect_laser() -> void:
	laser_stock = mini(99, laser_stock + 1)

func activate_laser() -> void:
	if gravity_blocks_control():
		return
	if laser_active:
		laser_active = false
		game.weapons.level = previous_weapon
		return
	if laser_time <= 0.0:
		if laser_stock <= 0:
			return
		laser_stock -= 1
		laser_time = 10.0
	previous_weapon = game.weapons.level
	laser_active = true
	game.weapons.level = 3

## Kept as an explicit development/test shortcut; collection uses collect_laser.
func equip_laser() -> void:
	collect_laser()
	if not laser_active:
		activate_laser()

## Limit death vibration spam and distinguish a hit's double pulse from gravity's
## long rumble and an enemy death's short tick. iOS supplies the hardware feedback.
func vibrate(event: String) -> void:
	if not game.progress.vibration_enabled:
		return
	if event in ["black_spawn", "white_spawn"]:
		Input.vibrate_handheld(65 if event == "black_spawn" else 35, 0.85)
		gravity_haptic = false
		gravity_haptic_delay = 0.26
		if event == "white_spawn":
			white_pops.assign([0.07, 0.16])
	elif event == "hit":
		gravity_haptic = false
		gravity_haptic_delay = 0.26
		Input.vibrate_handheld(45, 1.0)
		haptic_followup = 0.11
	elif haptic_cooldown <= 0.0 and not gravity_haptic:
		Input.vibrate_handheld(110 if event == "gravity" else 20, 0.65 if event == "gravity" else 0.35)
		haptic_cooldown = 0.45 if event == "gravity" else 0.22

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

## Gravity silhouettes come from screen refraction, with soft filled halos and
## particles for readability. No geometric rings are painted over the lens.
func _draw() -> void:
	if game.state != game.State.PLAYING:
		return
	if hazards_protected():
		var pulse := 0.75 + sin(game.elapsed * 3.2) * 0.25
		for layer in range(4, 0, -1):
			draw_circle(game.ship.position, 34.0 + layer * 7.0, Color(0.28, 0.86, 1.0, (0.006 + 0.004 * pulse) * (5 - layer)))
	for pulse in warp_pulses:
		var progress: float = clampf(pulse.age / 0.42, 0.0, 1.0)
		draw_warp_ring(pulse.at, 42.0 + progress * 44.0, game.elapsed * 1.7, 1.0 - progress)
	if pending_gravity_time >= 0.0:
		var at: Vector2 = game.ship.muzzle_position(game.weapons.level, 0, true)
		var progress := 1.0 - pending_gravity_time / GRAVITY_PREPARATION
		for layer in range(4, 0, -1):
			draw_circle(at, 4.0 + layer * 5.0 * progress, Color(0.22, 0.62, 1.0, 0.04 * (5 - layer) * progress))
		for index in range(26):
			var phase := fmod(progress * 1.7 + float(index) / 26.0, 1.0)
			var angle := index * 2.39996 + phase * 1.2
			var particle := at + Vector2.from_angle(angle) * (7.0 + (1.0 - phase) * 66.0)
			draw_circle(particle, 1.3 + phase * 1.1, Color(0.35 + phase * 0.5, 0.75 + phase * 0.2, 1.0, phase * progress))

## Historical API name retained for callers; the effect is a soft volume only.
func draw_warp_ring(at: Vector2, radius: float, _phase: float, alpha: float) -> void:
	for layer in range(4, 0, -1):
		draw_circle(at, radius * (0.68 + layer * 0.08), Color(0.35, 0.82, 1.0, 0.012 * alpha))

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
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var well := gravity_for(actor)
		var angle: float = game.ship.lean * 0.12 if actor == game.ship else 0.0
		var engine_load := 0.0
		if well != null:
			var nose: Vector2 = actor.position - well.well_position
			if well.kind == "white":
				nose = -nose
			# Player art faces up; alien art faces down. Both noses oppose gravity.
			angle = nose.angle() + (PI/2.0 if actor == game.ship else -PI/2.0)
			engine_load = gravity_engine_load(actor.position, well)
		actor.rotation = lerp_angle(actor.rotation, angle, 1.0 - exp(-delta * 7.0))
		actor.engine_burn.set_load(engine_load)
		actor.engine_burn.advance(delta)

## Visual load only: bright/long near a black horizon; the opposite near white.
## Measure from the core, so merged/charged wells behave like small ones.
func gravity_engine_load(at: Vector2, well: Node2D) -> float:
	var rim_distance := maxf(0.0, at.distance_to(well.well_position)-31.0*well.well_scale)
	var proximity := 1.0-clampf(rim_distance/320.0, 0.0, 1.0)
	return lerpf(0.22, 1.0, 1.0 - proximity) if well.kind == "white" else lerpf(0.08, 1.0, pow(proximity, 1.35))

## Cancel scheduled patterns on pause, death, restart, or vibration mute.
func stop_haptics() -> void:
	# iOS stops a finite event naturally. Sending a zero-duration replacement can
	# contend with touch delivery when its haptic engine is temporarily absent.
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
