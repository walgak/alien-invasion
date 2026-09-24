extends RefCounted
## Weapon pickups advance one rung; the game owns health and pickup collection.

const Projectile = preload("res://scripts/projectile.gd")
const MAX_LEVEL := 4
const NAMES := ["SINGLE", "DOUBLE", "TRIPLE", "LASER", "PLASMA"]
var level := 0

## Translate the clamped upgrade level into the label shown in the HUD.
func weapon_name() -> String:
	return NAMES[clampi(level, 0, MAX_LEVEL)]

## Advance one weapon tier without exceeding the final enhanced-plasma tier.
func upgrade() -> void:
	level = clampi(level + 1, 0, MAX_LEVEL)
	if level == 3:
		level = 4 # Laser is a timed pickup, never a permanent rung.

## Emit the selected weapon pattern and return its cooldown in seconds. Laser ownership stays with game.update_laser.
func fire(game: Node2D) -> float:
	var ship := game.get("ship") as Node2D
	if not is_instance_valid(ship):
		return 0.17
	# Use the rendered hardpoints immediately, even before the next physics tick
	# copies the new weapon tier into the ship's visual state.
	var muzzle: Vector2 = ship.muzzle_position(level)
	var cooldown := 0.17
	var effect := "shot"
	match clampi(level, 0, MAX_LEVEL):
		0:
			spawn_shot(game, muzzle, Vector2(0.0, -850.0))
		1:
			spawn_shot(game, ship.muzzle_position(level, -1), Vector2(0.0, -850.0))
			spawn_shot(game, ship.muzzle_position(level, 1), Vector2(0.0, -850.0))
		2:
			spawn_shot(game, muzzle, Vector2(0.0, -850.0))
			spawn_shot(game, ship.muzzle_position(level, -1), Vector2(-110.0, -880.0).normalized() * 850.0)
			spawn_shot(game, ship.muzzle_position(level, 1), Vector2(110.0, -880.0).normalized() * 850.0)
		3:
			game.update_laser(0.0)
			return 0.17
		4:
			# Stronger plasma keeps the same three guns, cadence and 850 speed.
			for lane in [-1, 0, 1]:
				var direction := Vector2(float(lane) * 110.0, -880.0).normalized()
				var plasma = spawn_shot(game, ship.muzzle_position(level, lane), direction * 850.0)
				plasma.kind = "plasma"
				plasma.damage = 2
	var sound := game.get("sound") as Node
	if is_instance_valid(sound):
		sound.call("play_effect", effect)
	return cooldown

## Create a player projectile and register it with the game's collision/update list.
func spawn_shot(game: Node2D, at: Vector2, speed: Vector2) -> Node2D:
	var shot = Projectile.new()
	shot.position = at
	shot.previous_position = at
	shot.velocity = speed
	game.add_child(shot)
	var shots: Array = game.get("projectiles")
	shots.append(shot)
	return shot
