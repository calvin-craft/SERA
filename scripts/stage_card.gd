extends Button

## Stage select card with key art. `text` keeps the name and record for
## accessibility; the visible card is drawn in `_draw`.

const MenuTheme = preload("res://scripts/menu_theme.gd")
const Texts = preload("res://texts.gd")
const Skyline = preload("res://scripts/skyline.gd")

var art: Texture2D
## A code-drawn skyline for stages without a painting yet.
var skyline := ""
## Not reached in the campaign yet: shown, but it cannot be started.
var locked := false
var number := 1
var stage_name := ""
var focus_line := ""
var record := ""
var practice_record := ""
var has_practice_record := false
var cleared := false
var tint := MenuTheme.ACCENT

var reveal := 1.0:
	set(value):
		reveal = value
		queue_redraw()

var _glow := 0.0
var _clock := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	for box in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	for color in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
			&"font_disabled_color", &"font_hover_pressed_color"]:
		add_theme_color_override(color, Color.TRANSPARENT)


func _process(delta: float) -> void:
	var goal := 1.0 if has_focus() or is_hovered() else 0.0
	_glow = move_toward(_glow, goal, delta * 6.0)
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if reveal <= 0.0:
		return
	var eased := ease(_glow, -2.0)
	var alpha := reveal
	draw_set_transform(Vector2(0.0, (1.0 - reveal) * 40.0 - eased * 8.0))
	var card := Rect2(Vector2.ZERO, size)
	var art_rect := Rect2(0, 0, size.x, size.y * 0.62)

	if eased > 0.0:
		draw_rect(card.grow(6.0 + sin(_clock * 4.0) * 1.5), Color(tint, 0.10 * eased * alpha))
	draw_rect(Rect2(card.position + Vector2(0, 10), card.size), Color(0, 0, 0, 0.45 * alpha))
	draw_rect(card, Color(0.02, 0.045, 0.06, 0.97 * alpha))
	var shade := lerpf(0.5, 1.0, eased)
	if art:
		var source := _cover(art.get_size(), art_rect.size)
		draw_texture_rect_region(art, art_rect, source, Color(shade, shade, shade, alpha))
	elif not skyline.is_empty():
		Skyline.paint(self, art_rect, skyline, Vector2(576.0 + _clock * 14.0, 342.0), alpha)
		draw_rect(art_rect, Color(0.0, 0.0, 0.0, (1.0 - shade) * alpha))
	if locked:
		draw_rect(art_rect, Color(0.01, 0.025, 0.035, 0.72 * alpha))
		var lock := art_rect.get_center() + Vector2(0.0, -6.0)
		draw_rect(Rect2(lock - Vector2(16.0, 4.0), Vector2(32.0, 26.0)), Color(MenuTheme.MUTED, 0.85 * alpha))
		draw_arc(lock + Vector2(0.0, -4.0), 11.0, PI, TAU, 16, Color(MenuTheme.MUTED, 0.85 * alpha), 4.0, true)
		draw_string(MenuTheme.text_font(700), Vector2(0.0, lock.y + 50.0), Texts.CARD_LOCKED, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
			Color(MenuTheme.MUTED, alpha))
	# Fade the art into the info block.
	var fade_top := art_rect.end.y - 70.0
	draw_polygon(PackedVector2Array([Vector2(0, fade_top), Vector2(size.x, fade_top), Vector2(size.x, art_rect.end.y), Vector2(0, art_rect.end.y)]),
		PackedColorArray([Color(0.02, 0.045, 0.06, 0.0), Color(0.02, 0.045, 0.06, 0.0), Color(0.02, 0.045, 0.06, alpha), Color(0.02, 0.045, 0.06, alpha)]))

	var display := MenuTheme.display_font(700)
	MenuTheme.slant(self, Rect2(14, 14, 98, 24), Color(MenuTheme.INK, 0.82 * alpha), 8.0)
	MenuTheme.spaced(self, display, Vector2(26, 32), Texts.CARD_STAGE.format({"번호": "%02d" % number}), 14, Color(tint, alpha), 1.6)
	if cleared:
		MenuTheme.slant(self, Rect2(size.x - 82, 14, 68, 24), Color(MenuTheme.AMBER, 0.92 * alpha), 8.0)
		draw_string(MenuTheme.text_font(700), Vector2(size.x - 82, 31), Texts.CARD_CLEARED, HORIZONTAL_ALIGNMENT_CENTER, 68, 13, Color(MenuTheme.INK, alpha))

	var y := art_rect.end.y - 4.0
	draw_string(MenuTheme.text_font(700), Vector2(18, y), stage_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(MenuTheme.TEXT, alpha))
	var line := Texts.CARD_LOCKED_NOTE if locked else focus_line
	draw_string(MenuTheme.text_font(), Vector2(18, y + 28), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, 14, Color(MenuTheme.MUTED, alpha))
	draw_line(Vector2(18, y + 46), Vector2(size.x - 18, y + 46), Color(MenuTheme.EDGE, alpha))
	var label_font := MenuTheme.text_font(600)
	var time_font := MenuTheme.display_font(600)
	draw_string(label_font, Vector2(18, y + 68), Texts.CARD_PRACTICE_BEST, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(MenuTheme.MUTED, alpha))
	draw_string(time_font, Vector2(0, y + 69), practice_record, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 18, 20,
		Color(tint if has_practice_record else MenuTheme.DIM, alpha))
	draw_string(label_font, Vector2(18, y + 94), Texts.CARD_BEST, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(MenuTheme.MUTED, alpha))
	draw_string(time_font, Vector2(0, y + 95), record, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 18, 18,
		Color(MenuTheme.AMBER if cleared else MenuTheme.DIM, alpha))

	var border := MenuTheme.EDGE.lerp(tint, eased)
	draw_rect(card, Color(border, alpha), false, lerpf(1.0, 2.0, eased))
	if eased > 0.0:
		var corner := 16.0
		for point: Vector2 in [card.position, Vector2(card.end.x, 0), card.end, Vector2(0, card.end.y)]:
			var h := corner if point.x == 0.0 else -corner
			var v := corner if point.y == 0.0 else -corner
			var p: Vector2 = point + Vector2(-h, -v) * 0.25
			draw_line(p, p + Vector2(h, 0), Color(tint, eased * alpha), 3.0)
			draw_line(p, p + Vector2(0, v), Color(tint, eased * alpha), 3.0)
	draw_set_transform(Vector2.ZERO)


static func _cover(texture_size: Vector2, target: Vector2) -> Rect2:
	var scale := maxf(target.x / texture_size.x, target.y / texture_size.y)
	var cut := target / scale
	return Rect2((texture_size - cut) * 0.5, cut)
