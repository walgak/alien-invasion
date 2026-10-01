extends Node2D
## Pairwise gravity rules. Operate on active wells only; traveling cannons do not
## collide. Merges conserve area and remaining lifetime, never restart a timer.
const PlayerWell = preload("res://scripts/player_well.gd")
const AccretionVisual = preload("res://scripts/accretion_visual.gd")
const BossCollapse = preload("res://scripts/boss_collapse.gd")
const CoalescenceVisual = preload("res://scripts/blackhole_coalescence.gd")
const MAX_ACCRETION_VISUALS := 12
var game: Node2D
var shockwaves: Array[Dictionary] = []
var exits: Array[Dictionary] = []
var accretion_pool: Array[Node2D] = []
var collapses: Array[Node2D] = []
var coalescence_pool: Array[Node2D] = []
var coalescence_pairs: Array[Dictionary] = []
var coalescence_radii: Dictionary = {}
# Store travel in logical pixels, not elapsed time: accelerating fields must
# accelerate their ripples too. Instance IDs avoid retaining a closed well.
const RIPPLE_SPEED_MULTIPLIER := 3.0
const RIPPLE_WAVELENGTH := 112.0
var ripple_travel: Dictionary = {}

## A second field freezes all participating lifetimes until a merge/discharge
## resolves the encounter. Animation, resistance windows and movement continue.
func lifetime_frozen(well: Node2D) -> bool:
	return well.holds_steering() and active_wells().size() >= 2

## Sum vectors before moving anything. Distance weights are bounded; opposing
## forces cancel rather than depending on which well happened to update first.
func net_force_for(actor: Node2D) -> Vector2:
	if actor == game.ship and game.combat.shield_time > 0.0:
		return Vector2.ZERO
	var force := Vector2.ZERO
	for well in active_wells():
		if actor != game.ship and not well is PlayerWell:
			continue
		force += force_from_well(well, actor.position)
	return force.limit_length(180.0)

## The shared physical force before tap/shield cancellation. Ripples use this
## same speed, including distance, acceleration and white-field interaction.
## With multiple fields each wave represents its own field, not the resultant
## vector (opposing forces may cancel, but their waves should remain visible).
func force_from_well(well: Node2D, at: Vector2) -> Vector2:
	var offset: Vector2 = well.well_position - at
	var weight := clampf(220.0 / maxf(offset.length(), 80.0), 0.35, 1.8)
	var strength: float
	if well is PlayerWell:
		strength = well.PULL_SPEED * (0.86 + 0.14 * clampf(well.active_age / 2.0, 0.0, 1.0))
	else:
		var progress := clampf(well.phase_time / maxf(well.well_duration, 0.001), 0.0, 1.0)
		strength = (lerpf(66.0, 86.0, progress) if well.kind == "black" else -lerpf(118.0, 94.0, progress)) * well.proximity_multiplier
	return offset.normalized() * strength * weight

## Integrate distance once per simulation frame. Phase wraps after one complete
## wavelength with no visual seam, preventing precision loss in endless play.
## No real-time shader clock: paused games also pause every ripple exactly.
func advance_ripples(delta: float) -> void:
	var live_ids: Dictionary = {}
	for well in active_wells():
		var id := well.get_instance_id()
		live_ids[id] = true
		var speed := force_from_well(well, game.ship.position).limit_length(180.0).length()
		ripple_travel[id] = fposmod(float(ripple_travel.get(id, 0.0)) + speed * RIPPLE_SPEED_MULTIPLIER * delta, RIPPLE_WAVELENGTH)
	for id in ripple_travel.keys():
		if not live_ids.has(id):
			ripple_travel.erase(id)

func ripple_distance(well: Node2D) -> float:
	return float(ripple_travel.get(well.get_instance_id(), 0.0))

## The controller calls this once each physics frame. A neutralising tap is an
## exact zero displacement, including in overlapping opposed fields.
func apply_player_force(delta: float) -> void:
	var wells := active_wells()
	# Expiration wins over lethal contact, matching the original boss contract.
	# A lone last-frame core must not swallow the ship on the frame it closes.
	if wells.size() == 1 and seconds_left(wells[0]) <= delta:
		close_well(wells[0])
		return
	if wells.is_empty() or game.combat.shield_time > 0.0:
		return
	var previous: Vector2 = game.ship.position
	var neutralised: bool = wells.any(func(well: Node2D) -> bool: return well.neutralise_time > 0.0)
	if not neutralised:
		game.ship.position += net_force_for(game.ship) * delta
	game.ship.target_x = game.ship.position.x
	for well in wells:
		if well.kind == "black" and Geometry2D.get_closest_point_to_segment(well.well_position, previous, game.ship.position).distance_to(well.well_position) < core_radius(well) - 2.0:
			game.lose_ship("Caught in the black hole.")
			return
		if well.kind == "white" and well.touches_screen_edge():
			game.lose_ship("The white hole pushed you into the boundary.")
			return

## Player wells share one actor-motion owner, preventing double integration.
func owns_actor_motion(well: Node2D) -> bool:
	for candidate in active_wells():
		if candidate is PlayerWell:
			return candidate == well
	return false

## Gravity rockets detonate at the first existing horizon they cross. Analytic
## segment/circle intersection prevents tunnelling at their fivefold speed.
func intercept_cannon(from: Vector2, to: Vector2, exclude: Node2D) -> Dictionary:
	var best := 2.0
	var result: Dictionary = {}
	var velocity := to - from
	var length_squared := velocity.length_squared()
	if length_squared < 0.0001:
		return result
	for well in active_wells():
		if well == exclude:
			continue
		var radius: float = core_radius(well)
		var offset: Vector2 = from - well.well_position
		var projection := offset.dot(velocity)
		var discriminant := projection * projection - length_squared * (offset.length_squared() - radius * radius)
		if discriminant < 0.0:
			continue
		# Both roots behind the ray origin mean the projectile is moving away;
		# clamping a negative entry root alone would invent an immediate impact.
		var exit_fraction := (-projection + sqrt(discriminant)) / length_squared
		if exit_fraction < 0.0:
			continue
		var fraction := maxf(0.0, (-projection - sqrt(discriminant)) / length_squared)
		if fraction <= 1.0 and fraction < best:
			best = fraction
			var contact: Vector2 = from + velocity * fraction
			var normal: Vector2 = (contact - well.well_position).normalized()
			if normal == Vector2.ZERO:
				normal = -velocity.normalized()
			result = {"at": well.well_position + normal * (radius + 2.0), "well": well}
	return result

## Snapshot the defeated hull before its node is freed. A finite presentation
## object opens the larger death field only after the visible transformation.
func add_boss_collapse(defeated: Node2D) -> void:
	var effect := BossCollapse.new()
	effect.game = game
	effect.configure(defeated)
	add_child(effect)
	collapses.append(effect)

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
		show_accretion(used, well.well_position, core_radius(well), well.kind == "white", well.hole_color)
		used += 1
	if game.death_time > 0.0 and game.death_is_gravity and used < MAX_ACCRETION_VISUALS:
		show_accretion(used, game.death_target, game.death_radius, false, game.death_hole_color)
		used += 1
	for i in range(used, accretion_pool.size()):
		accretion_pool[i].visible = false
	update_coalescence_visuals()

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
func close_well(well: Node2D, departing_force: Vector2 = Vector2.INF) -> void:
	if well is PlayerWell:
		well.finish_well(departing_force)
	else:
		well.return_to_firefight(departing_force)

## Advance attraction, repulsion and safe annihilation, then delayed blast damage.
func step(delta: float) -> void:
	var wells := active_wells()
	var whites := wells.filter(func(well: Node2D) -> bool: return well.kind == "white")
	for well in whites:
		well.proximity_multiplier = 1.0
		if whites.size() >= 2:
			well.proximity_multiplier += 2.0 * clampf(1.0 - well.well_position.distance_to(game.ship.position) / 350.0, 0.0, 1.0)
			well.pressure_front_radius = maxf(well.pressure_front_radius, 31.0 * well.well_scale) + 110.0 * delta
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
			var motion := direction * minf(45.0 * delta, distance * 0.25 + 0.1)
			if a.kind == "white" and b.kind == "white":
				motion = -motion
			if a.kind == "black" and b.kind == "black":
				# Preserve the centre of mass while unequal droplets draw together.
				var mass_a: float = a.well_scale * a.well_scale
				var mass_b: float = b.well_scale * b.well_scale
				a.well_position += motion * 2.0 * mass_b / (mass_a + mass_b)
				b.well_position -= motion * 2.0 * mass_a / (mass_a + mass_b)
			else:
				a.well_position += motion
				b.well_position -= motion
			if a.kind == "white" and b.kind == "white":
				for well in [a, b]:
					well.well_position = well.well_position.clamp(Vector2(35, 35), game.arena - Vector2(35, 35))
				if a.pressure_front_radius + b.pressure_front_radius >= a.well_position.distance_to(b.well_position):
					visual_shockwave((a.well_position + b.well_position) * 0.5)
					var departing_force := net_force_for(game.ship)
					close_well(a, departing_force)
					close_well(b, departing_force)
					game.sound.play_effect("rift")
					break
				continue
			if a.well_position.distance_to(b.well_position) > 31.0 * (a.well_scale + b.well_scale):
				continue
			if a.kind != b.kind:
				shockwaves.append({"at": (a.well_position + b.well_position) * 0.5, "age": 0.0, "radius": minf(280.0, 80.0 + 31.0 * (a.well_scale + b.well_scale)), "fired": false})
				var departing_force := net_force_for(game.ship)
				close_well(a, departing_force)
				close_well(b, departing_force)
				game.sound.play_effect("rift")
				game.combat.vibrate("gravity")
				break
			# Contact begins coalescence; the neck relaxes as the two centres
			# continue together. Only then transfer identity/lifetime atomically.
			if a.well_position.distance_to(b.well_position) > 3.0:
				continue
			merge(a, b)
			break # Recollect identities next frame, avoiding stale merged entries.
	update_coalescence_shapes()
	advance_ripples(delta)
	for wave in shockwaves.duplicate():
		wave.age += delta
		if wave.age >= 0.35 and not wave.fired and not wave.get("visual_only", false):
			wave.fired = true
			for enemy in game.enemies.duplicate():
				if enemy.position.distance_to(wave.at) <= wave.radius:
					# A player-generated gravity chain must not refill its own charge.
					game.destroy_enemy(enemy, false)
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
	# Coalescence is not an expiry: do not emit a second collapsing core/exiting
	# field at the consumed lobe, or kick the player as if the gravity had ended.
	if b is PlayerWell:
		b.phase = "finished"
		game.lingering_wells.erase(b)
		b.queue_free()
	else:
		b.phase = "firefight"
		b.return_to_firefight(Vector2.ZERO)
	game.sound.play_effect("rift")
	game.combat.vibrate("gravity")

## Preserve the sum of both original disc areas as their silhouettes overlap.
## Original well_scale remains the mass, so merging cannot create extra mass.
func disc_union_area(first: float, second: float, distance: float) -> float:
	if distance >= first + second:
		return PI * (first * first + second * second)
	if distance <= absf(first - second) + 0.001:
		return PI * maxf(first * first, second * second)
	var angle_a := acos(clampf((distance * distance + first * first - second * second) / (2.0 * distance * first), -1.0, 1.0))
	var angle_b := acos(clampf((distance * distance + second * second - first * first) / (2.0 * distance * second), -1.0, 1.0))
	var triangle := 0.5 * sqrt(maxf(0.0, (-distance + first + second) * (distance + first - second) * (distance - first + second) * (distance + first + second)))
	return PI * (first * first + second * second) - first * first * angle_a - second * second * angle_b + triangle

## A bounded eight-step bisection conserves visible volume without per-pixel
## simulation. These radii also drive swallowing/projectile/core collision tests.
func droplet_radii(first: float, second: float, distance: float) -> Vector2:
	var area := PI * (first * first + second * second)
	var low := 1.0
	var high := sqrt(2.0)
	for iteration in range(8):
		var scale := (low + high) * 0.5
		if disc_union_area(first * scale, second * scale, distance) < area:
			low = scale
		else:
			high = scale
	return Vector2(first, second) * ((low + high) * 0.5)

## One well can join one liquid neck at a time. Nearest surfaces pair first,
## keeping the total number of shader quads bounded by half the active wells.
func update_coalescence_shapes() -> void:
	coalescence_pairs.clear()
	coalescence_radii.clear()
	var candidates: Array[Dictionary] = []
	var wells := active_wells()
	for i in range(wells.size()):
		for j in range(i + 1, wells.size()):
			var a: Node2D = wells[i]
			var b: Node2D = wells[j]
			if a.kind != "black" or b.kind != "black":
				continue
			var radius_a: float = 31.0 * a.well_scale
			var radius_b: float = 31.0 * b.well_scale
			var distance: float = a.well_position.distance_to(b.well_position)
			var gap: float = distance - radius_a - radius_b
			if gap < 22.0:
				candidates.append({"first": a, "second": b, "gap": gap, "radii": droplet_radii(radius_a, radius_b, distance)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap < b.gap)
	for pair in candidates:
		var first_id: int = pair.first.get_instance_id()
		var second_id: int = pair.second.get_instance_id()
		if coalescence_radii.has(first_id) or coalescence_radii.has(second_id):
			continue
		coalescence_radii[first_id] = pair.radii.x
		coalescence_radii[second_id] = pair.radii.y
		coalescence_pairs.append(pair)

## Every consumer should use this physical radius during coalescence instead of
## deriving it from mass alone. Outside merging, it is exactly the original size.
func core_radius(well: Node2D) -> float:
	return coalescence_radii.get(well.get_instance_id(), 31.0 * well.well_scale)

func update_coalescence_visuals() -> void:
	var used := 0
	for pair in coalescence_pairs:
		if not is_instance_valid(pair.first) or not is_instance_valid(pair.second) or not pair.first.holds_steering() or not pair.second.holds_steering():
			continue
		if used == coalescence_pool.size():
			var visual := CoalescenceVisual.new()
			add_child(visual)
			coalescence_pool.append(visual)
		coalescence_pool[used].configure(pair.first.well_position, pair.second.well_position, pair.radii.x, pair.radii.y, pair.first.hole_color.lerp(pair.second.hole_color, 0.5), game.visual_time)
		used += 1
	for i in range(used, coalescence_pool.size()):
		coalescence_pool[i].visible = false

## A compact warning flash expands into a readable, player-safe shock ring.
func _draw() -> void:
	draw_guard_shield()
	draw_exits()
	for wave in shockwaves:
		if wave.age < 0.35:
			draw_circle(wave.at, 15 + wave.age * 90, Color(0.8, 0.9, 1, 0.7))
		else:
			var progress: float = clampf((wave.age - 0.35) / 0.75, 0.0, 1.0)
			draw_soft_light(wave.at, maxf(1.0, wave.radius * progress), Color("b9f8ff"), (1.0 - progress) * 0.18)

	# Always composite opaque cores last. Ships, beam filaments and hull shards
	# must never show through the event horizon regardless of scene insertion order.
	for well in active_wells():
		if well.kind == "black":
			draw_horizon(well.well_position, core_radius(well), well.hole_color)
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
	for collapse in collapses.duplicate():
		if game.state != game.State.PLAYING:
			collapses.erase(collapse)
			collapse.queue_free()
		else:
			collapse.step(delta)
	for effect in exits.duplicate():
		effect.age += delta
		if effect.age >= 1.2:
			exits.erase(effect)
	queue_redraw()

## Restart/title transitions must not leave a delayed boss death field queued.
func clear_collapses() -> void:
	ripple_travel.clear()
	for collapse in collapses:
		collapse.queue_free()
	collapses.clear()
	coalescence_pairs.clear()
	coalescence_radii.clear()
	for visual in coalescence_pool:
		visual.visible = false

## Fine plasma is drawn by the reusable textured sprites behind actors. This
## final opaque mask makes the event horizon absolute even during ship crumble.
func draw_horizon(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at, radius, Color.BLACK)

## A white singularity is a radiant source with the same physical core size.
## The surrounding sprite runs its radial plasma motion outward, not inward.
func draw_white_core(at: Vector2, radius: float) -> void:
	for layer in range(24, 0, -1):
		var fraction := float(layer) / 24.0
		var tint := Color("a4e4ff").lerp(Color("ffffef"), pow(1.0 - fraction, 0.45))
		draw_circle(at, radius * fraction, tint)

## The full shield silhouette is refraction, never a stroked circle or spokes.
## Its soft light weakens with the guards; a separate gravity-only field is
## visible while the boss avoids a player horizon and grants no damage immunity.
func draw_guard_shield() -> void:
	if not is_instance_valid(game.boss) or game.boss.phase == "arrival":
		return
	var guards: Array = game.enemies.filter(func(e: Node2D) -> bool: return e.shield_guard)
	var gravity_shield: bool = game.boss.has_player_gravity_threat()
	if guards.is_empty() and not gravity_shield:
		return
	var strength := float(guards.size()) / maxf(1.0, game.boss.guard_total)
	var center: Vector2 = game.boss.body_position
	draw_soft_light(center, game.boss.shield_radius() + 8.0, Color("8f95ff") if gravity_shield else Color("69d9ff"), 0.008 + strength * 0.014)

## Nested filled discs form a soft light volume without a painted outline.
func draw_soft_light(at: Vector2, radius: float, tint: Color, alpha: float) -> void:
	for layer in range(7, 0, -1):
		var fraction := float(layer) / 7.0
		draw_circle(at, radius * fraction, Color(tint, alpha * (1.0 - fraction * 0.72)))

## Black: contract first, then release. White: immediate outward energy and two
## expanding folds. All counts are fixed so larger charges cost no extra geometry.
func draw_exits() -> void:
	for effect in exits:
		var age: float = effect.age
		var black: bool = effect.kind == "black"
		var tint := Color("b894ff") if black else Color("b9f8ff")
		var outward_age: float = age - (0.55 if black else 0.0)
		if black and age < 0.55:
			draw_circle(effect.at, maxf(0.1, effect.radius * (1.0 - age / 0.55)), Color("01030a"))
		if outward_age >= 0.0:
			var t := clampf(outward_age / 0.65, 0, 1)
			draw_soft_light(effect.at, 22.0 + sqrt(t) * (effect.radius + 185.0), tint, (1.0 - t) * (0.28 if not black else 0.18))
			# White departure immediately releases the compressed screen bubble.
			if not black:
				draw_rect(Rect2(Vector2.ZERO, game.arena), Color("d8f9ff", pow(1.0 - t, 4.0) * 0.22))
