extends Node2D
## A player-launched gravity rocket, then a finite well. Boss-compatible fields
## let the existing background refraction pass render the same spatial folding.

var game: Node2D
var kind := "black"
var phase := "warning"
var well_position := Vector2.ZERO
var cannon_position := Vector2.ZERO
var charge := 1.0
var well_scale := 0.9
var animation_time := 0.0
var remaining := 0.0
var neutralise_time := 0.0
var origins: Dictionary[int, Vector2] = {}
## Stable instance IDs survive deletion; never use freed Nodes as dictionary keys.
var active_age := 0.0
var hole_color := Color("358cff")
const PULL_SPEED := 90.0
const MIN_LIFETIME := 3.0
const MAX_LIFETIME := 7.5

## Player charge grows a compact core, rather than dwarfing a boss's field.
## Lifetime and force keep their own rules; mergers still conserve actual area.
static func scale_for_charge(value: float) -> float:
	return lerpf(0.9, 1.35, (clampf(value, 1.0, 5.0) - 1.0) / 4.0)

## Charge determines presentation and duration; it never raises pulling force.
func lifetime_for_charge() -> float:
	return lerpf(MIN_LIFETIME, MAX_LIFETIME, (clampf(charge, 1.0, 5.0) - 1.0) / 4.0)

## Only the active well takes over controls; its traveling rocket does not.
func holds_steering() -> bool:
	return phase == "active"

## Tapping cancels force completely for a short window and never adds thrust.
func resist() -> void:
	if holds_steering():
		neutralise_time = 0.25

## Fly to the chosen location, implode, pull actors, then restore only survivors.
func step(delta: float) -> void:
	animation_time += delta
	if phase == "warning":
		var previous := cannon_position
		cannon_position = cannon_position.move_toward(well_position, 1225.0 * delta)
		var collision: Dictionary = game.gravity_fields.intercept_cannon(previous, cannon_position, self)
		if not collision.is_empty():
			well_position = collision.at
			cannon_position = collision.at
		if cannon_position.distance_to(well_position) < 1.0:
			phase = "active"
			remaining = lifetime_for_charge()
			well_scale = scale_for_charge(charge)
			game.sound.play_effect("rift")
			game.combat.vibrate("black_spawn")
		queue_redraw()
		return
	active_age += delta
	neutralise_time = maxf(0.0, neutralise_time - delta)
	# Include new arrivals and collectibles, but never bosses. Shots are bent by
	# game.bend_projectile, preserving their individual constant travel speeds.
	var actors: Array = []
	actors.append_array(game.enemies)
	actors.append_array(game.pickups)
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var id: int = actor.get_instance_id()
		if not origins.has(id):
			origins[id] = game.combat.returns.get(id, actor.position)
			# A second field inherits the first field's pre-pull origin, not the
			# already displaced position observed later in this same frame.
			for other in game.gravity_fields.active_wells():
				if other != self and other.get_script() == get_script() and other.origins.has(id):
					origins[id] = other.origins[id]
					break
			game.combat.returns.erase(id)
		var before: Vector2 = actor.position
		if game.gravity_fields.owns_actor_motion(self):
			actor.position += game.gravity_fields.net_force_for(actor) * delta
		actor.previous_position = actor.position
		var nearest := Geometry2D.get_closest_point_to_segment(game.ship.position, before, actor.position)
		if game.enemies.has(actor) and nearest.distance_to(game.ship.position) <= game.Enemy.HIT_RADIUS + game.protected_contact_radius():
			game.handle_alien_collision(actor)
			if game.state != game.State.PLAYING:
				return
			continue
		if actor.position.distance_to(well_position) < game.gravity_fields.core_radius(self) * (29.0 / 31.0):
			if game.enemies.has(actor):
				game.destroy_enemy(actor, false)
			elif game.pickups.has(actor):
				game.pickups.erase(actor)
				actor.queue_free()
		if game.state != game.State.PLAYING:
			return
	if not game.gravity_fields.lifetime_frozen(self):
		remaining -= delta
	if remaining <= 0.0:
		finish_well()
	queue_redraw()

## Restore living ships and collectibles only. Asteroids retain bent trajectories.
func finish_well(release_force: Vector2 = Vector2.INF) -> void:
	if phase == "finished":
		return
	var departing_force: Vector2 = game.gravity_fields.net_force_for(game.ship) if release_force == Vector2.INF else release_force
	game.gravity_fields.add_exit(well_position, kind, well_scale)
	game.request_cruise_return(departing_force)
	for id in origins.keys():
		var actor = instance_from_id(id)
		if is_instance_valid(actor) and actor != game.ship and not actor.is_queued_for_deletion() and not game.asteroids.has(actor):
			game.combat.returns[id] = origins[id]
	phase = "finished"
	game.lingering_wells.erase(self)
	queue_free()

## The traveling cannon stays here; gravity_fields owns the textured active disk
## and its opaque horizon so the exact same artwork survives merging and death.
func _draw() -> void:
	if phase == "warning":
		for layer in range(6, 0, -1):
			draw_circle(cannon_position, 5.0 + layer * 2.8, Color("4ea5ff", 0.04 + 0.025 * (6 - layer)))
		draw_circle(cannon_position, 7, Color("d6f7ff"))
		return
