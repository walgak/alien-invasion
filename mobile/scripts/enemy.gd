extends Node2D

const HIT_RADIUS := 24.0
const Artwork = preload("res://scripts/alien_artwork.gd")
const EngineBurn = preload("res://scripts/engine_burn.gd")
var engine_burn: Node2D
var formation_offset := Vector2.ZERO
var phase := 0.0
var tint := Color("ffb86a")
const RELEASE_FADE_SECONDS := 0.24
var velocity := Vector2(0, 125)
var previous_position := Vector2.ZERO
var age := 0.0
var shot_timer := 2.0
var summoned := false
var health := 3
var drop_group: Dictionary = {}
var shield_guard := false
var guard_angle := 0.0
var zigzag := false
var motion_phase := "flight"
var fold_origin := Vector2.ZERO
var fold_life := 0.0
var pull_start := Vector2.ZERO
var pull_offset := Vector2.ZERO
var phase_time := 0.0
var launch_speed := 220.0
var next_gun_side := -1

## Alien noses point down in normal flight. The twin violet engines therefore
## exhaust upward; rotating the entire ship keeps their force direction honest.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	engine_burn = EngineBurn.new()
	add_child(engine_burn)
	engine_burn.rotation = PI
	engine_burn.configure(Artwork.nozzles(), Color("b34cff"), 3.8)

## Alternate the two modeled cannons without adding bullets or changing timing.
func muzzle_position() -> Vector2:
	var at := to_global(Artwork.muzzle_local(next_gun_side))
	next_gun_side = -next_gun_side
	return at

## The aft spine houses the gravity cannon fired when an alien escapes below.
func rear_muzzle_position() -> Vector2:
	return to_global(Artwork.rear_muzzle_local())

## Capture the offscreen starting point and boss anchor, then enter the pull/windup/throw state machine.
func begin_pull(origin: Vector2) -> void:
	fold_origin = origin
	pull_start = position
	pull_offset = (position - origin).normalized() * 105.0
	launch_speed = velocity.length()
	velocity = Vector2.ZERO
	motion_phase = "pull"
	fold_life = RELEASE_FADE_SECONDS

## Advance this actor by delta seconds and retain its previous position for swept collision checks.
func advance(delta: float, target: Vector2 = Vector2.ZERO) -> void:
	previous_position = position
	var old_age := age
	age += delta
	var remaining := delta
	if motion_phase == "pull":
		var step := minf(remaining, 0.7 - phase_time)
		phase_time += step
		remaining -= step
		position = pull_start.lerp(fold_origin + pull_offset, smoothstep(0.0, 0.7, phase_time))
		if phase_time >= 0.7:
			motion_phase = "windup"
			phase_time = 0.0
	if motion_phase == "windup":
		var step := minf(remaining, 0.22 - phase_time)
		phase_time += step
		remaining -= step
		var direction := 1.0 if pull_offset.x < 0.0 else -1.0
		position = fold_origin + pull_offset.rotated(direction * smoothstep(0.0, 0.22, phase_time) * 0.65)
		if phase_time >= 0.22:
			motion_phase = "flight"
			velocity = (target - position).normalized() * launch_speed
	if motion_phase == "flight":
		position += velocity * remaining
		if not summoned:
			if zigzag:
				# Triangle wave gives clear alternating diagonal legs.
				position.x += (asin(sin(age * 2.8 + phase)) - asin(sin(old_age * 2.8 + phase))) * 60.0
			else:
				position.x += (sin(age * 1.8 + phase) - sin(old_age * 1.8 + phase)) * 22.0
		fold_life = maxf(0.0, fold_life - remaining)
	queue_redraw()

## Keep boss-connected tractor folds underneath the reference-matched 2D hull.
## Reflections and armor depth are baked into the mipmapped transparent texture.
func _draw() -> void:
	# The shared refraction shader supplies the tractor wake without line strokes.
	draw_texture_rect(Artwork.ALIEN_TEXTURE, Artwork.rect_for(), false)
