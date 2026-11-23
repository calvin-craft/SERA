extends Button

## A game-style menu entry: a slanted plate that lights up and slides when focused.
## The Button text stays set for accessibility and tests; drawing is custom.

const MenuTheme = preload("res://scripts/menu_theme.gd")

@export var index_label := ""
@export var caption := ""
@export var font_size := 25
@export var compact := false
## Half lit even without focus: the tab of the chapter being looked at.
var selected := false:
	set(value):
		selected = value
		queue_redraw()

## 0 → hidden, 1 → in place. Driven by the owning menu's intro tween.
var reveal := 1.0:
	set(value):
		reveal = value
		queue_redraw()

var _glow := 0.0
var _pulse := 0.0
var _clock := 0.0


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	for box in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	for color in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
			&"font_disabled_color", &"font_hover_pressed_color"]:
		add_theme_color_override(color, Color.TRANSPARENT)
	pressed.connect(func(): _pulse = 1.0)


func _process(delta: float) -> void:
	var lit := not disabled and (has_focus() or is_hovered())
	var goal := 1.0 if lit else 0.0
	var before := _glow
	_glow = move_toward(_glow, goal, delta * 6.5)
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	_clock += delta
	if _glow != before or _pulse > 0.0 or _glow > 0.0:
		queue_redraw()


func _draw() -> void:
	if reveal <= 0.0:
		return
	var eased := ease(maxf(_glow, 0.4 if selected else 0.0), -2.0)
	var alpha := reveal * (0.42 if disabled else 1.0)
	var slide := (1.0 - reveal) * -46.0
	draw_set_transform(Vector2(slide, 0.0))
	var body := Rect2(Vector2.ZERO, size)

	# Base plate, then the light that sweeps in from the left when focused.
	MenuTheme.slant_fade(self, body, Color(0.02, 0.05, 0.07, 0.62 * alpha), Color(0.02, 0.05, 0.07, 0.10 * alpha))
	if eased > 0.0:
		var lit := Rect2(body.position, Vector2(lerpf(size.x * 0.25, size.x, eased), size.y))
		MenuTheme.slant_fade(self, lit, Color(MenuTheme.ACCENT, 0.34 * eased * alpha), Color(MenuTheme.ACCENT, 0.0))
		MenuTheme.slant(self, Rect2(0, size.y - 2.0, lerpf(0.0, size.x * 0.82, eased), 2.0), Color(MenuTheme.ACCENT, 0.7 * eased * alpha), 0.0)
	if _pulse > 0.0:
		MenuTheme.slant(self, body, Color(1, 1, 1, 0.28 * _pulse * alpha))
	var bar := Color(MenuTheme.ACCENT if eased > 0.0 else MenuTheme.DIM, lerpf(0.55, 1.0, eased) * alpha)
	MenuTheme.slant(self, Rect2(0, 0, 18.0, size.y), bar, MenuTheme.SKEW)
	MenuTheme.slant(self, Rect2(4, 0, 14.0, size.y), Color(MenuTheme.INK, 0.55 * alpha), MenuTheme.SKEW)

	var baseline := size.y * 0.5 + font_size * 0.36
	var x := 30.0 + eased * 12.0
	if not index_label.is_empty():
		var number := MenuTheme.display_font(600)
		var tint := MenuTheme.ACCENT.lerp(Color.WHITE, eased * 0.3) if eased > 0.0 else MenuTheme.DIM
		draw_string(number, Vector2(x, baseline - 1.0), index_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(tint, alpha))
		x += 36.0
	var title_tint := MenuTheme.MUTED.lerp(Color.WHITE, eased)
	draw_string(MenuTheme.text_font(700 if eased > 0.5 else 500), Vector2(x, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(title_tint, alpha))

	if not caption.is_empty():
		var small := 13 if compact else 14
		draw_string(MenuTheme.text_font(), Vector2(0, baseline - 1.0), caption, HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 46.0, small, Color(MenuTheme.ACCENT if eased > 0.0 else MenuTheme.MUTED, (0.62 + 0.38 * eased) * alpha))
	if eased > 0.0:
		var bob := sin(_clock * 6.0) * 3.0
		var tip := Vector2(size.x - 22.0 + bob, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -7), tip, tip + Vector2(-7, 7)]), Color(MenuTheme.ACCENT, eased * alpha))
	draw_set_transform(Vector2.ZERO)
