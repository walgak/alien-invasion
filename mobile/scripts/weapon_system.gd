extends RefCounted
## Weapon pickups advance one rung; the game owns health and pickup collection.

const Projectile = preload("res://scripts/projectile.gd")
const MAX_LEVEL := 4
const NAMES := ["SINGLE", "DOUBLE", "TRIPLE", "LASER", "ROCKETS"]
var level := 0

func weapon_name() -> String:
	return NAMES[clampi(level, 0, MAX_LEVEL)]

func upgrade() -> void:
	level = clampi(level + 1, 0, MAX_LEVEL)

func fire(game: Node2D) -> float:
	var ship := game.get("ship") as Node2D
	if not is_instance_valid(ship):
		return 0.17
	var muzzle := ship.position + Vector2(0.0, -36.0)
	var cooldown := 0.17
	var effect := "shot"
	match clampi(level, 0, MAX_LEVEL):
		0:
			spawn_shot(game, muzzle, Vector2(0.0, -850.0))
		1:
			spawn_shot(game, muzzle + Vector2(-11.0, 7.0), Vector2(0.0, -850.0))
			spawn_shot(game, muzzle + Vector2(11.0, 7.0), Vector2(0.0, -850.0))
		2:
			spawn_shot(game, muzzle, Vector2(0.0, -900.0))
			spawn_shot(game, muzzle + Vector2(-17.0, 9.0), Vector2(-110.0, -880.0))
			spawn_shot(game, muzzle + Vector2(17.0, 9.0), Vector2(110.0, -880.0))
			cooldown = 0.16
		3:
			var beam = spawn_shot(game, muzzle, Vector2.ZERO)
			beam.setup_laser(muzzle, Vector2(muzzle.x, -24.0))
			cooldown = 0.22
			effect = "laser"
		4:
			for offset in [-13.0, 13.0]:
				var rocket = spawn_shot(game, muzzle + Vector2(offset, 7.0), Vector2(0.0, -660.0))
				rocket.kind = "rocket"
				rocket.damage = 3
				rocket.blast_radius = 65.0
			cooldown = 0.38
			effect = "rocket"
	var sound := game.get("sound") as Node
	if is_instance_valid(sound):
		sound.call("play_effect", effect)
	return cooldown

func spawn_shot(game: Node2D, at: Vector2, speed: Vector2) -> Node2D:
	var shot = Projectile.new()
	shot.position = at
	shot.previous_position = at
	shot.velocity = speed
	game.add_child(shot)
	var shots: Array = game.get("projectiles")
	shots.append(shot)
	return shot
