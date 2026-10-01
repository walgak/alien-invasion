extends Node2D

const PULL_SECONDS := 0.7
const WINDUP_SECONDS := 0.22
const RELEASE_FADE_SECONDS := 0.24
const ORE_ATLAS = preload("res://assets/asteroids/ore-atlas.png")
const ORE_SHADER = preload("res://shaders/asteroid_ore.gdshader")
const ORE_KINDS := ["ice", "ash", "magma", "fractured", "cinder"]
var artwork: Sprite2D
var ore_material: ShaderMaterial
var atlas_index := 0
var visual_time := 0.0

var radius := 24.0
var health := 2
var velocity := Vector2(0, 240)
var previous_position := Vector2.ZERO
var spin := 1.0
var flash := 0.0
var max_health := 2
var fold_origin := Vector2.ZERO
var fold_life := 0.0
var motion_phase := "flight"
var phase_time := 0.0
var pull_start := Vector2.ZERO
var pull_offset := Vector2.ZERO
var aim_offset := Vector2.ZERO
var launch_speed := 260.0
var swing_direction := 1.0
## Fragments inherit this material; empty chooses a seeded ore independently of size.
var visual_kind := ""
var visual_seed := 1
## Set only when the player actually changes this rock's momentum. Ambient and
## boss-thrown asteroids cannot damage their own fleet without that intervention.
var player_deflected := false
## Shared by every descendant of one large rock. It counts living fragments and
## remembers any non-primary damage or escaped piece until the family ends.
var reward_family: Dictionary = {}

## Use one shared detailed atlas for every rock. Each instance adds one cheap
## sprite and uniforms; it does not rebuild plates or crater geometry per frame.
## Fragments inherit the material while size and collision stay physics-owned.
func _ready() -> void:
	if visual_kind.is_empty():
		visual_kind = ORE_KINDS[posmod(visual_seed, ORE_KINDS.size())]
	atlas_index = {"ice":0, "ash":1, "magma":2, "fractured":3, "cinder":4}.get(visual_kind, 2)
	if visual_kind == "ash" and visual_seed % 2 == 0:
		atlas_index = 5
	max_health = max(health, 1)
	ore_material = ShaderMaterial.new()
	ore_material.shader = ORE_SHADER
	artwork = Sprite2D.new()
	artwork.texture = ORE_ATLAS
	artwork.region_enabled = true
	var origin := Vector2((atlas_index % 3) * 512, (atlas_index / 3) * 512)
	artwork.region_rect = Rect2(origin, Vector2(512,512))
	# Each generated silhouette spans roughly 480 pixels inside its tile.
	# Fitting that span to the collision diameter avoids oversized hitboxes.
	artwork.scale = Vector2.ONE * (radius / 240.0)
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	artwork.material = ore_material
	ore_material.set_shader_parameter("tile_origin", origin / Vector2(1536,1024))
	ore_material.set_shader_parameter("icy", visual_kind == "ice")
	add_child(artwork)
	update_artwork()

## Baked mineral depth is complemented by subtle live highlights and heat.
## These are presentation-only: health, spin, fragments and rewards are unchanged.
func update_artwork() -> void:
	if ore_material == null: return
	ore_material.set_shader_parameter("visual_time", visual_time)
	ore_material.set_shader_parameter("tumble", rotation)
	ore_material.set_shader_parameter("hit_flash", clampf(flash * 5.0,0.0,1.0))
	ore_material.set_shader_parameter("damage", 1.0 - clampf(float(health)/float(max_health),0.0,1.0))

## Capture the offscreen starting point and boss anchor, then enter the pull/windup/throw state machine.
func begin_pull(origin: Vector2, target_offset: Vector2) -> void:
	fold_origin = origin
	pull_start = position
	pull_offset = (position - origin).normalized() * (85.0 + radius)
	swing_direction = 1.0 if pull_offset.x < 0.0 else -1.0
	aim_offset = target_offset
	launch_speed = velocity.length()
	velocity = Vector2.ZERO
	motion_phase = "pull"
	phase_time = 0.0
	fold_life = RELEASE_FADE_SECONDS

## Advance this actor by delta seconds and retain its previous position for swept collision checks.
func advance(delta: float, target: Vector2 = Vector2.ZERO) -> void:
	previous_position = position
	var remaining := delta
	if motion_phase == "pull":
		var step := minf(remaining, PULL_SECONDS - phase_time)
		phase_time += step
		remaining -= step
		position = pull_start.lerp(fold_origin + pull_offset, smoothstep(0.0, PULL_SECONDS, phase_time))
		if phase_time >= PULL_SECONDS:
			motion_phase = "windup"
			phase_time = 0.0
	if motion_phase == "windup":
		var step := minf(remaining, WINDUP_SECONDS - phase_time)
		phase_time += step
		remaining -= step
		var swing := swing_direction * smoothstep(0.0, WINDUP_SECONDS, phase_time) * 0.65
		position = fold_origin + pull_offset.rotated(swing)
		if phase_time >= WINDUP_SECONDS:
			motion_phase = "flight"
			velocity = (target + aim_offset - position).normalized() * launch_speed
	if motion_phase == "flight":
		position += velocity * remaining
		fold_life = maxf(0.0, fold_life - remaining)
	rotation += spin * delta
	flash = maxf(0, flash - delta)
	visual_time += delta
	update_artwork()
