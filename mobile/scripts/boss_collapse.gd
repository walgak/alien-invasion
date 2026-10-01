extends Node2D
## The player's supplied eight-frame destruction sheets replace the defeated
## hull. They remain 2D sprites; crossfades make the hand-drawn phases continuous.
## The actual gravity field still begins at 0.65s and lasts eight seconds.
const DeathShader = preload("res://shaders/boss_destruction.gdshader")
const SHEETS := {
	"black": preload("res://assets/bosses/destruction/black-collapse.png"),
	"white": preload("res://assets/bosses/destruction/white-burst.png"),
	"asteroid": preload("res://assets/bosses/destruction/asteroid-shatter.png")
}
# The supplied frames vary slightly in spacing. Explicit pixel bounds keep a
# neighbor's wing out of the frame, and reactor pivots keep the effect anchored.
const BOUNDARIES := {
	"black": [0, 317, 604, 872, 1145, 1426, 1698, 1929, 2172],
	"white": [0, 279, 515, 795, 1056, 1381, 1630, 1891, 2172],
	"asteroid": [0, 289, 551, 809, 1085, 1374, 1646, 1908, 2172]
}
const PIVOTS := {
	"black": [Vector2(167,350), Vector2(464,350), Vector2(740,354), Vector2(1015,355), Vector2(1302,365), Vector2(1570,370), Vector2(1822,373), Vector2(2050,380)],
	"white": [Vector2(143,355), Vector2(397,355), Vector2(658,357), Vector2(927,360), Vector2(1207,360), Vector2(1492,364), Vector2(1757,364), Vector2(2027,366)],
	"asteroid": [Vector2(155,354), Vector2(420,356), Vector2(681,358), Vector2(945,357), Vector2(1225,358), Vector2(1509,363), Vector2(1765,367), Vector2(2028,360)]
}
# The strips were packed into narrow cells. Restoring each intact hull to the
# 272px gameplay footprint prevents an abrupt skinny-shape change on death.
const PIXELS_PER_UNIT := {
	"black": Vector2(1.0 / 0.84, 1.0 / 0.65),
	"white": Vector2(1.0 / 0.98, 1.0 / 0.70),
	"asteroid": Vector2(1.0 / 0.94, 1.0 / 0.765)
}
const OPEN_TIME := 0.65
const DURATION := 1.45
const QUAD_SIZE := 360.0
var game: Node2D
var kind := "black"
var tint := Color("a45cff")
var size := 1.8
var age := 0.0
var opened := false
var hull: Node2D
var sheet: Sprite2D
var finish: ShaderMaterial
var frame_position := 0.0

func configure(source: Node2D) -> void:
	position = source.body_position
	kind = source.kind
	tint = source.hole_color
	size = source.well_scale * 1.8
	z_as_relative = false
	z_index = 28
	# The first tenth of a second preserves the exact scarred source hull,
	# dissolving into the matching authored sprite rather than switching it.
	hull = game.Boss.new()
	hull.game = game
	hull.kind = kind
	hull.hole_color = tint
	hull.animation_time = source.animation_time
	hull.max_health = source.max_health
	hull.health = 0.0
	hull.collapse_snapshot = true
	add_child(hull)
	hull.queue_redraw()
	sheet = Sprite2D.new()
	sheet.texture = SHEETS[kind]
	sheet.scale = Vector2.ONE * QUAD_SIZE / Vector2(sheet.texture.get_size())
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	finish = ShaderMaterial.new()
	finish.shader = DeathShader
	finish.set_shader_parameter("sheet_texture", SHEETS[kind])
	finish.set_shader_parameter("pixels_per_unit", PIXELS_PER_UNIT[kind])
	sheet.material = finish
	add_child(sheet)
	refresh_sheet()

## Simulation time, not wall time: a pause freezes every piece and frame blend.
func step(delta: float) -> void:
	age += delta
	refresh_sheet()
	if age >= OPEN_TIME and not opened:
		opened = true
		hull.visible = false
		if kind in ["black", "white"]:
			open_death_well()
	if age >= DURATION:
		game.gravity_fields.collapses.erase(self)
		queue_free()

## Only the gravity bosses produce a new field. Their previous cannon or active
## attack lives in a separate detached node and is never touched by this effect.
func open_death_well() -> void:
	var well = game.Boss.new()
	well.game = game
	well.kind = kind
	well.hole_color = tint
	well.lingering = true
	well.phase = "active"
	well.body_position = position
	well.well_position = position
	well.well_scale = size
	well.well_duration = game.Boss.ACTIVE_SECONDS * 2.0
	game.add_child(well)
	game.lingering_wells.append(well)
	game.combat.vibrate(kind + "_spawn")
	game.sound.play_effect("rift")

## Black folds reach their tiny singularity as the field opens; white/asteroid
## frames are at the first major explosion then, leaving a visible debris tail.
func refresh_sheet() -> void:
	var changeover := smoothstep(0.0, 0.15, age)
	hull.modulate.a = 1.0 - changeover
	var at_open := 5.6 if kind == "black" else 4.0
	if age <= OPEN_TIME:
		frame_position = clampf(age / OPEN_TIME, 0.0, 1.0) * at_open
	else:
		frame_position = lerpf(at_open, 7.0, clampf((age - OPEN_TIME) / 0.54, 0.0, 1.0))
	var first := clampi(int(floor(frame_position)), 0, 7)
	var second := mini(first + 1, 7)
	set_frame("a", first)
	set_frame("b", second)
	finish.set_shader_parameter("frame_mix", smoothstep(0.0, 1.0, frame_position - first))
	finish.set_shader_parameter("opacity", changeover * (1.0 - smoothstep(1.05, DURATION, age)))
	finish.set_shader_parameter("inward_fold", sin(clampf(age / OPEN_TIME, 0.0, 1.0) * PI) if kind == "black" else 0.0)
	finish.set_shader_parameter("black_core", 27.0 * (1.0 - smoothstep(0.25, OPEN_TIME, age)) if kind == "black" else 0.0)

func set_frame(suffix: String, frame: int) -> void:
	var edges: Array = BOUNDARIES[kind]
	finish.set_shader_parameter("frame_" + suffix, Vector4(edges[frame] + 0.5, 110.0, edges[frame + 1] - 0.5, 610.0))
	finish.set_shader_parameter("pivot_" + suffix, PIVOTS[kind][frame])
