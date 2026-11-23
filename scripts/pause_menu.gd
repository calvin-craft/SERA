extends CanvasLayer

signal resumed
signal retried
signal title_requested

const MenuTheme = preload("res://scripts/menu_theme.gd")
const MenuItem = preload("res://scripts/menu_item.gd")
const Texts = preload("res://texts.gd")
## The inputs in the controls panel; their descriptions are Texts.CONTROLS, in the same order.
const CONTROL_KEYS := [
	["A", "D"], ["Space"], ["LMB"], ["Shift"], ["W", "+", "Shift"], ["RMB"], ["W", "+", "RMB"], ["E"], ["R"],
]

var screen: ColorRect
var continue_button: Button
var retry_button: Button
var title_button: Button
var help: Label
var decor: Control
var items: Array[MenuItem] = []
var heading := ""
var detail := ""
var shown_for := 0.0
## Rows for abilities this stage has switched on: [input tokens, description].
var extra_controls: Array = []


func _ready() -> void:
	layer = 8
	process_mode = PROCESS_MODE_ALWAYS
	screen = ColorRect.new()
	screen.color = Color(0.008, 0.02, 0.032, 0.6)
	screen.theme = MenuTheme.create()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var side := Gradient.new()
	side.offsets = PackedFloat32Array([0.0, 0.42, 0.75])
	side.colors = PackedColorArray([Color(0.005, 0.015, 0.024, 0.92), Color(0.005, 0.015, 0.024, 0.75), Color(0.005, 0.015, 0.024, 0.0)])
	var shade := TextureRect.new()
	shade.texture = GradientTexture2D.new()
	shade.texture.gradient = side
	shade.texture.width = 256
	shade.texture.height = 4
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	decor = Control.new()
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(decor)
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.draw.connect(_draw_decor)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	screen.add_child(column)
	column.anchor_left = 0.065
	column.anchor_right = 0.42
	column.offset_top = 262
	continue_button = _item(Texts.PAUSE_CONTINUE, "Esc")
	retry_button = _item(Texts.PAUSE_RETRY, "")
	title_button = _item(Texts.PAUSE_TO_TITLE, "")
	for item in items:
		column.add_child(item)
	help = MenuTheme.label("", 14, MenuTheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	continue_button.pressed.connect(func(): resumed.emit())
	retry_button.pressed.connect(func(): retried.emit())
	title_button.pressed.connect(func(): title_requested.emit())
	screen.hide()


func _item(text: String, caption: String) -> MenuItem:
	var item := MenuItem.new()
	item.text = text
	item.caption = caption
	item.compact = true
	item.font_size = 22
	item.custom_minimum_size.y = 54
	items.append(item)
	return item


func _process(delta: float) -> void:
	if screen.visible:
		shown_for += delta
		decor.queue_redraw()


func open_menu(can_retry: bool, campaign_run: bool, stage_heading: String = "", stage_detail: String = "", abilities: Array = []) -> void:
	retry_button.disabled = not can_retry
	heading = stage_heading
	detail = stage_detail
	extra_controls = abilities
	help.text = Texts.PAUSE_HELP if campaign_run and can_retry else ""
	shown_for = 0.0
	screen.show()
	screen.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(screen, "modulate:a", 1.0, 0.16)
	for i in items.size():
		items[i].reveal = 0.0
		tween.tween_property(items[i], "reveal", 1.0, 0.32).set_delay(0.04 + i * 0.05) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	continue_button.grab_focus()


func close_menu() -> void:
	screen.hide()


func _draw_decor() -> void:
	var eased := ease(clampf(shown_for / 0.35, 0.0, 1.0), -2.4)
	var left := decor.size.x * 0.065
	MenuTheme.slant(decor, Rect2(left, 112, 30.0 * eased, 4), MenuTheme.ACCENT, 3.0)
	MenuTheme.spaced(decor, MenuTheme.display_font(600), Vector2(left + 40, 120), Texts.PAUSE_EYEBROW, 14, Color(MenuTheme.ACCENT, eased), 5.0)
	decor.draw_string(MenuTheme.text_font(700), Vector2(left + (1.0 - eased) * -24.0, 170), Texts.PAUSE_HEADING,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(MenuTheme.TEXT, eased))
	decor.draw_rect(Rect2(left, 188, 300.0 * eased, 2), Color(MenuTheme.ACCENT, 0.7))
	if not heading.is_empty():
		decor.draw_string(MenuTheme.text_font(500), Vector2(left, 222), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(MenuTheme.MUTED, eased))
	if not detail.is_empty():
		decor.draw_string(MenuTheme.display_font(600), Vector2(left, 244), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MenuTheme.ACCENT, 0.8 * eased))
	_draw_controls(eased)
	var y := decor.size.y - 44.0
	var x := left
	x += MenuTheme.keycap(decor, Vector2(x, y), "↑↓", Texts.KEY_SELECT, eased) + 22.0
	x += MenuTheme.keycap(decor, Vector2(x, y), "Enter", Texts.KEY_CONFIRM, eased) + 22.0
	MenuTheme.keycap(decor, Vector2(x, y), "Esc", Texts.PAUSE_CONTINUE, eased)


func _draw_controls(alpha: float) -> void:
	var rows: Array = []
	for i in CONTROL_KEYS.size():
		rows.append([CONTROL_KEYS[i], Texts.CONTROLS[i] if i < Texts.CONTROLS.size() else ""])
	rows.append_array(extra_controls)
	var step := 38.0 if rows.size() <= 9 else 34.0
	var panel := Rect2(decor.size.x * 0.56, 156.0 - (rows.size() - 9) * 10.0 if rows.size() > 9 else 156.0,
		decor.size.x * 0.44 - 60.0, 54.0 + rows.size() * step)
	panel.position.x += (1.0 - alpha) * 30.0
	MenuTheme.slant(decor, panel, Color(0.02, 0.05, 0.07, 0.78 * alpha), 14.0)
	MenuTheme.slant(decor, Rect2(panel.position, Vector2(panel.size.x, 3.0)), Color(MenuTheme.ACCENT, alpha), 1.0)
	var x := panel.position.x + 30.0
	MenuTheme.spaced(decor, MenuTheme.display_font(600), Vector2(x, panel.position.y + 32.0), Texts.CONTROLS_EYEBROW, 13, Color(MenuTheme.ACCENT, alpha), 4.0)
	decor.draw_string(MenuTheme.text_font(500), Vector2(x + 112.0, panel.position.y + 32.0), Texts.CONTROLS_HEADING, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(MenuTheme.MUTED, alpha))
	var y := panel.position.y + 50.0
	for row: Array in rows:
		MenuTheme.combo(decor, Vector2(x, y), row[0], alpha, 13)
		decor.draw_string(MenuTheme.text_font(), Vector2(x + 124.0, y + 16.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MenuTheme.TEXT, alpha))
		y += step
