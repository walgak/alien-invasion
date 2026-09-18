extends RefCounted
## Reference-matched alien art. Normal aliens, summoned ships and boss guards
## use this same hull, preserving their existing collision and movement rules.
const ALIEN_TEXTURE = preload("res://assets/ships/alien-fighter.png")
const PlayerArtwork = preload("res://scripts/ship_artwork.gd")
const PLAYER_SIZE_RATIO := 1.2

## Divide, rather than subtract 20%: the player's base hull is 1.2x the alien.
## Upgraded player hulls may still expand according to their existing tiers.
static func size_for() -> Vector2:
	return PlayerArtwork.size_for(0) / PLAYER_SIZE_RATIO

static func rect_for() -> Rect2:
	var size := size_for()
	return Rect2(-size * 0.5, size)

## Pixel-measured UV landmarks on the source sprite (nose points down).
static func point_at(uv: Vector2) -> Vector2:
	return (uv-Vector2.ONE*0.5)*size_for()

static func muzzle_local(side: int) -> Vector2:
	return point_at(Vector2(0.5+float(side)*0.168, 0.765))

static func rear_muzzle_local() -> Vector2:
	return point_at(Vector2(0.5, 0.018))

## EngineBurn faces up through a PI rotation. Negate the source-space points
## here so the parent rotation places each plume on its actual violet nozzle.
static func nozzles() -> PackedVector2Array:
	return PackedVector2Array([-point_at(Vector2(0.393,0.291)), -point_at(Vector2(0.607,0.291))])
