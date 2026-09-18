extends Node2D
## A repeating firefight, random special attack, and return to the firefight.

const HIT_RADIUS := 54.0
const HullFinish = preload("res://scripts/hull_finish.gd")
const WARNING_SECONDS := 1.25
const ACTIVE_SECONDS := 4.0
const FIREFIGHT_MIN_SECONDS := 5.0
const FIREFIGHT_MAX_SECONDS := 9.0
const TAP_NEUTRALISE_SECONDS := 0.22
const EDGE_COLLISION_DISTANCE := 26.0
const RIFT_CANNON_SPEED := 1225.0
const SWARM_SIZE := 4
const ASTEROID_SIZES := [
	{"radius": 20.0, "health": 3},
	{"radius": 31.0, "health": 6},
	{"radius": 43.0, "health": 10}
]
var game: Node2D
var kind := "black"
var health := 20.0
var max_health := 20.0
var body_position := Vector2.ZERO
var phase := "firefight"
var phase_time := 0.0
var cooldown := 0.0
var shot_timer := 0.8
var asteroid_timer := 0.0
var swarm_count := 0
var swarm_reward: Dictionary = {}
var well_position := Vector2.ZERO
var white_push_direction := Vector2.DOWN
var neutralise_time := 0.0
var cannon_active := false
var cannon_position := Vector2.ZERO
var cannon_previous_position := Vector2.ZERO
var cannon_velocity := Vector2.ZERO
var tap_flash := 0.0
var hit_flash := 0.0
var animation_time := 0.0
var lingering := false
## Detached attacks skip boss-body rendering and free themselves when their phase ends.
var well_duration := ACTIVE_SECONDS
## Normal force lasts four seconds; the death-created well overrides this to eight.
var well_scale := 1.0
var proximity_multiplier := 1.0
var guard_total := 0
var dodge_offset := Vector2.ZERO
var hole_color := Color("a45cff")

## Godot calls this once after the node joins the scene; initialize child nodes and cached resources here.
func _ready() -> void:
	if lingering:
		return
	return_to_firefight()
	phase = "arrival"

## Advance the boss phase machine or a detached residual attack; all attack timers use seconds.
func step(delta: float) -> void:
	if health <= 0 or game.state != game.State.PLAYING:
		return
	animation_time += delta
	phase_time += delta
	tap_flash = maxf(0.0, tap_flash - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	if not lingering:
		var patrol := Vector2(game.arena.x * 0.5 + sin(animation_time * 0.63) * 80, game.top_inset + 250)
		update_player_well_dodge(delta,patrol)
		body_position = patrol+dodge_offset
	if phase == "arrival":
		body_position.y = lerpf(-100.0, game.top_inset + 250.0+dodge_offset.y, smoothstep(0.0, 1.5, phase_time))
		if phase_time >= 1.5:
			return_to_firefight()
	elif phase == "firefight":
		cooldown -= delta
		shot_timer -= delta
		if cooldown <= 0:
			begin_special()
		elif shot_timer <= 0:
			fire_volley()
			shot_timer += 1.35 / game.difficulty_scale()
	elif phase == "warning":
		if cannon_active:
			cannon_previous_position = cannon_position
			cannon_position += cannon_velocity * delta
			if Geometry2D.get_closest_point_to_segment(well_position, cannon_previous_position, cannon_position).distance_to(well_position) <= 18.0:
				activate_special()
		elif phase_time >= WARNING_SECONDS:
			activate_special()
	elif phase == "active" and kind == "asteroid":
		asteroid_timer -= delta
		if phase_time >= ACTIVE_SECONDS:
			phase = "clearing"
			phase_time = 0.0
		elif asteroid_timer <= 0:
			summon_asteroid()
			asteroid_timer += 0.82
	elif phase == "active" and kind == "swarm":
		asteroid_timer -= delta
		if swarm_count >= SWARM_SIZE:
			phase = "clearing"
			phase_time = 0.0
		elif asteroid_timer <= 0.0:
			summon_alien()
			swarm_count += 1
			asteroid_timer += 0.92
	elif phase == "clearing":
		var summons_cleared: bool = game.asteroids.is_empty()
		if kind == "swarm":
			summons_cleared = game.enemies.filter(func(enemy: Node2D) -> bool: return enemy.summoned).is_empty()
		if summons_cleared:
			return_to_firefight()
	elif phase == "active" and kind in ["black", "white"]:
		# Expiration must run before contact handling. A shielded core/edge
		# contact cannot keep returning early and strand an attack forever.
		if phase_time >= well_duration:
			if kind == "white":
				game.returning_to_cruise = true
			return_to_firefight()
			return
		var force_blocked: bool = neutralise_time > 0.0 or game.combat.shield_time > 0.0
		neutralise_time = maxf(0.0, neutralise_time - delta)
		var previous_position: Vector2 = game.ship.position
		if not force_blocked:
			var direction: Vector2 = (well_position - previous_position).normalized()
			if kind == "white":
				direction = -direction
			var fraction := clampf(phase_time / well_duration, 0.0, 1.0)
			# Same average travel budget, with gentle acceleration/deceleration.
			var strength := lerpf(66.0, 86.0, fraction) if kind == "black" else lerpf(118.0, 94.0, fraction)
			strength *= proximity_multiplier
			game.ship.position += direction * strength * delta
		if game.combat.shield_time <= 0.0:
			game.ship.target_x = game.ship.position.x
		var closest := Geometry2D.get_closest_point_to_segment(well_position, previous_position, game.ship.position)
		if kind == "black" and closest.distance_to(well_position) < 29 * well_scale and game.combat.shield_time <= 0.0:
			game.lose_ship("Caught in the black hole.")
			return
		if kind == "white" and touches_screen_edge() and game.combat.shield_time <= 0.0:
			game.lose_ship("The white hole pushed you into the boundary.")
			return
	queue_redraw()

## Boss hulls are immune to player gravity, but no longer sit visually behind a
## well. They read its destination and burn sideways before the core opens.
func update_player_well_dodge(delta: float, patrol: Vector2) -> void:
	var threat: Node2D
	var nearest := INF
	for well in game.lingering_wells:
		if well.get_script()!=game.PlayerWell or well.phase == "finished":
			continue
		var distance: float = patrol.distance_squared_to(well.well_position)
		if distance < nearest:
			nearest = distance
			threat = well
	var desired := Vector2.ZERO
	if threat != null and nearest < 430.0*430.0:
		var side := 1.0 if threat.well_position.x < patrol.x else -1.0
		var target_x := clampf(patrol.x+side*190.0,84.0,game.arena.x-84.0)
		desired.x = target_x-patrol.x
		# A well placed above the boss also forces a shallow dive; otherwise the
		# boss climbs, keeping its silhouette outside the event horizon.
		desired.y = 62.0 if threat.well_position.y < patrol.y else -58.0
	var speed := 420.0 if desired != Vector2.ZERO else 190.0
	dodge_offset = dodge_offset.move_toward(desired,speed*delta)

## Aim three enemy projectiles at the ship's current position; their trajectories remain dodgeable after firing.
func fire_volley() -> void:
	var muzzle := body_position + Vector2(0, 45)
	var aim: Vector2 = (game.ship.position - muzzle).normalized()
	for angle in [-0.2, 0.0, 0.2]:
		game.spawn_hostile_shot(muzzle, aim.rotated(angle) * 245.0)

## Finish a special and schedule another firefight. Detached attacks free themselves instead of restarting.
func return_to_firefight() -> void:
	if phase == "active" and kind in ["black", "white"]:
		game.gravity_fields.add_exit(well_position, kind, well_scale)
	if lingering:
		if kind in ["asteroid", "swarm"]:
			game.burst(body_position + Vector2(0, 42), Color("ffb86a"), 18)
		game.lingering_wells.erase(self)
		queue_free()
		return
	phase = "firefight"
	phase_time = 0.0
	cooldown = game.rng.randf_range(FIREFIGHT_MIN_SECONDS, FIREFIGHT_MAX_SECONDS)
	shot_timer = 0.8
	neutralise_time = 0.0
	cannon_active = false
	queue_redraw()

## Enter the telegraph phase and launch a rift cannon or prepare a finite summoned barrage.
func begin_special() -> void:
	phase = "warning"
	phase_time = 0.0
	neutralise_time = 0.0
	if kind in ["black", "white"]:
		position_gravity_hole()
		launch_rift_cannon()
	else:
		cannon_active = false
	queue_redraw()

## Start the force/barrage timer only after the warning or cannon landing; unsafe gravity landings are redirected.
func activate_special() -> void:
	game.combat.vibrate(kind + "_spawn" if kind in ["black", "white"] else "enemy")
	if not lingering and kind in ["black", "white"] and well_position.distance_to(game.ship.position) < minf(130.0, game.arena.x * 0.22):
		position_gravity_hole()
		aim_cannon_at_hole()
		return
	cannon_active = false
	phase = "active"
	phase_time = 0.0
	neutralise_time = 0.0
	asteroid_timer = 0.0
	swarm_count = 0
	swarm_reward = {"dropped": false}
	game.sound.play_effect("rift" if kind in ["black", "white"] else "burst")
	if kind in ["black", "white"]:
		if game.combat.shield_time <= 0.0:
			game.combat.cancel()
		game.burst(well_position, Color("b9f8ff") if kind == "white" else Color("baa3ff"), 34)
		# Steering changes to tapping, so clear bullets that can no longer be dodged.
		for shot in game.projectiles.duplicate():
			if shot.hostile:
				game.remove_projectile(shot)

## Spawn the fast visual cannon at the boss muzzle and aim it at the chosen fixed well location.
func launch_rift_cannon() -> void:
	cannon_active = true
	cannon_position = body_position + Vector2(0, 46)
	cannon_previous_position = cannon_position
	aim_cannon_at_hole()

## Compute the fixed-speed cannon velocity from its current position to the well destination.
func aim_cannon_at_hole() -> void:
	var aim := well_position - cannon_position
	cannon_velocity = aim.normalized() * RIFT_CANNON_SPEED if aim.length() > 0.001 else Vector2.ZERO

## Choose a rock size and offscreen origin, then let the rock's pull/windup state machine throw it.
func summon_asteroid() -> void:
	var choice: Dictionary = ASTEROID_SIZES[game.rng.randi_range(0, ASTEROID_SIZES.size() - 1)]
	var radius: float = choice.radius
	var side: int = game.rng.randi_range(0, 2)
	var start := Vector2.ZERO
	if side == 0:
		start = Vector2(game.rng.randf_range(radius, game.arena.x - radius), -radius - 18.0)
	elif side == 1:
		start = Vector2(-radius - 18.0, game.rng.randf_range(game.top_inset + 145.0, game.arena.y - 260.0))
	else:
		start = Vector2(game.arena.x + radius + 18.0, game.rng.randf_range(game.top_inset + 145.0, game.arena.y - 260.0))
	var aim_offset := Vector2(game.rng.randf_range(-65, 65), 0)
	var velocity: Vector2 = Vector2.DOWN * game.rng.randf_range(225, 305)
	game.spawn_asteroid(start, velocity, radius, 0, body_position + Vector2(0, 42), aim_offset)
	game.sound.play_effect("fold")

## Create a tethered alien and attach the barrage's shared reward token so the swarm guarantees one drop.
func summon_alien() -> void:
	var side: int = game.rng.randi_range(0, 2)
	var start := Vector2.ZERO
	if side == 0:
		start = Vector2(game.rng.randf_range(40.0, game.arena.x - 40.0), -60.0)
	elif side == 1:
		start = Vector2(-60.0, game.rng.randf_range(game.top_inset + 140.0, game.top_inset + 340.0))
	else:
		start = Vector2(game.arena.x + 60.0, game.rng.randf_range(game.top_inset + 140.0, game.top_inset + 340.0))
	var velocity: Vector2 = Vector2.DOWN * game.rng.randf_range(185.0, 240.0)
	var alien: Node2D = game.spawn_enemy(start, velocity, true, body_position + Vector2(0, 42))
	alien.shot_timer = 0.55
	alien.drop_group = swarm_reward
	game.sound.play_effect("fold")

## Choose a lower-middle landing region, maximizing clearance if the random point is too close to the ship.
func position_gravity_hole() -> void:
	# Fixed lower-middle arena region, never a ship-relative target.
	var region := Rect2(game.arena * Vector2(0.28, 0.57), game.arena * Vector2(0.44, 0.13))
	var candidate := Vector2(game.rng.randf_range(region.position.x, region.end.x), game.rng.randf_range(region.position.y, region.end.y))
	if candidate.distance_to(game.ship.position) < 130.0:
		# The farthest corner maximizes reaction room even after prior drift.
		for corner in [region.position, region.end, Vector2(region.end.x, region.position.y), Vector2(region.position.x, region.end.y)]:
			if corner.distance_to(game.ship.position) > candidate.distance_to(game.ship.position):
				candidate = corner
	well_position = candidate
	white_push_direction = (game.ship.position - well_position).normalized()

## Check the ship's collision margin against all four screen boundaries for white-hole defeat.
func touches_screen_edge() -> bool:
	var at: Vector2 = game.ship.position
	return at.x <= EDGE_COLLISION_DISTANCE or at.x >= game.arena.x - EDGE_COLLISION_DISTANCE \
		or at.y <= EDGE_COLLISION_DISTANCE or at.y >= game.arena.y - EDGE_COLLISION_DISTANCE

## Return a normalized on/off meter value; tapping cancels force completely rather than weakening it.
func neutralisation() -> float:
	return 1.0 if neutralise_time > 0.0 else 0.0

## Refresh the short neutralisation window without applying any positional impulse to the ship.
func resist() -> void:
	if phase == "active" and kind in ["black", "white"]:
		neutralise_time = TAP_NEUTRALISE_SECONDS / proximity_multiplier
		queue_redraw()

## Ignore damage while guards remain; otherwise reduce boss health and hand victory handling to game.gd.
func take_hit(amount: int = 1) -> void:
	if game.boss_is_shielded():
		return
	# Called only by a friendly projectile collision in the game controller.
	if health <= 0 or game.state != game.State.PLAYING:
		return
	health = maxf(0.0, health - maxi(amount, 0))
	hit_flash = 0.07
	if health == 0:
		visible = false
		game.defeat_boss(self)

## Report whether this active gravity attack replaces horizontal dragging with tap-to-neutralise input.
func holds_steering() -> bool:
	return phase == "active" and kind in ["black", "white"]

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	if lingering and kind in ["asteroid", "swarm"]:
		draw_tractor_remnant()
		return
	if kind == "swarm":
		if not lingering:
			draw_swarm_body()
		return

	var tint := hole_color if kind == "black" else (Color("b9f8ff") if kind == "white" else Color("ffb86a"))
	if not lingering:
		draw_set_transform(body_position)
		draw_armored_body(tint)
		if hit_flash > 0:
			draw_circle(Vector2.ZERO, 52, Color(1, 1, 1, 0.42))
		draw_set_transform(Vector2.ZERO)
	if phase not in ["warning", "active"] or kind not in ["black", "white"]:
		return
	var active := phase == "active"
	var radius := (31.0 if active else 25.0) * well_scale
	if cannon_active:
		draw_rift_cannon(tint)
	draw_space_folds(well_position, radius, tint, active)
	# Active disks and their core masks are shared with player/lingering wells.
	if not active:
		draw_arc(well_position, radius, animation_time, animation_time + PI * 1.65, 48, tint, 2, true)
		draw_line(well_position - Vector2(9,0), well_position + Vector2(9,0), tint, 1, true)
		draw_line(well_position - Vector2(0,9), well_position + Vector2(0,9), tint, 1, true)

## Draw the three non-carrier bosses as related warships with different tools:
## gravity bosses use enclosing scythes; the forge uses armored crusher arms.
func draw_armored_body(tint: Color) -> void:
	var pulse := 0.75 + sin(animation_time * 5.0) * 0.25
	draw_circle(Vector2.ZERO,82.0,Color(tint,0.045))
	for side in [-1.0,1.0]:
		var outer: PackedVector2Array
		if kind == "asteroid":
			outer = PackedVector2Array([Vector2(side*15,-30),Vector2(side*63,-48),Vector2(side*81,-24),Vector2(side*76,26),Vector2(side*51,50),Vector2(side*47,12),Vector2(side*20,21)])
		else:
			outer = PackedVector2Array([Vector2(side*13,-28),Vector2(side*49,-54),Vector2(side*74,-62),Vector2(side*61,-28),Vector2(side*76,13),Vector2(side*60,54),Vector2(side*43,18),Vector2(side*19,25)])
		HullFinish.plate(self, outer, Color("716b7d") if kind != "asteroid" else Color("80715f"), tint, animation_time)
		var inset := PackedVector2Array([Vector2(side*20,-23),Vector2(side*50,-43),Vector2(side*62,-45),Vector2(side*50,-19),Vector2(side*61,15),Vector2(side*50,34),Vector2(side*39,8),Vector2(side*22,14)])
		HullFinish.plate(self, inset, Color("a5a4b9") if kind != "asteroid" else Color("b89770"), tint, animation_time + side * 0.3)
		draw_polyline(PackedVector2Array([Vector2(side*21,-19),Vector2(side*48,-35),Vector2(side*45,-12),Vector2(side*55,18),Vector2(side*43,25)]),Color(tint,0.85),3.2,true)
		# Twin recessed weapon/tractor ports.
		var port := Vector2(side*30,11)
		draw_circle(port,10,Color("08080d"))
		draw_arc(port,10,0,TAU,24,Color(tint,0.75),2,true)
		draw_circle(port,4.5,Color(tint,pulse))
	var hull := PackedVector2Array([Vector2(0,-61),Vector2(22,-27),Vector2(24,20),Vector2(10,49),Vector2(0,59),Vector2(-10,49),Vector2(-24,20),Vector2(-22,-27)])
	HullFinish.plate(self, hull, Color("777e94"), tint, animation_time)
	HullFinish.plate(self, PackedVector2Array([Vector2(0,-56),Vector2(0,47),Vector2(-9,39),Vector2(-17,14),Vector2(-16,-21)]), Color("b3b7c9"), tint, animation_time)
	var core_tint := Color("ffffff") if kind == "white" else tint
	draw_colored_polygon(PackedVector2Array([Vector2(0,-31),Vector2(8,-7),Vector2(7,23),Vector2(0,42),Vector2(-7,23),Vector2(-8,-7)]),Color("09080f"))
	draw_line(Vector2(0,-26),Vector2(0,34),core_tint,5.0,true)
	for y in [-17.0,-5.0,7.0,19.0]:
		draw_circle(Vector2(0,y),2.6,Color(core_tint,pulse))
	if kind == "black":
		draw_arc(Vector2(0,35),13,0,TAU,32,Color("c47cff"),3,true)
	elif kind == "white":
		draw_circle(Vector2(0,35),10,Color("ecffff"))
		draw_circle(Vector2(0,35),18,Color(tint,0.16))
	else:
		HullFinish.plate(self, PackedVector2Array([Vector2(-17,35),Vector2(0,55),Vector2(17,35),Vector2(0,24)]), Color("b38660"), tint, animation_time)
		draw_line(Vector2(-10,36),Vector2(0,48),Color("ffb86a"),3,true)
		draw_line(Vector2(10,36),Vector2(0,48),Color("ffb86a"),3,true)

## Render the carrier's distinctive body and hangars; this is cosmetic geometry, not collision geometry.
func draw_swarm_body() -> void:
	var tint := Color("c26bff")
	var pulse := 0.5 + sin(animation_time * 4.0) * 0.5
	draw_set_transform(body_position)
	draw_circle(Vector2.ZERO, 94.0, Color(tint, 0.05))
	# Four hooked hangar blades echo the small alien while making the carrier's
	# wider, predatory silhouette instantly distinct from the gravity bosses.
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			Vector2(side * 18.0, -37.0), Vector2(side * 63.0, -62.0),
			Vector2(side * 88.0, -47.0), Vector2(side * 68.0, -13.0),
			Vector2(side * 86.0, 29.0), Vector2(side * 62.0, 66.0),
			Vector2(side * 45.0, 18.0), Vector2(side * 23.0, 27.0)
		])
		HullFinish.plate(self, wing, Color("807589"), tint, animation_time)
		var raised := PackedVector2Array([Vector2(side*30,-31),Vector2(side*61,-49),Vector2(side*73,-45),Vector2(side*58,-13),Vector2(side*72,30),Vector2(side*60,44),Vector2(side*48,10)])
		HullFinish.plate(self, raised, Color("b599c3"), tint, animation_time + side * 0.3)
		draw_line(Vector2(side * 52.0, -39.0), Vector2(side * 63.0, 29.0), Color(tint,0.85), 4.0, true)
		for i in range(3):
			var dock := Vector2(side * (43.0 + float(i) * 9.0), -25.0 + float(i) * 22.0)
			draw_circle(dock,7.0,Color("08080d"))
			draw_circle(dock, 3.0, Color(tint, 0.45 + pulse * 0.4))
	var hull := PackedVector2Array([Vector2(0,-64),Vector2(29,-31),Vector2(30,27),Vector2(0,58),Vector2(-30,27),Vector2(-29,-31)])
	HullFinish.plate(self, hull, Color("8a809c"), tint, animation_time)
	HullFinish.plate(self, PackedVector2Array([Vector2(0,-58),Vector2(0,48),Vector2(-13,32),Vector2(-18,-23)]), Color("c1aacd"), tint, animation_time)
	for side in [-1.0, 1.0]:
		var eye := PackedVector2Array([Vector2(side*5,-13),Vector2(side*23,-27),Vector2(side*19,-3),Vector2(side*6,5)])
		draw_colored_polygon(eye, tint)
	draw_circle(Vector2(0, 29), 13.0 + pulse, Color(tint, 0.17))
	draw_circle(Vector2(0, 29), 6.0, Color("f1dcff"))
	if phase in ["warning", "active", "clearing"]:
		draw_arc(Vector2(0, 42), 16.0 + pulse * 3.0, animation_time * 2.0, animation_time * 2.0 + TAU * 0.8, 32, Color(tint, 0.6), 2.0, true)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, 40.0, Color(1, 1, 1, 0.5))
	draw_set_transform(Vector2.ZERO)

## Draw inward or outward animated rings around a well; the screen shader provides background distortion.
func draw_space_folds(center: Vector2, core_radius: float, tint: Color, active: bool) -> void:
	# The background shader bends the sky. These sparse glints sit on its ridges.
	var direction := 1.0 if kind == "white" else -1.0
	var spacing := TAU / 0.255
	var offset := fposmod(animation_time * direction * 5.5 / 0.255, spacing)
	var outer := (164.0 if active else 112.0) * well_scale
	for i in range(6):
		var ring_radius := core_radius + offset + i * spacing
		if ring_radius > outer:
			break
		var envelope := (1.0 - smoothstep(outer * 0.66, outer, ring_radius)) * smoothstep(core_radius, core_radius + 12.0, ring_radius)
		var points := PackedVector2Array()
		for n in range(33):
			var angle := -2.9 + float(n) / 32.0 * 1.7
			points.append(center + Vector2(cos(angle), sin(angle) * 0.83) * ring_radius)
		draw_polyline(points, Color(tint, envelope * (0.17 if active else 0.05)), 1.0, true)

## Render the traveling space-fold projectile and its luminous tail.
func draw_rift_cannon(tint: Color) -> void:
	var trail := PackedVector2Array()
	var direction := cannon_velocity.normalized()
	var side := direction.orthogonal()
	for i in range(18):
		var t := float(i) / 17.0
		var base := cannon_position - direction * t * 86.0
		var wave := side * sin(animation_time * 24.0 + t * 16.0) * (10.0 * (1.0 - t))
		trail.append(base + wave)
	draw_polyline(trail, Color(tint, 0.24), 7.0, true)
	draw_polyline(trail, Color(tint, 0.55), 2.4, true)
	draw_circle(cannon_position, 9.5, Color("f5ffff") if kind == "white" else Color("f0e5ff"))
	draw_circle(cannon_position, 17.0, Color(tint, 0.25))

## The destroyed carrier leaves a broken, still-powered tractor core. Its
## position is the original tether origin, and its lifetime is the attack's own.
func draw_tractor_remnant() -> void:
	var at := body_position + Vector2(0, 42)
	var tint := Color("79f4c4") if kind == "swarm" else Color("ffb86a")
	draw_circle(at, 46, Color(tint, 0.06))
	for i in range(5):
		var angle := i * TAU / 5.0 + sin(animation_time) * 0.08
		var offset := Vector2.from_angle(angle) * 25.0
		draw_colored_polygon(PackedVector2Array([at + offset, at + offset * 1.5 + Vector2(9, 4), at + offset * 1.4 - Vector2(4, 8)]), tint.darkened(0.5))
		draw_arc(at, 31, angle, angle + 0.65, 12, Color(tint, 0.7), 3, true)
	draw_circle(at, 11 + sin(animation_time * 17) * 2, tint)
	draw_circle(at, 5, Color.WHITE)
