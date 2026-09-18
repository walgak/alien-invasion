extends RefCounted
## Artwork, emitters and fractured hull share one coordinate system. Reskinning
## the fighter must never silently change steering or collision bounds.
const FIGHTER_TEXTURE = preload("res://assets/ships/player-fighter.png")
const Surface = preload("res://shaders/fighter_hull.gdshader")
const WIDTHS := [1.0, 1.13, 1.28, 1.45, 1.38]
const HEIGHTS := [1.0, 1.035, 1.07, 1.10, 1.085]

## Upgrades expand the actual hull; the central cockpit stays recognizable.
static func size_for(level: int) -> Vector2:
	var tier := clampi(level, 0, 4)
	return Vector2(88.0 * WIDTHS[tier], 88.0 * HEIGHTS[tier])

static func rect_for(level: int) -> Rect2:
	var size := size_for(level)
	return Rect2(-size * 0.5, size)

## Normalized points measured on the artwork: nose and two wing cannons.
## Explicit tiers avoid a one-frame mismatch immediately after an upgrade.
static func muzzle_local(level: int, lane: int = 0, special: bool = false) -> Vector2:
	var uv := Vector2(0.5, 0.018)
	if lane != 0 and not special:
		uv = Vector2(0.5 + signf(float(lane)) * 0.221, 0.338)
	return (uv - Vector2.ONE * 0.5) * size_for(level)

## Both plumes attach to the blue mouths of the twin engine cylinders.
static func nozzles(level: int) -> PackedVector2Array:
	var size := size_for(level)
	return PackedVector2Array([Vector2(-0.14, 0.403) * size, Vector2(0.14, 0.403) * size])

## Death freezes the same shader state as the intact hull, including retracted
## cannons, so the fragments retain the ship's actual armor and cockpit detail.
static func surface_for(level: int, clock: float = 0.0) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = Surface
	update_surface(surface, level, clock, false)
	return surface

static func update_surface(surface: ShaderMaterial, level: int, clock: float, immune: bool) -> void:
	surface.set_shader_parameter("side_ports", level in [1, 2, 4])
	surface.set_shader_parameter("laser_port", level == 3)
	surface.set_shader_parameter("visual_time", clock)
	surface.set_shader_parameter("recovering", immune)
