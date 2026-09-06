extends Control
## Real GUI buttons keep menus usable with touch, mouse, and keyboard focus.

const INK := Color("e8f0f5")
const MUTED := Color("94a7bc")
const MINT := Color("64edcf")
const BOSS_NAMES := {"black": "BLACK HOLE", "white": "WHITE HOLE", "asteroid": "ASTEROID FORGE", "swarm": "SWARM CARRIER"}
var game: Node2D
var primary: Button
var secondary: Button
var pause_button: Button
var sound_button: Button
var font: Font

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
	pause_button = make_button(false)
	pause_button.text = "II"
	pause_button.tooltip_text = "Pause · P / Esc"
	pause_button.pressed.connect(game.pause_run)
	sound_button = make_button(false)
	sound_button.add_theme_font_size_override("font_size", 13)
	sound_button.pressed.connect(game.toggle_sound)

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

func panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style

func refresh() -> void:
	if not is_inside_tree():
		return
	var w: float = game.arena.x
	var h: float = game.arena.y
	var menu: bool = game.state == game.State.MENU
	var playing: bool = game.state == game.State.PLAYING
	primary.visible = not playing
	secondary.visible = not playing and not menu
	pause_button.visible = playing
	sound_button.visible = not playing
	primary.text = "Launch endless flight  →" if menu else ("Resume flight  →" if game.state == game.State.PAUSED else "Fly again  →")
	secondary.text = "Return to title"
	primary.position = Vector2(40, h - game.bottom_inset - 170) if menu else Vector2(64, h * 0.36 + 215)
	primary.size = Vector2(w - (80 if menu else 128), 62)
	secondary.position = primary.position + Vector2(0, 76)
	secondary.size = primary.size
	pause_button.position = Vector2(w - 88, game.top_inset)
	pause_button.size = Vector2(56, 56)
	sound_button.position = Vector2(w * 0.5 - 75, h - game.bottom_inset - 74)
	sound_button.size = Vector2(150, 46)
	sound_button.text = "SOUND  " + ("ON" if game.progress.sound_enabled else "OFF")
	# Clear focus after a click; keyboard users can still Tab through visible buttons.
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	queue_redraw()

func text_at(value: String, at: Vector2, font_size: int, tint: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func centered(value: String, y: float, font_size: int, tint: Color = INK) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	text_at(value, Vector2((size.x - width) * 0.5, y), font_size, tint)

func tracked(value: String, y: float, font_size: int, tracking: float, tint: Color) -> void:
	var width := 0.0
	for letter in value:
		width += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking
	var x := (size.x - width + tracking) * 0.5
	for letter in value:
		text_at(letter, Vector2(x, y), font_size, tint)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking

func _draw() -> void:
	if not font:
		return
	var w: float = game.arena.x
	var h: float = game.arena.y
	var top: float = game.top_inset
	if game.state == game.State.MENU:
		tracked("ENDLESS FLIGHT", top + 28, 12, 3.0, MINT)
		tracked("ALIEN", top + 142, 58, 9.0, INK)
		tracked("INVASION", top + 205, 56, 4.0, INK)
		centered("Keep flying. Make every life count.", top + 250, 17, MUTED)
		tracked("HIGH SCORE  %06d" % game.progress.best_for("endless"), top + 290, 12, 1.5, MINT)
		centered("Single → Double → Triple → Laser → Rockets", h - game.bottom_inset - 292, 16, Color("ffc56e"))
		centered("Catch weapon drops for power and one emergency life.", h - game.bottom_inset - 262, 13, MUTED)
		centered("Hull drops restore lives. Carry up to three.", h - game.bottom_inset - 239, 13, MUTED)
		centered("Drag to steer · auto-fire · tap against gravity", h - game.bottom_inset - 200, 13, INK)
		return
	draw_rect(Rect2(0, 0, w, top + 143), Color("080e20"))
	text_at("SCORE", Vector2(28, top + 12), 11, MUTED)
	text_at("%06d" % game.score, Vector2(28, top + 48), 31)
	text_at("HIGH SCORE", Vector2(w * 0.48, top + 12), 10, MINT)
	text_at("%06d" % game.progress.best_for("endless"), Vector2(w * 0.48, top + 42), 23)
	text_at("HULL", Vector2(28, top + 84), 10, MUTED)
	for i in range(3):
		draw_circle(Vector2(77 + i * 22, top + 79), 5, MINT if i < game.lives else Color("293349"))
	if game.weapons.level > 0:
		text_at("+ BACKUP", Vector2(152, top + 84), 10, Color("ffc56e"))
	text_at(game.weapons.weapon_name(), Vector2(w - 125, top + 84), 12, Color("ffc56e"))
	if is_instance_valid(game.boss):
		centered(BOSS_NAMES.get(game.boss.kind, "BOSS"), top + 112, 12, Color("ffb86a"))
		draw_rect(Rect2(28, top + 127, w - 56, 4), Color("293349"))
		draw_rect(Rect2(28, top + 127, (w - 56) * float(game.boss.health) / game.boss.max_health, 4), Color("ffb86a"))
	else:
		tracked("SECTOR %02d  ·  %d BOSSES DEFEATED" % [game.bosses_defeated + 1, game.bosses_defeated], top + 119, 10, 1.0, MUTED)
	if game.state == game.State.PLAYING:
		if game.boss_warning > 0.0:
			centered("BOSS APPROACHING", top + 202, 25, Color("ffb86a"))
			centered(BOSS_NAMES.get(game.pending_boss, "UNKNOWN SIGNAL"), top + 231, 13, INK)
		elif game.recovery_time > 0.0:
			centered("BOSS DEFEATED", h * 0.43, 26, MINT)
			centered("Keep flying. The next sector awaits.", h * 0.43 + 29, 14, MUTED)
		elif is_instance_valid(game.boss):
			draw_boss_notice()
		if game.pickup_notice_time > 0.0:
			centered(game.pickup_notice, h - game.bottom_inset - 220, 15, Color("ffc56e"))
		centered("DRAG TO STEER", h - game.bottom_inset - 5, 10, MUTED)
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

func draw_boss_notice() -> void:
	var boss: Node2D = game.boss
	# Keep instructions clear of the white hole that now often appears above the ship.
	var y: float = game.arena.y * 0.52
	if boss.kind == "white":
		draw_rect(Rect2(Vector2(2.5, 2.5), size - Vector2(5, 5)), Color("36505e"), false, 3)
		if boss.phase in ["warning", "active"]:
			var edge_start := Vector2(3, size.y - 3)
			var edge_end := Vector2(size.x - 3, size.y - 3)
			if boss.white_push_direction == Vector2.UP:
				edge_start.y = 3
				edge_end.y = 3
			elif boss.white_push_direction == Vector2.LEFT:
				edge_start = Vector2(3, 3)
				edge_end = Vector2(3, size.y - 3)
			elif boss.white_push_direction == Vector2.RIGHT:
				edge_start = Vector2(size.x - 3, 3)
				edge_end = Vector2(size.x - 3, size.y - 3)
			draw_line(edge_start, edge_end, Color("ffb86a"), 5)
	if boss.phase in ["firefight", "arrival"]:
		if boss.phase_time < 2.5:
			centered("Dodge the boss's shots. Keep firing back.", y - 20, 14, MUTED)
		return
	if boss.kind in ["asteroid", "swarm"]:
		# Keep the playfield unobstructed while the pilot is dodging rocks.
		centered("REINFORCEMENTS INCOMING" if boss.phase == "warning" else "Dodge or shoot the incoming threats.", y - 20, 16, Color("ffd19d"))
		centered("Only hits on the boss damage its core.", y + 7, 12, MUTED)
		return
	draw_style_box(panel(Color("101c30"), Color("425064")), Rect2(48, y - 45, size.x - 96, 111))
	if boss.phase == "warning":
		centered("BLACK HOLE FORMING" if boss.kind == "black" else "WHITE HOLE FORMING", y - 12, 18, Color("ffd19d"))
		centered("Get ready to tap rapidly.", y + 17, 15)
		centered("Avoid the dark core." if boss.kind == "black" else "The screen edges are lethal.", y + 44, 13, MUTED)
	else:
		centered("FORCE NEUTRALISED" if boss.neutralisation() >= 1.0 else "TAP TO BLOCK FORCE", y - 12, 21, MINT)
		centered("Keep tapping to hold your position.", y + 15, 13)
		draw_rect(Rect2(76, y + 34, size.x - 152, 9), Color("2a354a"))
		draw_rect(Rect2(76, y + 34, (size.x - 152) * boss.neutralisation(), 9), MINT)
