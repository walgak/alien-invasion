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
var gravity_haptic_remaining := 0.0
var white_pops: Array[float] = []
var warp_pulses: Array[Dictionary] = []
var missiles := 30
## Special weapons are inventory, independent of the permanent primary gun tier.
var electron_stock := 0
var laser_stock := 0
var laser_active := false
var gravity_charge := 0.0
var gravity_armed := false
## Selection uses gameplay time, so backgrounding/pausing cancels without spending.
var gravity_selection_time := 0.0
## A single signal accompanies each enabled device pulse for input verification.
signal weapon_feedback_requested(action: String)
var pending_gravity_time := -1.0
var pending_gravity_target := Vector2.ZERO
var pending_gravity_charge := 0.0
var pending_gravity_units := 0.0
var aim_touches: Dictionary = {}
## Real resistance pointers live separately from steering and weapon targeting.
## This lets the optical tap shield blink exactly with touch, without making a
## long hold repeatedly cancel gravity or granting collected-shield immunity.
var gravity_touches: Dictionary = {}
const GRAVITY_MIN_CHARGE := 10.0
const GRAVITY_MAX_CHARGE := 50.0
const GRAVITY_PREPARATION := 1.0 / 3.0
const GRAVITY_SELECTION_WINDOW := 3.0

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
	electron_stock = 0
	laser_stock = 0
	laser_active = false
	previous_weapon = 0
	gravity_charge = 0.0

## Cancel a run-level action on pause, death or restart. Releasing a steering
## finger uses release_control instead, so it never cancels a queued special shot.
func cancel(keep_gravity_touches: bool = false) -> void:
	release_control()
	aim_touches.clear()
	if not keep_gravity_touches:
		gravity_touches.clear()
	gravity_armed = false
	gravity_selection_time = 0.0
	pending_gravity_time = -1.0
	pending_gravity_charge = 0.0
	pending_gravity_units = 0.0

## A pointer can own movement or an independent targeting tap, never both.
func owns_pointer(id: int) -> bool:
	return finger == id or aim_touches.has(id) or gravity_touches.has(id)

## A collected shield is timed equipment; the tap effect is only touch-held warp.
func gravity_touch_active() -> bool:
	return gravity_blocks_control() and not gravity_touches.is_empty()

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

## Match the visible hull at every gun tier, including the widest laser shape.
## Physics and shader layers share this radius instead of separate magic values.
func shield_radius() -> float:
	return 1.2 * maxf(47.0, game.Ship.Artwork.size_for(game.weapons.level).x * 0.5 + 8.0)

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
		cancel(true)
	elif finger != -1:
		held += delta
	if not gravity_blocks_control():
		gravity_touches.clear()
	for touch in aim_touches.values():
		touch.age += delta
	if pending_gravity_time >= 0.0:
		pending_gravity_time = maxf(0.0, pending_gravity_time - delta)
		if pending_gravity_time == 0.0:
			launch_gravity()
	if gravity_armed:
		gravity_selection_time = maxf(0.0, gravity_selection_time - delta)
		if gravity_selection_time <= 0.000001:
			gravity_selection_time = 0.0
			queue_gravity(automatic_gravity_target())
			# Automatic precharge already played during the final third-second
			# of selection. Launch on this deadline, without a second delay.
			if pending_gravity_time >= 0.0:
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
	if owns_pointer(id) or at.y <= game.playfield_top() or not Rect2(Vector2.ZERO, game.arena).has_point(at):
		return
	if gravity_blocks_control():
		gravity_touches[id] = true
		warp_pulses.append({"at": game.ship.position, "age": 0.0})
		if warp_pulses.size() > 4:
			warp_pulses.pop_front()
		if is_instance_valid(game.boss):
			game.boss.resist()
		for well in game.lingering_wells:
			well.resist()
		return
	if gravity_armed and at.y < game.arena.y * 0.5:
		if valid_gravity_target(at):
			aim_touches[id] = {"at": at, "age": 0.0, "gravity": true, "target": null}
		return
	# The armed lower half belongs to steering, even when an alien is under the
	# finger. A target selector must never take away the ability to evade it.
	if gravity_armed and finger == -1:
		begin_control(id, at)
		return
	var tapped: Node2D
	for enemy in game.enemies:
		if game.target_is_exposed(enemy, "enemy") and at.distance_to(enemy.position) < 35.0:
			tapped = enemy
	if is_instance_valid(game.boss) and game.target_is_exposed(game.boss, "boss") and at.distance_to(game.boss.body_position) < game.boss.hit_radius():
		tapped = game.boss
	if tapped != null:
		aim_touches[id] = {"at": at, "age": 0.0, "gravity": false, "target": tapped}
		return
	if finger == -1 and (at.y >= game.arena.y * 0.72 or at.distance_to(game.ship.position) < 75.0):
		begin_control(id, at)

## The steering finger remains the same across buttons and both screen halves.
func begin_control(id: int, at: Vector2) -> void:
	finger = id
	held = 0.0
	gesture = "control"
	game.pointer_id = id
	game.previous_pointer_x = at.x

## Only the upper half accepts a gravity destination. Keeping the minimum core
## away from the hull prevents a self-hit when a shield permits high-altitude flight.
func valid_gravity_target(at: Vector2) -> bool:
	var selected_size := clampf(gravity_charge / GRAVITY_MIN_CHARGE, 1.0, 5.0)
	var clear_distance := maxf(90.0, 31.0 * PlayerWell.scale_for_charge(selected_size) + game.Ship.HIT_RADIUS + 24.0)
	return Rect2(Vector2(0, game.playfield_top()), Vector2(game.arena.x, game.arena.y * 0.5 - game.playfield_top())).has_point(at) and at.distance_to(game.ship.position) >= clear_distance

func move(id: int, at: Vector2) -> void:
	if gravity_touches.has(id):
		if not Rect2(Vector2.ZERO, game.arena).has_point(at):
			gravity_touches.erase(id)
		return
	if aim_touches.has(id):
		# Sliding away cancels a tap, never takes over a finger already steering.
		if at.distance_to(aim_touches[id].at) > 32.0 or not Rect2(Vector2.ZERO, game.arena).has_point(at):
			aim_touches.erase(id)
		return
	if finger == -1 and not gravity_blocks_control() and at.y >= game.arena.y * (0.5 if gravity_armed else 0.72):
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
	if gravity_touches.has(id):
		gravity_touches.erase(id)
		return
	if aim_touches.has(id):
		var tap: Dictionary = aim_touches[id]
		aim_touches.erase(id)
		if canceled or gravity_blocks_control() or at.distance_to(tap.at) > 32.0:
			return
		if tap.gravity:
			if gravity_armed and valid_gravity_target(at) and gravity_charge >= GRAVITY_MIN_CHARGE:
				queue_gravity(at)
		elif tap.age < 1.0 and is_instance_valid(tap.target) and not tap.target.is_queued_for_deletion() and rocket_cooldown <= 0.0 and missiles > 0:
			if launch_cannon(tap.target):
				rocket_cooldown = 0.25
		return
	if id == finger:
		release_control()

## Eligible kills add charge. The game excludes kills caused by our own hole.
func add_gravity_charge(amount: float = 1.0) -> void:
	gravity_charge = clampf(gravity_charge + amount, 0.0, GRAVITY_MAX_CHARGE)

func arm_gravity() -> bool:
	if gravity_blocks_control() or pending_gravity_time >= 0.0 or gravity_charge < GRAVITY_MIN_CHARGE:
		return false
	gravity_armed = not gravity_armed
	gravity_selection_time = GRAVITY_SELECTION_WINDOW if gravity_armed else 0.0
	if not gravity_armed:
		clear_gravity_touches()
	return true

## Center of the upper half is the automatic aim. A rare shielded ship already
## occupying that position uses a safe upper-half point instead.
func automatic_gravity_target() -> Vector2:
	var center: Vector2 = game.arena * Vector2(0.5, 0.25)
	if valid_gravity_target(center):
		return center
	var safest := center
	var clearance := -1.0
	for y in [maxf(game.playfield_top() + 36.0, game.arena.y * 0.15), game.arena.y * 0.42]:
		for x in [game.arena.x * 0.2, game.arena.x * 0.5, game.arena.x * 0.8]:
			var candidate := Vector2(x, y)
			var distance: float = candidate.distance_squared_to(game.ship.position)
			if valid_gravity_target(candidate) and distance > clearance:
				safest = candidate
				clearance = distance
	return safest

## Queue once, then forget all selection fingers so releasing after an automatic
## launch cannot accidentally fire a cannon or start another gravity shot.
func queue_gravity(at: Vector2) -> void:
	if not gravity_armed or gravity_blocks_control() or gravity_charge < GRAVITY_MIN_CHARGE:
		return
	gravity_armed = false
	gravity_selection_time = 0.0
	clear_gravity_touches()
	pending_gravity_units = gravity_charge
	pending_gravity_charge = clampf(gravity_charge / GRAVITY_MIN_CHARGE, 1.0, 5.0)
	pending_gravity_target = at
	pending_gravity_time = GRAVITY_PREPARATION

func clear_gravity_touches() -> void:
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

## A boss can have only one targeted cannon in flight, shared by tap and button.
func boss_cannon_in_flight() -> bool:
	if not is_instance_valid(game.boss): return false
	for shot in game.projectiles:
		if not shot.hostile and shot.kind == "rocket" and is_instance_valid(shot.homing_target) and shot.homing_target == game.boss:
			return true
	return false

func can_target_boss() -> bool:
	return is_instance_valid(game.boss) and game.target_is_exposed(game.boss, "boss") and not boss_cannon_in_flight()

func can_fire_cannon_button() -> bool:
	if gravity_blocks_control(): return false
	var has_aliens: bool = game.enemies.any(func(enemy: Node2D) -> bool: return game.target_is_exposed(enemy, "enemy"))
	return missiles >= 5 if has_aliens else missiles > 0 and can_target_boss()

func launch_cannon(enemy: Node2D, play_sound: bool = true) -> bool:
	if missiles <= 0 or not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): return false
	if enemy == game.boss and not can_target_boss(): return false
	var shot = game.weapons.spawn_shot(game, game.ship.muzzle_position(game.weapons.level, 0, true), Vector2(0, -660))
	shot.kind = "rocket"
	shot.homing_target = enemy
	shot.damage = 3
	shot.blast_radius = 65.0
	missiles -= 1
	if play_sound:
		game.sound.play_effect("rocket")
	return true

## Five cannons enable the volley; only the necessary available ammunition is
## spent. Existing homing shots reserve their target's health to avoid overkill.
func fire_cannon_volley() -> int:
	if gravity_blocks_control() or missiles <= 0:
		return 0
	var candidates: Array = []
	for enemy in game.enemies:
		if game.target_is_exposed(enemy, "enemy"):
			candidates.append(enemy)
	# Keep the multi-alien volley, then let the same control fire one at a
	# lone boss. Boss damage still respects the existing alien guard shield.
	if candidates.is_empty():
		return 1 if can_target_boss() and launch_cannon(game.boss) else 0
	if missiles < 5: return 0
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

## Only boss rewards add electron charges. Failed/blocked launches never spend
## stock, and one activation is capped by the game to one chained screen attack.
func collect_electron() -> void:
	electron_stock = mini(10, electron_stock + 1)

func activate_electron() -> bool:
	if game.state != game.State.PLAYING or game.death_time > 0.0 or gravity_blocks_control() or electron_stock <= 0:
		return false
	if not game.fire_electron():
		return false
	electron_stock -= 1
	return true

## Laser pickups are inventory. A paused partial charge survives weapon toggles
## and costs no further pickup when selected again; charges never auto-chain.
func collect_laser() -> void:
	laser_stock = mini(99, laser_stock + 1)

func activate_laser() -> bool:
	if gravity_blocks_control():
		return false
	if laser_active:
		laser_active = false
		game.weapons.level = previous_weapon
		return true
	if laser_time <= 0.0:
		if laser_stock <= 0:
			return false
		laser_stock -= 1
		laser_time = 10.0
	previous_weapon = game.weapons.level
	laser_active = true
	game.weapons.level = 3
	return true

## Short tactile confirmation belongs to accepted button actions, not frames or
## held fingers. Disabled controls and muted vibration produce no device call.
func weapon_button_feedback(action: String) -> void:
	if not game.progress.vibration_enabled:
		return
	var duration := 25
	var strength := 0.45
	match action:
		"gravity":
			duration = 38
			strength = 0.6
		"laser":
			duration = 22
			strength = 0.4
		"cannon":
			duration = 45
			strength = 0.7
		"electron":
			duration = 30
			strength = 0.85
	Input.vibrate_handheld(duration, strength)
	weapon_feedback_requested.emit(action)
	# A finite click replaces iOS's rumble event. Resume an active field softly
	# after the click instead of leaving gravity silent until the old clock ends.
	gravity_haptic = false
	gravity_haptic_remaining = 0.0
	gravity_haptic_delay = maxf(gravity_haptic_delay, float(duration) / 1000.0 + 0.04)

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

## Shared visual clock for the muzzle particles and space-warp renderer. Auto
## fire precharges inside its three-second window but keeps manual aim available
## until the deadline; choosing a spot starts the usual fresh preparation.
func gravity_preparation_time() -> float:
	if pending_gravity_time >= 0.0:
		return pending_gravity_time
	if gravity_armed and gravity_selection_time <= GRAVITY_PREPARATION:
		return gravity_selection_time
	return -1.0

## The shield layer owns all shield/tap surfaces. This controller only draws
## the short-lived plasma gathering at the cannon during launch preparation.
func _draw() -> void:
	if game.state != game.State.PLAYING:
		return
	var preparation_time := gravity_preparation_time()
	if preparation_time >= 0.0:
		var at: Vector2 = game.ship.muzzle_position(game.weapons.level, 0, true)
		var progress := 1.0 - preparation_time / GRAVITY_PREPARATION
		for layer in range(4, 0, -1):
			draw_circle(at, 4.0 + layer * 5.0 * progress, Color(0.22, 0.62, 1.0, 0.04 * (5 - layer) * progress))
		for index in range(26):
			var phase := fmod(progress * 1.7 + float(index) / 26.0, 1.0)
			var angle := index * 2.39996 + phase * 1.2
			var particle := at + Vector2.from_angle(angle) * (7.0 + (1.0 - phase) * 66.0)
			draw_circle(particle, 1.3 + phase * 1.1, Color(0.35 + phase * 0.5, 0.75 + phase * 0.2, 1.0, phase * progress))

## Pick the nearest field that actually controls this ship for legacy callers.
## Orientation uses the resultant vector below, not this single-well helper.
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
		var angle: float = game.ship.lean * 0.12 if actor == game.ship else 0.0
		var engine_load := 0.0
		var force: Vector2 = game.gravity_fields.net_force_for(actor)
		if force.length_squared() > 0.01:
			# Opposing the vector sum is the optimum attitude between white holes;
			# two equal opposing fields leave the normal flight attitude unchanged.
			angle = (-force).angle() + (PI/2.0 if actor == game.ship else -PI/2.0)
			for well in game.gravity_fields.active_wells():
				if actor != game.ship and not well is PlayerWell:
					continue
				engine_load = maxf(engine_load, gravity_engine_load(actor.position, well))
		actor.rotation = lerp_angle(actor.rotation, angle, 1.0 - exp(-delta * 7.0))
		actor.engine_burn.set_load(engine_load)
		actor.engine_burn.advance(delta)
		actor.update_damage_visual(delta)

## Visual load only: bright/long near a black horizon; the opposite near white.
## Measure from the core, so merged/charged wells behave like small ones.
func gravity_engine_load(at: Vector2, well: Node2D) -> float:
	var rim_distance := maxf(0.0, at.distance_to(well.well_position)-game.gravity_fields.core_radius(well))
	var proximity := 1.0-clampf(rim_distance/320.0, 0.0, 1.0)
	return lerpf(0.22, 1.0, 1.0 - proximity) if well.kind == "white" else lerpf(0.08, 1.0, pow(proximity, 1.35))

## Cancel scheduled patterns on pause, death, restart, or vibration mute.
func stop_haptics() -> void:
	# iOS stops a finite event naturally. Sending a zero-duration replacement can
	# contend with touch delivery when its haptic engine is temporarily absent.
	gravity_haptic = false
	gravity_haptic_delay = 0.0
	gravity_haptic_remaining = 0.0
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
	gravity_haptic_remaining = maxf(0.0, gravity_haptic_remaining - delta)
	var wells: Array = game.gravity_fields.active_wells()
	if wells.is_empty():
		if gravity_haptic:
			stop_haptics()
	elif (not gravity_haptic or gravity_haptic_remaining <= 0.15) and gravity_haptic_delay <= 0.0:
		var duration := 0.0
		for well in wells:
			duration = maxf(duration, game.gravity_fields.seconds_left(well))
		# A lone field ends naturally at its exact remaining lifetime. Interacting
		# fields can end early through annihilation, so their renewable segments
		# are short enough that no long rumble continues after a sudden discharge.
		if gravity_haptic and duration <= gravity_haptic_remaining + 0.05:
			return
		duration = clampf(duration, 0.05, 1.2 if wells.size() > 1 else 30.0)
		Input.vibrate_handheld(int(duration * 1000), 0.18)
		gravity_haptic_remaining = duration
		gravity_haptic = true
