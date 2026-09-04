extends Control
## Real GUI buttons keep menus usable with touch, mouse, and keyboard focus.

const INK := Color("e8f0f5")
const MUTED := Color("94a7bc")
const MINT := Color("64edcf")
const MODE_LABELS := {"fleet": "First contact", "black": "Black hole", "white": "White hole", "asteroid": "Asteroid forge"}
var game: Node2D
var primary: Button
var secondary: Button
var pause_button: Button
var sound_button: Button
var font: Font
var mode_buttons: Dictionary = {}

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
	for mode in MODE_LABELS:
		var button := make_button(false)
		button.text = MODE_LABELS[mode]
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(game.select_mode.bind(mode))
		mode_buttons[mode] = button

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
	primary.text = "Launch mission  →" if menu else ("Resume flight  →" if game.state == game.State.PAUSED else "Fly again  →")
	secondary.text = "Return to title"
	primary.position = Vector2(48, h - game.bottom_inset - 186) if menu else Vector2(64, h * 0.36 + 215)
	primary.size = Vector2(w - (96 if menu else 128), 62)
	secondary.position = primary.position + Vector2(0, 76)
	secondary.size = primary.size
	pause_button.position = Vector2(w - 88, game.top_inset)
	pause_button.size = Vector2(56, 56)
	sound_button.position = Vector2(w * 0.5 - 75, h - game.bottom_inset - 74)
	sound_button.size = Vector2(150, 46)
	sound_button.text = "SOUND  " + ("ON" if game.progress.sound_enabled else "OFF")
	var index := 0
	for mode in mode_buttons:
		var button: Button = mode_buttons[mode]
		button.visible = menu
		button.position = Vector2(48 + (index % 2) * ((w - 108) * 0.5 + 12), h - game.bottom_inset - 300 + floori(index / 2.0) * 54)
		button.size = Vector2((w - 108) * 0.5, 44)
		button.add_theme_stylebox_override("normal", panel(Color("1b3645") if mode == game.selected_mode else Color("101c30"), MINT if mode == game.selected_mode else Color("283b51")))
		index += 1
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
		tracked("FLIGHT SELECT / " + str(MODE_LABELS[game.selected_mode]).to_upper(), top + 25, 11, 1.5, MINT)
		draw_line(Vector2(w * 0.5 - 24, top + 57), Vector2(w * 0.5 + 24, top + 57), Color("355364"), 1)
		tracked("ALIEN", top + 143, 58, 9.0, INK)
		tracked("INVASION", top + 207, 58, 4.0, INK)
		centered("Protect the quiet between the stars.", top + 250, 17, MUTED)
		tracked("CHOOSE YOUR FLIGHT", h - game.bottom_inset - 324, 11, 1.8, MUTED)
		var hint := "Drag to steer · weapons fire automatically."
		if game.selected_mode in ["black", "white"]:
			hint = "Drag to steer · tap rapidly to resist the hole."
		elif game.selected_mode == "asteroid":
			hint = "Dodge the asteroids, or shoot them apart."
		centered(hint, h - game.bottom_inset - 100, 13, MUTED)
		tracked("FLIGHT BEST  %04d" % game.progress.best_for(game.selected_mode), h - game.bottom_inset, 11, 1.5, MUTED)
		return
	draw_rect(Rect2(0, 0, w, top + 121), Color("080e20"))
	text_at("SCORE", Vector2(32, top + 13), 11, MUTED)
	text_at("%04d" % game.score, Vector2(32, top + 50), 32)
	centered(str(MODE_LABELS[game.encounter]).to_upper(), top + 14, 11, MINT)
	centered("WAVE 01" if game.encounter == "fleet" else "BOSS ENCOUNTER", top + 43, 16)
	draw_line(Vector2(32, top + 78), Vector2(w - 32, top + 78), Color("233247"), 1)
	text_at("HULL", Vector2(32, top + 109), 11, MUTED)
	for i in range(3):
		var at := Vector2(86 + i * 23, top + 104)
		draw_circle(at, 5.5, MINT if i < game.lives else Color("293349"))
	var remaining := "%02d / 15 REMAINING" % game.enemies.size()
	if is_instance_valid(game.boss):
		remaining = "BOSS CORE  %d%%" % roundi(100.0 * game.boss.health / game.boss.max_health)
		draw_rect(Rect2(32, top + 132, w - 64, 4), Color("243147"))
		draw_rect(Rect2(32, top + 132, (w - 64) * game.boss.health / game.boss.max_health, 4), Color("ffb86a"))
		var phase_label := "EXCHANGE FIRE"
		if game.boss.phase == "warning":
			phase_label = "SPECIAL ATTACK INCOMING"
		elif game.boss.phase in ["active", "clearing"]:
			phase_label = "ASTEROID BARRAGE" if game.boss.kind == "asteroid" else "RESIST THE HOLE"
		tracked(phase_label, top + 160, 10, 1.3, MUTED)
	text_at(remaining, Vector2(w - 32 - font.get_string_size(remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, top + 109), 11, MUTED)
	var drag_y: float = h - game.bottom_inset - 46
	draw_line(Vector2(w * 0.5 - 50, drag_y), Vector2(w * 0.5 + 50, drag_y), Color("294758"), 2)
	draw_circle(Vector2(w * 0.5, drag_y), 4, MINT)
	var resisting: bool = is_instance_valid(game.boss) and game.boss.holds_steering()
	tracked("TAP ANYWHERE · SPACE ON KEYBOARD" if resisting else "DRAG ANYWHERE TO MOVE", drag_y + 28, 10, 1.1, MUTED)
	if game.elapsed < 4.0 and game.state == game.State.PLAYING and game.encounter == "fleet":
		centered("Your weapons fire automatically.", h - game.bottom_inset - 239, 15, Color(MUTED, clampf(4.0 - game.elapsed, 0, 1)))
	if game.damage_flash > 0 and game.state == game.State.PLAYING:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.26, 0.22, game.damage_flash * 0.13))
	if game.state == game.State.PLAYING:
		if is_instance_valid(game.boss):
			draw_boss_notice()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.04, 0.08, 0.86))
	var y: float = h * 0.36
	draw_style_box(panel(Color("101c30"), Color("2b4258")), Rect2(32, y - 58, w - 64, 426))
	var paused: bool = game.state == game.State.PAUSED
	var won: bool = game.state == game.State.WON
	tracked("FLIGHT PAUSED" if paused else ("SECTOR SECURED" if won else "SIGNAL LOST"), y - 17, 11, 2, MINT if paused or won else Color("ffb18f"))
	centered("Take a breath." if paused else ("Clear skies." if won else "One more flight?"), y + 32, 34)
	centered("Your mission will wait for you." if paused else ("Every invader stopped. Beautiful flying." if won and game.encounter == "fleet" else ("The boss is down. Beautiful flying." if won else game.loss_reason)), y + 68, 13, MUTED)
	centered("%04d" % game.score, y + 132, 43)
	tracked("CURRENT SCORE" if paused else "FINAL SCORE", y + 156, 10, 1.5, MUTED)
	var record := "NEW FLIGHT BEST" if not paused and game.score > game.best_at_start else "FLIGHT BEST  %04d" % game.progress.best_for(game.encounter)
	centered(record, y + 189, 12, MINT)

func draw_boss_notice() -> void:
	var boss: Node2D = game.boss
	var y: float = game.ship.position.y - 155
	if boss.kind == "white":
		draw_rect(Rect2(0, 160, 5, size.y - 160), Color("7ab6c4"))
		draw_rect(Rect2(size.x - 5, 160, 5, size.y - 160), Color("7ab6c4"))
	if boss.phase == "firefight":
		if boss.phase_time < 2.5:
			centered("Dodge the boss's shots. Keep firing back.", y - 20, 14, MUTED)
		return
	if boss.kind == "asteroid":
		# Keep the playfield unobstructed while the pilot is dodging rocks.
		centered("ASTEROID BARRAGE INCOMING" if boss.phase == "warning" else "Dodge or shoot the asteroids.", y - 20, 16, Color("ffd19d"))
		centered("Only hits on the boss damage its core.", y + 7, 12, MUTED)
		return
	draw_style_box(panel(Color("101c30"), Color("425064")), Rect2(48, y - 45, size.x - 96, 111))
	if boss.phase == "warning":
		centered("BLACK HOLE FORMING" if boss.kind == "black" else "WHITE HOLE FORMING", y - 12, 18, Color("ffd19d"))
		centered("Get ready to tap rapidly.", y + 17, 15)
		centered("Avoid the dark core." if boss.kind == "black" else "The screen edges are lethal.", y + 44, 13, MUTED)
	else:
		centered("TAP TO RESIST", y - 12, 23, MINT)
		centered("Fight the pull." if boss.kind == "black" else "Fight the push. Stay away from the edges.", y + 15, 13)
		draw_rect(Rect2(76, y + 34, size.x - 152, 9), Color("2a354a"))
		draw_rect(Rect2(76, y + 34, (size.x - 152) * boss.resistance, 9), MINT)
