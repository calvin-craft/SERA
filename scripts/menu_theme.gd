extends RefCounted

## Shared look for menus and the in-game HUD: palette, fonts, the Control theme
## and small drawing helpers for slanted plates and key caps.

const TEXT := Color("#e8f7f7")
const MUTED := Color("#a3bac3")
const DIM := Color("#5f7782")
const ACCENT := Color("#87e7f5")
const AMBER := Color("#ffc27b")
const HEAT := Color("#ff9673")
const INK := Color("#050c11")
const PANE := Color(0.025, 0.056, 0.075, 0.96)
const PLATE := Color(0.02, 0.05, 0.07, 0.78)
const EDGE := Color(0.53, 0.78, 0.84, 0.32)
const SKEW := 12.0

static var _fonts: Dictionary = {}


static func display_font(weight: int = 700) -> SystemFont:
	return _font(&"display", weight, ["Bahnschrift", "Barlow Condensed", "DejaVu Sans", "Arial"])


static func text_font(weight: int = 400) -> SystemFont:
	return _font(&"text", weight, ["Malgun Gothic", "Noto Sans CJK KR", "Arial"])


static func _font(kind: StringName, weight: int, names: Array) -> SystemFont:
	var key := "%s_%d" % [kind, weight]
	if not _fonts.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(names)
		font.font_weight = weight
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_fonts[key] = font
	return _fonts[key]


static func create() -> Theme:
	var style := Theme.new()
	style.default_font = text_font()
	style.default_font_size = 19
	var neutral := panel(Color(0.046, 0.11, 0.15, 0.93), Color("#384e59"), 17.0)
	var hover := panel(Color("#16414d"), Color("#65a7b7"), 17.0)
	var pressed := panel(Color("#205765"), ACCENT, 17.0)
	var disabled := panel(Color(0.033, 0.07, 0.09, 0.84), Color("#2c4349"), 17.0)
	var focus := panel(Color.TRANSPARENT, ACCENT, 17.0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	for box in [neutral, hover, pressed, disabled, focus]:
		box.skew = Vector2(0.18, 0.0)
	style.set_stylebox(&"normal", &"Button", neutral)
	style.set_stylebox(&"hover", &"Button", hover)
	style.set_stylebox(&"pressed", &"Button", pressed)
	style.set_stylebox(&"disabled", &"Button", disabled)
	style.set_stylebox(&"focus", &"Button", focus)
	style.set_color(&"font_color", &"Button", TEXT)
	style.set_color(&"font_disabled_color", &"Button", Color("#79909a"))
	style.set_color(&"font_hover_color", &"Button", Color.WHITE)
	style.set_color(&"font_focus_color", &"Button", Color.WHITE)
	style.set_type_variation(&"PrimaryButton", &"Button")
	style.set_stylebox(&"normal", &"PrimaryButton", panel(Color("#153f50"), Color("#65a8b5"), 17.0))

	# Confirmation dialogs render as embedded windows: make them a slanted HUD card.
	var window := panel(PANE, ACCENT, 26.0)
	window.border_width_top = 3
	window.expand_margin_top = 34.0
	window.shadow_color = Color(0, 0, 0, 0.55)
	window.shadow_size = 24
	style.set_stylebox(&"embedded_border", &"Window", window)
	style.set_stylebox(&"embedded_unfocused_border", &"Window", window)
	style.set_font(&"title_font", &"Window", text_font(700))
	style.set_font_size(&"title_font_size", &"Window", 18)
	style.set_color(&"title_color", &"Window", ACCENT)
	style.set_constant(&"title_height", &"Window", 34)
	var dialog := StyleBoxEmpty.new()
	dialog.content_margin_left = 26.0
	dialog.content_margin_right = 26.0
	dialog.content_margin_top = 20.0
	dialog.content_margin_bottom = 20.0
	style.set_stylebox(&"panel", &"AcceptDialog", dialog)
	style.set_constant(&"buttons_separation", &"AcceptDialog", 18)
	style.set_constant(&"buttons_min_width", &"AcceptDialog", 150)
	style.set_color(&"font_color", &"Label", TEXT)
	return style


static func panel(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding * 0.62
	box.content_margin_bottom = padding * 0.62
	return box


static func label(text: String, font_size: int, color: Color = TEXT, weight: int = 400) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", color)
	if weight != 400:
		node.add_theme_font_override(&"font", text_font(weight))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, height: float = 49.0) -> Button:
	var node := Button.new()
	node.text = text
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.custom_minimum_size.y = height
	return node


## A parallelogram leaning right, the basic shape of every plate in the UI.
static func slant_points(rect: Rect2, skew: float = SKEW) -> PackedVector2Array:
	if rect.size.x < 0.5 or rect.size.y < 0.5:
		return PackedVector2Array()
	skew = minf(skew, rect.size.x * 0.5)
	return PackedVector2Array([
		rect.position + Vector2(skew, 0.0),
		Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(skew, 0.0),
		Vector2(rect.position.x, rect.end.y),
	])


static func slant(canvas: CanvasItem, rect: Rect2, color: Color, skew: float = SKEW) -> void:
	var points := slant_points(rect, skew)
	if not points.is_empty() and color.a > 0.0:
		canvas.draw_colored_polygon(points, color)


static func slant_fade(canvas: CanvasItem, rect: Rect2, from: Color, to: Color, skew: float = SKEW) -> void:
	var points := slant_points(rect, skew)
	if not points.is_empty():
		canvas.draw_polygon(points, PackedColorArray([from, to, to, from]))


static func slant_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float = 1.0, skew: float = SKEW) -> void:
	var points := slant_points(rect, skew)
	if points.is_empty():
		return
	points.append(points[0])
	canvas.draw_polyline(points, color, width, true)


## Draws text with extra spacing between letters. Returns the drawn width.
static func spaced(canvas: CanvasItem, font: Font, origin: Vector2, text: String, font_size: int, color: Color, spacing: float) -> float:
	var x := origin.x
	for character in text:
		canvas.draw_string(font, Vector2(x, origin.y), character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	return x - origin.x - spacing


static func spaced_width(font: Font, text: String, font_size: int, spacing: float) -> float:
	var width := 0.0
	for character in text:
		width += font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	return width - spacing


## A physical-looking key cap followed by its action. Returns the total width.
static func keycap(canvas: CanvasItem, origin: Vector2, key: String, action: String, alpha: float = 1.0, font_size: int = 14) -> float:
	var key_font := display_font(600)
	var width := maxf(24.0, key_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0)
	var cap := Rect2(origin, Vector2(width, 22.0))
	canvas.draw_rect(Rect2(cap.position + Vector2(0, 3), cap.size), Color(0.0, 0.0, 0.0, 0.5 * alpha))
	canvas.draw_rect(cap, Color(0.86, 0.95, 0.97, 0.94 * alpha))
	canvas.draw_rect(Rect2(cap.position.x, cap.end.y - 3.0, cap.size.x, 3.0), Color(0.55, 0.68, 0.73, alpha))
	canvas.draw_string(key_font, Vector2(cap.position.x, cap.position.y + 16.0), key, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(INK, alpha))
	if action.is_empty():
		return width
	var font := text_font()
	canvas.draw_string(font, Vector2(cap.end.x + 8.0, cap.position.y + 16.0), action, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(MUTED, alpha))
	return width + 8.0 + font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func key_width(key: String, font_size: int = 14) -> float:
	return maxf(24.0, display_font(600).get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0)


## A small mouse with the left (1) or right (2) button lit.
static func mouse(canvas: CanvasItem, origin: Vector2, button: int, alpha: float = 1.0) -> float:
	var body := Rect2(origin + Vector2(0.0, -2.0), Vector2(18.0, 26.0))
	var shell := StyleBoxFlat.new()
	shell.set_corner_radius_all(8)
	shell.bg_color = Color(0.0, 0.0, 0.0, 0.5 * alpha)
	canvas.draw_style_box(shell, Rect2(body.position + Vector2(0, 3), body.size))
	shell.bg_color = Color(0.86, 0.95, 0.97, 0.94 * alpha)
	canvas.draw_style_box(shell, body)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(ACCENT.lerp(Color("#3fc8e4"), 0.6), alpha)
	if button == 1:
		lit.corner_radius_top_left = 8
	else:
		lit.corner_radius_top_right = 8
	canvas.draw_style_box(lit, Rect2(body.position + Vector2(0.0 if button == 1 else 9.0, 0.0), Vector2(9.0, 11.0)))
	canvas.draw_line(body.position + Vector2(9, 0), body.position + Vector2(9, 11), Color(INK, 0.55 * alpha), 1.0)
	canvas.draw_line(body.position + Vector2(1, 11), body.position + Vector2(17, 11), Color(INK, 0.55 * alpha), 1.0)
	return body.size.x


## Draws input tokens side by side: key names, "LMB"/"RMB" for mouse buttons,
## and "+" for chords. Returns the width; pass measure to only compute it.
static func combo(canvas: CanvasItem, origin: Vector2, tokens: Array, alpha: float = 1.0, font_size: int = 14, measure: bool = false) -> float:
	var x := origin.x
	for i in tokens.size():
		var token: String = tokens[i]
		if i > 0:
			x += 4.0
		if token == "+":
			if not measure:
				canvas.draw_string(display_font(600), Vector2(x, origin.y + 16.0), "+", HORIZONTAL_ALIGNMENT_CENTER, 12, font_size, Color(MUTED, alpha))
			x += 12.0
		elif token == "LMB" or token == "RMB":
			x += 18.0 if measure else mouse(canvas, Vector2(x, origin.y), 1 if token == "LMB" else 2, alpha)
		else:
			x += key_width(token, font_size) if measure else keycap(canvas, Vector2(x, origin.y), token, "", alpha, font_size)
	return x - origin.x
