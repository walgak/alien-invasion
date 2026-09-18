extends Node2D

const HIT_RADIUS := 24.0
const HullFinish = preload("res://scripts/hull_finish.gd")
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

## Alien noses point down in normal flight. The twin violet engines therefore
## exhaust upward; rotating the entire ship keeps their force direction honest.
func _ready() -> void:
	engine_burn = EngineBurn.new()
	add_child(engine_burn)
	engine_burn.rotation = PI
	engine_burn.configure(PackedVector2Array([Vector2(-8,17), Vector2(8,17)]), Color("b34cff"), 3.8)

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

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	if fold_life > 0.0:
		var anchor := to_local(fold_origin)
		var side := anchor.orthogonal().normalized()
		for lane in range(5):
			var points := PackedVector2Array()
			for i in range(25):
				var t := float(i) / 24.0
				points.append(anchor.lerp(Vector2((lane - 2) * 6, 0), t) + side * sin(t * TAU * 2 + age * 5 + lane) * 3.0 * sin(t * PI))
			draw_polyline(points, Color("91f5da", fold_life / RELEASE_FADE_SECONDS * 0.32), 1.2, true)
	var energy := Color("d18cff")
	draw_circle(Vector2.ZERO, 32, Color(energy, 0.055))
	for x in [-8.0, 8.0]:
		draw_circle(Vector2(x,-17), 4.1, Color("351852"))
		draw_circle(Vector2(x,-18), 2.5, Color("d8a3ff"))
	# Scythe wings frame a narrow spear hull, matching the supplied concept at
	# gameplay scale without depending on a texture asset.
	for side in [-1.0, 1.0]:
		var blade := PackedVector2Array([Vector2(side*8,-12),Vector2(side*22,-19),Vector2(side*31,-25),Vector2(side*24,-7),Vector2(side*29,11),Vector2(side*20,19),Vector2(side*15,5),Vector2(side*7,8)])
		HullFinish.plate(self, blade, Color("66627c"), energy, age)
		HullFinish.plate(self, PackedVector2Array([Vector2(side*12,-9),Vector2(side*23,-17),Vector2(side*19,-4),Vector2(side*23,10),Vector2(side*17,13),Vector2(side*12,1)]), Color("9a86ac"), energy, age + side * 0.3)
		draw_line(Vector2(side*14,-8),Vector2(side*21,10),energy,2.0,true)
	var hull := PackedVector2Array([Vector2(0,-24),Vector2(11,-8),Vector2(10,10),Vector2(0,23),Vector2(-10,10),Vector2(-11,-8)])
	HullFinish.plate(self, hull, Color("77758c"), energy, age)
	HullFinish.plate(self, PackedVector2Array([Vector2(0,-22),Vector2(0,18),Vector2(-6,9),Vector2(-7,-6)]), Color("ba9bc8"), energy, age)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(5,-3),Vector2(3,10),Vector2(0,16),Vector2(-3,10),Vector2(-5,-3)]),Color("120c1d"))
	draw_line(Vector2(0,-13),Vector2(0,12),Color("d692ff"),3.0,true)
	draw_circle(Vector2(0,15),3,Color("f1d8ff"))

	# Rear-facing gravity cannon: the ship flies down, leaving this violet barrel
	# aimed back toward the player once it has crossed the bottom boundary.
	HullFinish.plate(self, PackedVector2Array([Vector2(-6,-34),Vector2(6,-34),Vector2(5,-18),Vector2(-5,-18)]), Color("7c6e91"), energy, age)
	draw_circle(Vector2(0,-32),5,Color("08070c"))
	draw_arc(Vector2(0,-32),6,0,TAU,18,Color("c875ff"),2,true)
	draw_line(Vector2(0,-30),Vector2(0,-19),Color("e0a7ff"),2.5,true)
