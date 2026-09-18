extends Node2D
## A player-launched gravity rocket, then a finite well. Boss-compatible fields
## let the existing background refraction pass render the same spatial folding.

var game: Node2D
var kind := "black"
var phase := "warning"
var well_position := Vector2.ZERO
var cannon_position := Vector2.ZERO
var charge := 1.0
var well_scale := 1.8
var animation_time := 0.0
var remaining := 0.0
var neutralise_time := 0.0
var origins: Dictionary[int, Vector2] = {}
## Stable instance IDs survive deletion; never use freed Nodes as dictionary keys.
var active_age := 0.0
var hole_color := Color("358cff")
const PULL_SPEED := 90.0

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
		cannon_position = cannon_position.move_toward(well_position, 1225.0 * delta)
		if cannon_position.distance_to(well_position) < 1.0:
			phase = "active"
			remaining = charge * 1.5
			well_scale = 1.8 * sqrt(charge)
			game.sound.play_effect("rift")
			game.combat.vibrate("black_spawn")
		queue_redraw()
		return
	active_age += delta
	var blocked := neutralise_time > 0.0
	neutralise_time = maxf(0.0, neutralise_time - delta)
	# Include new arrivals and collectibles, but never bosses. Shots are bent by
	# game.bend_projectile, preserving their individual constant travel speeds.
	var actors: Array = [game.ship]
	actors.append_array(game.enemies)
	actors.append_array(game.pickups)
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var id: int = actor.get_instance_id()
		if not origins.has(id):
			origins[id] = game.combat.returns.get(id, actor.position)
			game.combat.returns.erase(id)
		if actor == game.ship and (blocked or game.combat.shield_time > 0.0):
			continue
		var before: Vector2 = actor.position
		actor.position = actor.position.move_toward(well_position, PULL_SPEED * (0.86 + 0.14 * clampf(active_age / 2.0, 0.0, 1.0)) * minf(delta, remaining))
		if actor == game.ship:
			actor.target_x = actor.position.x
		else:
			actor.previous_position = actor.position
		var nearest := Geometry2D.get_closest_point_to_segment(game.ship.position, before, actor.position)
		if game.enemies.has(actor) and nearest.distance_to(game.ship.position) <= game.Enemy.HIT_RADIUS + game.Ship.HIT_RADIUS:
			game.remove_enemy(actor)
			game.damage_ship("An alien collided with your ship.")
			if game.state != game.State.PLAYING:
				return
			continue
		if actor.position.distance_to(well_position) < 29.0 * well_scale:
			if actor == game.ship:
				game.lose_ship("Caught in your own black hole.")
			elif game.enemies.has(actor):
				game.destroy_enemy(actor)
			elif game.asteroids.has(actor):
				game.hit_asteroid(actor, actor.health, false)
			elif game.pickups.has(actor):
				game.pickups.erase(actor)
				actor.queue_free()
		if game.state != game.State.PLAYING:
			return
	remaining -= delta
	if remaining <= 0.0:
		finish_well()
	queue_redraw()

## Restore living ships and collectibles only. Asteroids retain bent trajectories.
func finish_well() -> void:
	if phase == "finished":
		return
	game.gravity_fields.add_exit(well_position, kind, well_scale)
	for id in origins.keys():
		var actor = instance_from_id(id)
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and not game.asteroids.has(actor):
			game.combat.returns[id] = origins[id]
	phase = "finished"
	game.lingering_wells.erase(self)
	queue_free()

## The traveling cannon stays here; gravity_fields owns the textured active disk
## and its opaque horizon so the exact same artwork survives merging and death.
func _draw() -> void:
	if phase == "warning":
		draw_circle(cannon_position, 10, Color("d6f7ff"))
		draw_arc(cannon_position, 20, 0, TAU, 32, Color("4ea5ff"), 3, true)
		return
