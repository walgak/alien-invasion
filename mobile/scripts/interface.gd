extends Control
## Menus use native GUI controls; flight buttons are circular glass surfaces
## routed explicitly so no control can steal an established steering gesture.
const GlassButton = preload("res://scripts/glass_button.gd")

const INK := Color("e8f0f5")
const MUTED := Color("94a7bc")
const MINT := Color("64edcf")
const BOSS_NAMES := {"black": "BLACK HOLE", "white": "WHITE HOLE", "asteroid": "ASTEROID FORGE", "swarm": "SWARM CARRIER"}
var game: Node2D
var primary: Button
var secondary: Button
var pause_button: Button
var sound_button: Button
var vibration_button: Button
var shake_button: Button
var laser_button: Button
var distortion_button: Button
var font: Font
var gravity_button: Button
var laser_use_button: Button
var cannon_button: Button
var electron_button: Button
const SPECIAL_ACTIONS := ["gravity", "laser", "cannon", "electron"]
var special_touches: Dictionary = {}
var special_touch_msec := -1000

## Godot calls this once after the node joins the scene; initialize child nodes and cached resources here.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	primary = make_button(true)
	primary.pressed.connect(func():
		if game.state == game.State.PAUSED:
			game.resume_run()
		else:
			game.start_run())
	secondary = make_button(false)
	secondary.pressed.connect(func():
		game.progress.save()
		game.show_title())
	pause_button = make_special_button("pause")
	pause_button.tooltip_text = "Pause · P / Esc"
	sound_button = make_button(false)
	sound_button.add_theme_font_size_override("font_size", 13)
	sound_button.pressed.connect(game.toggle_sound)
	vibration_button = make_button(false)
	vibration_button.add_theme_font_size_override("font_size", 13)
	vibration_button.pressed.connect(game.toggle_vibration)
	shake_button = make_button(false)
	shake_button.add_theme_font_size_override("font_size", 11)
	shake_button.pressed.connect(game.toggle_screen_shake)
	laser_button = make_button(false)
	laser_button.add_theme_font_size_override("font_size", 11)
	laser_button.pressed.connect(game.toggle_laser_brightness)
	distortion_button = make_button(false)
	distortion_button.add_theme_font_size_override("font_size", 11)
	distortion_button.pressed.connect(game.toggle_distortion)
	gravity_button = make_special_button("gravity")
	laser_use_button = make_special_button("laser")
	cannon_button = make_special_button("cannon")
	electron_button = make_special_button("electron")

## Raw pointer routing is shared by desktop and phone. These Button subclasses
## have no native GUI interaction, which is what prevents movement stutter.
func make_special_button(action: String) -> Button:
	var button := GlassButton.new()
	button.action = action
	add_child(button)
	return button

func activate_special(action: String) -> void:
	if game.state != game.State.PLAYING or game.death_time > 0.0:
		return
	if action == "pause":
		game.pause_run()
		return
	if game.combat.gravity_blocks_control():
		# Unavailable weapon buttons still count as resistance taps.
		game.combat.press(-99, game.ship.position)
		return
	var accepted := false
	match action:
		"gravity": accepted = game.combat.arm_gravity()
		"laser": accepted = game.combat.activate_laser()
		"cannon": accepted = game.combat.fire_cannon_volley() > 0
		"electron": accepted = game.combat.activate_electron()
	if accepted:
		game.combat.weapon_button_feedback(action)
	refresh_special_buttons()

func special_buttons() -> Array:
	return [gravity_button, laser_use_button, cannon_button, electron_button]

## Only a NEW press inside a circle can acquire a special button. A release or
## drag from the steering finger always reaches combat, even over a button.
func route_special_touch(event: InputEvent) -> bool:
	if game.state != game.State.PLAYING or game.death_time > 0.0:
		special_touches.clear()
		return false
	var pointer := -2
	var at := Vector2.ZERO
	var pressed := false
	var canceled := false
	if event is InputEventScreenDrag:
		return special_touches.has(event.index)
	if event is InputEventMouseMotion:
		return event.device != InputEvent.DEVICE_ID_EMULATION and special_touches.has(-2)
	if event is InputEventScreenTouch:
		pointer = event.index
		at = event.position
		pressed = event.pressed
		canceled = event.canceled
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return false
		at = event.position
		pressed = event.pressed
	else:
		return false
	if game.combat.owns_pointer(pointer):
		return false
	var flight_buttons := special_buttons() + [pause_button]
	var actions := SPECIAL_ACTIONS + ["pause"]
	if pressed:
		for index in range(actions.size()):
			var button = flight_buttons[index]
			if button.visible and button.contains_point(at):
				special_touches[pointer] = index
				special_touch_msec = Time.get_ticks_msec()
				return true
	elif special_touches.has(pointer):
		var index: int = special_touches[pointer]
		var button = flight_buttons[index]
		special_touches.erase(pointer)
		special_touch_msec = Time.get_ticks_msec()
		if not canceled and button.visible and button.contains_point(at):
			activate_special(actions[index])
		return true
	return false

## No nodes are rebuilt as stock changes. The four thumb-reachable lenses sit
## above the normal flight lane and avoid the phone's lower safe-area inset.
func _process(_delta: float) -> void:
	if is_instance_valid(gravity_button):
		refresh_special_buttons()

func refresh_special_buttons() -> void:
	if not is_instance_valid(gravity_button):
		return
	var playing: bool = game.state == game.State.PLAYING and game.death_time <= 0.0
	for button in special_buttons():
		button.visible = playing
	if not playing:
		special_touches.clear()
		return
	var combat = game.combat
	var diameter := 62.0
	var bottom: float = game.cruise_position().y - 75.0
	for index in range(SPECIAL_ACTIONS.size()):
		var button: Button = special_buttons()[index]
		button.size = Vector2.ONE * diameter
		button.position = Vector2(game.arena.x - diameter - 18.0, bottom - index * 70.0 - diameter * 0.5)
	var blocked: bool = combat.gravity_blocks_control()
	var charge: float = combat.gravity_charge
	var gravity_progress: float = charge / combat.GRAVITY_MAX_CHARGE
	if combat.gravity_armed:
		gravity_progress = combat.gravity_selection_time / combat.GRAVITY_SELECTION_WINDOW
	elif combat.pending_gravity_time >= 0.0:
		gravity_progress = 1.0 - combat.pending_gravity_time / combat.GRAVITY_PREPARATION
	gravity_button.present("%d" % floori(charge), not blocked and charge >= combat.GRAVITY_MIN_CHARGE and combat.pending_gravity_time < 0.0, combat.gravity_armed or combat.pending_gravity_time >= 0.0, gravity_progress, game.visual_time)
	laser_use_button.present("%.0fs" % ceilf(combat.laser_time) if combat.laser_time > 0.0 else "%d" % combat.laser_stock, not blocked and (combat.laser_stock > 0 or combat.laser_time > 0.0), combat.laser_active, combat.laser_time / 10.0, game.visual_time)
	cannon_button.present("%d" % combat.missiles, not blocked and combat.missiles >= 5, false, minf(combat.missiles / 5.0, 1.0), game.visual_time)
	electron_button.present("%d" % combat.electron_stock, not blocked and combat.electron_stock > 0, false, 1.0 if combat.electron_stock > 0 else 0.0, game.visual_time)

## Create a real GUI button with shared colors and focus styling so touch and keyboard navigation work.
func make_button(accent: bool) -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("102b2b") if accent else INK)
	button.add_theme_color_override("font_hover_color", Color("102b2b") if accent else MINT)
	button.add_theme_color_override("font_pressed_color", Color("102b2b") if accent else MINT)
	button.add_theme_stylebox_override("normal", panel(MINT if accent else Color("101c30"), Color("283b51")))
	button.add_theme_stylebox_override("hover", panel(Color("9bf9e0") if accent else Color("1b3045"), MINT))
	button.add_theme_stylebox_override("pressed", panel(Color("48c5af") if accent else Color("1d3a4b"), MINT))
	var focus := panel(Color(0, 0, 0, 0), INK)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	add_child(button)
	return button

## Build the reusable rounded panel style used by menus and buttons.
func panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style

## Update button visibility, positions and labels after state or layout changes; redraw-only HUD values need no new nodes.
func refresh() -> void:
	if not is_inside_tree():
		return
	var w: float = game.arena.x
	var h: float = game.arena.y
	var menu: bool = game.state == game.State.MENU
	var playing: bool = game.state == game.State.PLAYING
	if game.death_time > 0.0:
		for button in [primary, secondary, pause_button, sound_button, vibration_button, shake_button, laser_button, distortion_button, gravity_button, laser_use_button, cannon_button, electron_button]:
			button.visible = false
		queue_redraw()
		return
	refresh_special_buttons()
	primary.visible = not playing
	secondary.visible = not playing and not menu
	pause_button.visible = playing
	sound_button.visible = not playing
	vibration_button.visible = not playing
	shake_button.visible = not playing
	laser_button.visible = not playing
	distortion_button.visible = not playing
	primary.text = "Launch endless flight  →" if menu else ("Resume flight  →" if game.state == game.State.PAUSED else "Fly again  →")
	secondary.text = "Return to title"
	primary.position = Vector2(40, h - game.bottom_inset - 224) if menu else Vector2(64, h * 0.36 + 215)
	primary.size = Vector2(w - (80 if menu else 128), 62)
	secondary.position = primary.position + Vector2(0, 76)
	secondary.size = primary.size
	pause_button.position = Vector2(w - 66, game.top_inset - 4.0)
	pause_button.size = Vector2(48, 48)
	pause_button.present("", true, false, 0.0, game.visual_time)
	sound_button.position = Vector2(32, h - game.bottom_inset - 74)
	sound_button.size = Vector2((w - 76) * 0.5, 46)
	vibration_button.position = Vector2(w * 0.5 + 6, h - game.bottom_inset - 74)
	vibration_button.size = sound_button.size
	vibration_button.text = "VIBRATION  " + ("ON" if game.progress.vibration_enabled else "OFF")
	sound_button.text = "SOUND  " + ("ON" if game.progress.sound_enabled else "OFF")
	var third := (w - 80.0) / 3.0
	shake_button.position = Vector2(32, h - game.bottom_inset - 128)
	shake_button.size = Vector2(third, 42)
	laser_button.position = Vector2(40 + third, h - game.bottom_inset - 128)
	laser_button.size = Vector2(third, 42)
	distortion_button.position = Vector2(48 + third * 2.0, h - game.bottom_inset - 128)
	distortion_button.size = Vector2(third, 42)
	shake_button.text = "SHAKE  " + ("ON" if game.progress.screen_shake_enabled else "OFF")
	laser_button.text = "LASER  " + ("FULL" if game.progress.laser_brightness > 0.7 else "SOFT")
	distortion_button.text = "WARP  " + ("FULL" if game.progress.distortion_strength > 0.7 else "SOFT")
	# Clear focus after a click; keyboard users can still Tab through visible buttons.
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	queue_redraw()

## Draw one string at a baseline position using the shared UI font.
func text_at(value: String, at: Vector2, font_size: int, tint: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

## Measure a string and center its baseline horizontally in the viewport.
func centered(value: String, y: float, font_size: int, tint: Color = INK) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	text_at(value, Vector2((size.x - width) * 0.5, y), font_size, tint)

## Draw centered lettering with explicit spacing between glyphs for small HUD headings.
func tracked(value: String, y: float, font_size: int, tracking: float, tint: Color) -> void:
	var width := 0.0
	for letter in value:
		width += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking
	var x := (size.x - width + tracking) * 0.5
	for letter in value:
		text_at(letter, Vector2(x, y), font_size, tint)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	if not font:
		return
	var w: float = game.arena.x
	var h: float = game.arena.y
	var top: float = game.top_inset
	if game.death_time > 0.0:
		centered("GRAVITY COLLAPSE" if game.death_is_gravity else "SHIP DESTROYED", h * 0.3, 24, Color("ffb18f"))
		centered(game.loss_reason, h * 0.3 + 30, 13, INK)
		return
	if game.state == game.State.MENU:
		tracked("ENDLESS FLIGHT", top + 28, 12, 3.0, MINT)
		tracked("ALIEN", top + 142, 58, 9.0, INK)
		tracked("INVASION", top + 205, 56, 4.0, INK)
		centered("Keep flying. Make every life count.", top + 250, 17, MUTED)
		tracked("HIGH SCORE  %06d" % game.progress.best_for("endless"), top + 290, 12, 1.5, MINT)
		centered("Hold your ship to fire · drag to steer", h - game.bottom_inset - 318, 16, Color("ffc56e"))
		centered("Tap enemies for cannons · buttons deploy specials", h - game.bottom_inset - 292, 13, MUTED)
		centered("Alien kills charge gravity · tap to resist a hole", h - game.bottom_inset - 270, 13, MUTED)
		centered("Lasers save 10 seconds of fire · hull repairs up to 3", h - game.bottom_inset - 248, 13, INK)
		return
	# Floating essentials leave the upper playfield open. The boss indicator
	# follows its hull until final boss damage artwork replaces health bars.
	text_at("%06d" % game.score, Vector2(24, top + 27), 22, Color(0.9, 0.96, 1.0, 0.88))
	if is_instance_valid(game.boss):
		var boss_at: Vector2 = game.boss.body_position + Vector2(-48, 82)
		boss_at.x = clampf(boss_at.x, 10.0, w - 106.0)
		boss_at.y = maxf(boss_at.y, top + 10.0)
		draw_style_box(panel(Color(0.035, 0.07, 0.13, 0.6), Color(0, 0, 0, 0)), Rect2(boss_at, Vector2(96, 4)))
		var tint := Color("75cfff") if game.boss_is_shielded() else Color("ffbb85")
		draw_style_box(panel(tint, Color(0, 0, 0, 0)), Rect2(boss_at, Vector2(96.0 * float(game.boss.health) / game.boss.max_health, 4)))
	if game.state == game.State.PLAYING:
		if game.boss_warning > 0.0:
			centered("BOSS APPROACHING", top + 202, 25, Color("ffb86a"))
			centered(BOSS_NAMES.get(game.pending_boss, "UNKNOWN SIGNAL"), top + 231, 13, INK)
		elif game.recovery_time > 0.0 and not game.gravity_is_active():
			centered("BOSS DEFEATED", h * 0.43, 26, MINT)
			centered("Keep flying. The next sector awaits.", h * 0.43 + 29, 14, MUTED)
		if game.pickup_notice_time > 0.0:
			centered(game.pickup_notice, h - game.bottom_inset - 220, 15, Color("ffc56e"))
		if game.damage_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.26, 0.22, game.damage_flash * 0.13))
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.04, 0.08, 0.86))
	var y := h * 0.36
	var paused: bool = game.state == game.State.PAUSED
	draw_style_box(panel(Color("101c30"), Color("2b4258")), Rect2(32, y - 58, w - 64, 426))
	tracked("FLIGHT PAUSED" if paused else "RUN ENDED", y - 17, 11, 2, MINT if paused else Color("ffb18f"))
	centered("Take a breath." if paused else "One more flight?", y + 32, 32)
	centered("Your flight will wait for you." if paused else game.loss_reason, y + 66, 13, MUTED)
	centered("%06d" % game.score, y + 128, 42)
	centered("%d BOSSES DEFEATED" % game.bosses_defeated, y + 156, 11, MUTED)
	centered("NEW HIGH SCORE" if not paused and game.score > game.best_at_start else "HIGH SCORE  %06d" % game.progress.best_for("endless"), y + 188, 12, MINT)

## Retained for older capture tools. Flight feedback now comes from the field,
## shield, engine and button states, never an instruction panel over the action.
func draw_boss_notice() -> void:
	pass
