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
var origins: Dictionary = {}
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
			remaining = charge
			well_scale = 1.8 * sqrt(charge)
			game.sound.play_effect("rift")
			game.combat.vibrate("gravity")
		queue_redraw()
		return
	var blocked := neutralise_time > 0.0
	neutralise_time = maxf(0.0, neutralise_time - delta)
	# Include new arrivals and collectibles, but never bosses. Shots are bent by
	# game.bend_projectile, preserving their individual constant travel speeds.
	var actors: Array = [game.ship]
	actors.append_array(game.enemies)
	actors.append_array(game.asteroids)
	actors.append_array(game.pickups)
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		if not origins.has(actor):
			origins[actor] = game.combat.returns.get(actor, actor.position)
			game.combat.returns.erase(actor)
		if actor == game.ship and (blocked or game.combat.shield_time > 0.0):
			continue
		var before: Vector2 = actor.position
		actor.position = actor.position.move_toward(well_position, PULL_SPEED * minf(delta, remaining))
		if actor == game.ship:
			actor.target_x = actor.position.x
		else:
			actor.previous_position = actor.position
		var nearest := Geometry2D.get_closest_point_to_segment(game.ship.position, before, actor.position)
		if game.asteroids.has(actor) and nearest.distance_to(game.ship.position) <= actor.radius + game.Ship.HIT_RADIUS:
			game.remove_asteroid(actor)
			game.instant_loss("An asteroid struck your ship.")
			if game.state != game.State.PLAYING:
				return
			continue
		if game.enemies.has(actor) and nearest.distance_to(game.ship.position) <= game.Enemy.HIT_RADIUS + game.Ship.HIT_RADIUS:
			game.remove_enemy(actor)
			game.damage_ship()
			if game.state != game.State.PLAYING:
				return
			continue
		if actor.position.distance_to(well_position) < 29.0 * well_scale:
			if actor == game.ship:
				game.lose_ship("Caught in your own black hole.")
			elif game.enemies.has(actor):
				game.destroy_enemy(actor)
			elif game.asteroids.has(actor):
				game.hit_asteroid(actor, actor.health)
			elif game.pickups.has(actor):
				game.pickups.erase(actor)
				actor.queue_free()
		if game.state != game.State.PLAYING:
			return
	remaining -= delta
	if remaining <= 0.0:
		for actor in origins:
			if is_instance_valid(actor) and not actor.is_queued_for_deletion():
				game.combat.returns[actor] = origins[actor]
		phase = "finished"
		game.lingering_wells.erase(self)
		queue_free()
	queue_redraw()

## Inward-moving concentric folds accompany the shader's actual background lens.
func _draw() -> void:
	if phase == "warning":
		draw_circle(cannon_position, 10, Color("c7a0ff"))
		draw_arc(cannon_position, 20, 0, TAU, 32, Color("806ad9"), 3, true)
		return
	for i in range(5):
		var progress := fposmod(float(i) / 5.0 - animation_time * 0.45, 1.0)
		draw_arc(well_position, (32 + 85 * progress) * well_scale, 0, TAU, 80, Color(0.55, 0.4, 1.0, (1 - progress) * 0.45), 2, true)
	draw_circle(well_position, 31 * well_scale, Color("03020c"))
	draw_arc(well_position, 32 * well_scale, 0, TAU, 80, Color("b894ff"), 3, true)
