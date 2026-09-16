extends Node2D
## Pairwise gravity rules. Operate on active wells only; traveling cannons do not
## collide. Merges conserve area and remaining lifetime, never restart a timer.
const PlayerWell = preload("res://scripts/player_well.gd")
var game: Node2D
var shockwaves: Array[Dictionary] = []

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
		if wave.age >= 0.35 and not wave.fired:
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
			for actor in b.origins:
				if not a.origins.has(actor):
					a.origins[actor] = b.origins[actor]
			b.origins.clear()
	else:
		a.well_duration = a.phase_time + duration
	close_well(b)
	game.sound.play_effect("rift")
	game.combat.vibrate("gravity")

## A compact warning flash expands into a readable, player-safe shock ring.
func _draw() -> void:
	for wave in shockwaves:
		if wave.age < 0.35:
			draw_circle(wave.at, 15 + wave.age * 90, Color(0.8, 0.9, 1, 0.7))
		else:
			var progress: float = clampf((wave.age - 0.35) / 0.75, 0.0, 1.0)
			draw_arc(wave.at, maxf(1.0, wave.radius * progress), 0, TAU, 96, Color(0.7, 0.95, 1, 1 - progress), 6, true)
