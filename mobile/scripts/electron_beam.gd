extends Node2D
## One stored charge draws a finite, visible chain through the current playfield.
## Target identities are rechecked on arrival: another weapon may kill them first.
var game: Node2D
var pending: Array[Dictionary] = []
var links: Array[Dictionary] = []
var next_hit := 0.0
var last_point := Vector2.ZERO
var age := 0.0

func _init() -> void:
	z_index = 24

func clear() -> void:
	pending.clear()
	links.clear()
	next_hit = 0.0
	queue_redraw()

## Select the nearest forward gun column first, then visit nearest neighbors.
## The boss is last so surviving guards have time to lose their shield gate.
func fire() -> bool:
	if not pending.is_empty():
		return false
	var candidates: Array[Dictionary] = []
	for actor in game.enemies + game.asteroids:
		var kind := "enemy" if game.enemies.has(actor) else "rock"
		if game.target_is_exposed(actor, kind):
			candidates.append({"id": actor.get_instance_id(), "kind": kind, "at": actor.position})
	var first: Array = candidates.filter(func(item: Dictionary) -> bool: return item.kind == "enemy")
	if first.is_empty(): first = candidates.duplicate()
	last_point = game.ship.muzzle_position(game.weapons.level, 0, true)
	if not first.is_empty():
		first.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ax: float = absf(a.at.x-last_point.x)
			var bx: float = absf(b.at.x-last_point.x)
			return ax < bx if not is_equal_approx(ax,bx) else a.at.distance_squared_to(last_point) < b.at.distance_squared_to(last_point))
		pending.append(first[0])
		candidates.erase(first[0])
		var point: Vector2 = first[0].at
		while not candidates.is_empty():
			candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.at.distance_squared_to(point) < b.at.distance_squared_to(point))
			var next: Dictionary = candidates.pop_front()
			pending.append(next)
			point = next.at
	if is_instance_valid(game.boss) and game.target_is_exposed(game.boss, "boss"):
		pending.append({"id": game.boss.get_instance_id(), "kind": "boss", "at": game.boss.body_position})
	if pending.is_empty():
		return false
	age = 0.0
	next_hit = 0.0
	game.sound.play_effect("rift")
	game.combat.vibrate("enemy")
	return true

## A chain costs one inventory item regardless of target count. Asteroid melting
## uses the existing destruction path with fragmentation explicitly disabled.
func step(delta: float) -> void:
	age += delta
	for link in links.duplicate():
		link.life -= delta
		if link.life <= 0.0: links.erase(link)
	next_hit -= delta
	if not pending.is_empty() and next_hit <= 0.0:
		next_hit = 0.055
		var entry: Dictionary = pending.pop_front()
		var actor = instance_from_id(entry.id)
		if is_instance_valid(actor) and not actor.is_queued_for_deletion() and game.target_is_exposed(actor,entry.kind):
			var target: Vector2 = actor.body_position if entry.kind == "boss" else actor.position
			var route: Array[Vector2] = game.route_energy_link(last_point,target)
			links.append({"route": route, "life": 0.42})
			if route.is_empty() or route.back().distance_to(target) > 1.0:
				queue_redraw()
				return
			last_point = target
			if entry.kind == "rock": game.hit_asteroid(actor, actor.health, false)
			elif entry.kind == "enemy": game.damage_target(actor,"enemy",actor.health)
			elif actor == game.boss: game.damage_target(actor,"boss",3)
	queue_redraw()

## Filled plasma ribbons have a white electric core and soft colored volume.
## Fixed subdivisions bound work even with a full screen of targets.
func _draw() -> void:
	for link in links:
		var opacity: float = clampf(link.life/0.2,0,1)
		var route: Array = link.route
		for i in range(0,route.size()-1,2):
			var from: Vector2 = route[i]
			var to: Vector2 = route[i+1]
			var direction := to-from
			var side := direction.normalized().orthogonal()
			for layer in range(3):
				var width: float = [8.0,3.0,0.95][layer]
				var tint: Color = [Color(0.27,0.45,1.0,0.12*opacity),Color(0.45,0.85,1.0,0.55*opacity),Color(0.93,1,1,opacity)][layer]
				var upper := PackedVector2Array()
				var lower := PackedVector2Array()
				for j in range(9):
					var t := float(j)/8.0
					var ripple := sin(t*30.0+age*75.0+i)*sin(t*PI)*minf(7.0,direction.length()*0.04)
					var point := from+direction*t+side*ripple
					upper.append(point+side*width)
					lower.append(point-side*width)
				lower.reverse()
				upper.append_array(lower)
				draw_colored_polygon(upper,tint)
