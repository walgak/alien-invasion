extends Node2D
## Pairwise gravity rules. Operate on active wells only; traveling cannons do not
## collide. Merges conserve area and remaining lifetime, never restart a timer.
const PlayerWell = preload("res://scripts/player_well.gd")
const AccretionVisual = preload("res://scripts/accretion_visual.gd")
const MAX_ACCRETION_VISUALS := 12
var game: Node2D
var shockwaves: Array[Dictionary] = []
var exits: Array[Dictionary] = []
var accretion_pool: Array[Node2D] = []

## Reuse the same small visual pool across launches, merges and deaths. Large
## charged fields change uniforms and quad size, never the number of particles.
func update_visuals() -> void:
	var used := 0
	for well in active_wells():
		if used >= MAX_ACCRETION_VISUALS:
			break
		# The death view below replaces this field rather than doubling its glow.
		if game.death_time > 0.0 and game.death_is_gravity and well.kind == "black" and well.well_position.distance_to(game.death_target) < 1.0:
			continue
		show_accretion(used, well.well_position, 31.0 * well.well_scale, well.kind == "white", well.hole_color)
		used += 1
	if game.death_time > 0.0 and game.death_is_gravity and used < MAX_ACCRETION_VISUALS:
		show_accretion(used, game.death_target, game.death_radius, false, game.death_hole_color)
		used += 1
	for i in range(used, accretion_pool.size()):
		accretion_pool[i].visible = false

func show_accretion(index: int, at: Vector2, radius: float, white: bool, tint: Color) -> void:
	if index == accretion_pool.size():
		var visual := AccretionVisual.new()
		add_child(visual)
		accretion_pool.append(visual)
	accretion_pool[index].configure(at, radius, white, Color("56ceff") if white else tint, game.visual_time)

## This layer occludes every actor inside an event horizon, but stays below HUD.
func _init() -> void:
	z_index = 32

## Collect every live field once, including the still-living boss's current field.
func active_wells() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for well in game.lingering_wells:
		if well.holds_steering() and not well.is_queued_for_deletion():
			result.append(well)
	if is_instance_valid(game.boss) and game.boss.holds_steering():
		result.append(game.boss)
	return result

## Read remaining seconds from either kind of attack implementation.
func seconds_left(well: Node2D) -> float:
	return well.remaining if well is PlayerWell else maxf(0.0, well.well_duration - well.phase_time)

## Close an individual field without killing its owning boss or other attacks.
func close_well(well: Node2D) -> void:
	if well is PlayerWell:
		well.finish_well()
	else:
		if well.kind == "white":
			game.returning_to_cruise = true
		well.return_to_firefight()

## Advance attraction, repulsion and safe annihilation, then delayed blast damage.
func step(delta: float) -> void:
	var wells := active_wells()
	var whites := wells.filter(func(well: Node2D) -> bool: return well.kind == "white")
	for well in whites:
		well.proximity_multiplier = 1.0
		if whites.size() >= 2:
			well.proximity_multiplier += 2.0 * clampf(1.0 - well.well_position.distance_to(game.ship.position) / 350.0, 0.0, 1.0)
	for i in range(wells.size()):
		var a: Node2D = wells[i]
		if not a.holds_steering() or a.is_queued_for_deletion():
			continue
		for j in range(i + 1, wells.size()):
			var b: Node2D = wells[j]
			if not b.holds_steering() or b.is_queued_for_deletion():
				continue
			var offset: Vector2 = b.well_position - a.well_position
			var distance := offset.length()
			var direction := offset.normalized() if distance > 0.01 else Vector2.RIGHT
			if a.kind == b.kind:
				var motion := direction * minf(35.0 * delta, distance * 0.25 + 0.1)
				if a.kind == "white":
					motion = -motion
				a.well_position += motion
				b.well_position -= motion
				if a.kind == "white":
					for well in [a, b]:
						well.well_position = well.well_position.clamp(Vector2(35, game.top_inset + 170), game.arena - Vector2(35, 35))
			if a.kind == "white" and b.kind == "white":
				continue
			if a.well_position.distance_to(b.well_position) > 31.0 * (a.well_scale + b.well_scale):
				continue
			if a.kind != b.kind:
				shockwaves.append({"at": (a.well_position + b.well_position) * 0.5, "age": 0.0, "radius": minf(280.0, 80.0 + 31.0 * (a.well_scale + b.well_scale)), "fired": false})
				close_well(a)
				close_well(b)
				game.sound.play_effect("rift")
				game.combat.vibrate("gravity")
				break
			merge(a, b)
			break # Recollect identities next frame, avoiding stale merged entries.
	for wave in shockwaves.duplicate():
		wave.age += delta
		if wave.age >= 0.35 and not wave.fired and not wave.get("visual_only", false):
			wave.fired = true
			for enemy in game.enemies.duplicate():
				if enemy.position.distance_to(wave.at) <= wave.radius:
					game.damage_target(enemy, "enemy", enemy.health)
			for rock in game.asteroids.duplicate():
				if rock.position.distance_to(wave.at) <= wave.radius:
					game.damage_target(rock, "rock", 5)
			if is_instance_valid(game.boss) and game.boss.body_position.distance_to(wave.at) <= wave.radius:
				game.damage_target(game.boss, "boss", 5)
			for shot in game.projectiles.duplicate():
				if shot.position.distance_to(wave.at) <= wave.radius:
					game.remove_projectile(shot)
			game.burst(wave.at, Color("b9f8ff"), 45)
		if wave.age >= 1.1:
			shockwaves.erase(wave)
	queue_redraw()

## Prefer a player well so its affected-actor bookkeeping survives merging with
## a boss well. Radius follows sqrt(area), consistent with charge-to-size scaling.
func merge(first: Node2D, second: Node2D) -> void:
	var a: Node2D = second if second is PlayerWell else first
	var b: Node2D = first if a == second else second
	var area: float = a.well_scale * a.well_scale + b.well_scale * b.well_scale
	a.well_position = (a.well_position * a.well_scale * a.well_scale + b.well_position * b.well_scale * b.well_scale) / area
	var duration := seconds_left(a) + seconds_left(b)
	a.well_scale = sqrt(area)
	if a is PlayerWell:
		a.remaining = duration
		if b is PlayerWell:
			for id in b.origins.keys():
				if not a.origins.has(id):
					a.origins[id] = b.origins[id]
			b.origins.clear()
	else:
		a.well_duration = a.phase_time + duration
	close_well(b)
	game.sound.play_effect("rift")
	game.combat.vibrate("gravity")

## A compact warning flash expands into a readable, player-safe shock ring.
func _draw() -> void:
	draw_guard_shield()
	draw_exits()
	for wave in shockwaves:
		if wave.age < 0.35:
			draw_circle(wave.at, 15 + wave.age * 90, Color(0.8, 0.9, 1, 0.7))
		else:
			var progress: float = clampf((wave.age - 0.35) / 0.75, 0.0, 1.0)
			draw_arc(wave.at, maxf(1.0, wave.radius * progress), 0, TAU, 96, Color(0.7, 0.95, 1, 1 - progress), 6, true)

	# Always composite opaque cores last. Ships, beam filaments and hull shards
	# must never show through the event horizon regardless of scene insertion order.
	for well in active_wells():
		if well.kind == "black":
			draw_horizon(well.well_position, 31.0 * well.well_scale, well.hole_color)
		elif well.kind == "white":
			draw_white_core(well.well_position, 31.0 * well.well_scale)
	if game.death_time > 0.0 and game.death_is_gravity:
		draw_horizon(game.death_target, game.death_radius, game.death_hole_color)

## Visual-only fallback for a shielded escape-cannon impact: no damage or force.
func visual_shockwave(at: Vector2) -> void:
	shockwaves.append({"at": at, "age": 0.35, "radius": 190.0, "fired": true, "visual_only": true})

## Expiring fields leave two folds and an energy release, independent of physics.
func add_exit(at: Vector2, kind: String, size: float) -> void:
	if exits.size() >= 12:
		exits.pop_front()
	exits.append({"at": at, "kind": kind, "radius": 31.0 * size, "age": 0.0})

## The visual clock keeps exit effects finite without keeping a gravity force alive.
func visual_step(delta: float) -> void:
	for effect in exits.duplicate():
		effect.age += delta
		if effect.age >= 1.2:
			exits.erase(effect)
	queue_redraw()

## Fine plasma is drawn by the reusable textured sprites behind actors. This
## final opaque mask makes the event horizon absolute even during ship crumble.
func draw_horizon(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at, radius, Color.BLACK)
	draw_arc(at, radius + 0.5, 0, TAU, 112, Color(color.lightened(0.72), 0.72), 0.9, true)

## A white singularity is a radiant source with the same physical core size.
## The surrounding sprite runs its radial plasma motion outward, not inward.
func draw_white_core(at: Vector2, radius: float) -> void:
	for layer in range(24, 0, -1):
		var fraction := float(layer) / 24.0
		var tint := Color("a4e4ff").lerp(Color("ffffef"), pow(1.0 - fraction, 0.45))
		draw_circle(at, radius * fraction, tint)
	draw_arc(at, radius + 0.6, 0, TAU, 96, Color("efffff"), 1.3, true)

## Hull shield strength is tied to living guards, not boss health. Individual
## strands make the connection to each guard obvious, and fade as guards die.
func draw_guard_shield() -> void:
	if not is_instance_valid(game.boss) or game.boss.phase == "arrival":
		return
	var guards: Array = game.enemies.filter(func(e: Node2D) -> bool: return e.shield_guard)
	if guards.is_empty():
		return
	var strength := float(guards.size()) / maxf(1.0, game.boss.guard_total)
	var center: Vector2 = game.boss.body_position
	draw_circle(center, 76, Color(0.2, 0.75, 1, 0.025 + strength * 0.075))
	for i in range(12):
		var angle: float = float(i) * TAU / 12.0 + game.visual_time * 0.06
		draw_arc(center, 76, angle, angle + TAU / 12.0 * (0.3 + 0.65 * strength), 8, Color(0.35, 0.86, 1, 0.18 + 0.55 * strength), 1.0 + strength * 2.0, true)
	for guard in guards:
		var direction: Vector2 = (guard.position - center).normalized()
		draw_line(center + direction * 76, guard.position, Color(0.3, 0.8, 1, 0.15 + strength * 0.2), 1.5, true)

## Black: contract first, then release. White: immediate outward energy and two
## expanding folds. All counts are fixed so larger charges cost no extra geometry.
func draw_exits() -> void:
	for effect in exits:
		var age: float = effect.age
		var black: bool = effect.kind == "black"
		var tint := Color("b894ff") if black else Color("b9f8ff")
		var outward_age: float = age - (0.55 if black else 0.0)
		for ring in range(2):
			var t := clampf((age - float(ring) * 0.09) / (0.55 if black else 0.95), 0.0, 1.0)
			var radius: float = (effect.radius + 95.0) * (1.0 - t) if black else effect.radius + t * 180.0
			if t < 1.0:
				draw_arc(effect.at, maxf(1.0, radius), 0, TAU, 80, Color(tint, (1.0 - t) * 0.65), 2.5, true)
		if black and age < 0.55:
			draw_circle(effect.at, maxf(0.1, effect.radius * (1.0 - age / 0.55)), Color("01030a"))
		if outward_age >= 0.0:
			var t := clampf(outward_age / 0.65, 0, 1)
			for ray in range(20):
				var direction := Vector2.from_angle(float(ray) * TAU / 20.0 + float(ray % 3) * 0.07)
				var radius: float = 15 + sqrt(t) * (125 + ray % 4 * 14)
				draw_line(effect.at + direction * radius * 0.65, effect.at + direction * radius, Color(tint, (1 - t) * 0.65), 2, true)
