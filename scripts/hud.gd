extends Control

const CampaignStore = preload("res://scripts/campaign.gd")
const MenuTheme = preload("res://scripts/menu_theme.gd")
const Texts = preload("res://texts.gd")
const INK := Color("#e6f0ee")
const MUTED := Color("#a7bdc6")
const DIM := Color("#5f7782")
const CYAN := Color("#72e5ff")
const AMBER := Color("#ffc27b")
const HEAT := Color("#ff9673")
const PLATE := Color(0.02, 0.05, 0.075, 0.86)
const CLEAR := Color(0.02, 0.05, 0.075, 0.0)
const EMPTY := Color("#1d313b")
const SEGMENTS := 20
const INTRO_TIME := 2.7

var display_font := MenuTheme.display_font(700)
var number_font := MenuTheme.display_font(600)
var text_font := MenuTheme.text_font()
var bold_font := MenuTheme.text_font(700)

var life := 0.0
var shown_energy := 0.0
var last_energy := -1
var gain_flash := 0.0
var spend_flash := 0.0
var spend_from := 0.0
var last_integrity := -1
var damage_flash := 0.0
var hint_state: Dictionary = {}
var complete_age := 0.0
var feedback_last_left := 0.0
var feedback_age := 0.0

@onready var level = $"../.."


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	life += delta
	var energy: int = level.sera.energy
	if last_energy < 0:
		last_energy = energy
		shown_energy = energy
	elif energy > last_energy:
		gain_flash = 1.0
	elif energy < last_energy:
		spend_from = maxf(spend_from if spend_flash > 0.0 else 0.0, shown_energy)
		spend_flash = 1.0
	last_energy = energy
	shown_energy = move_toward(shown_energy, energy, delta * maxf(60.0, absf(energy - shown_energy) * 6.0))
	gain_flash = move_toward(gain_flash, 0.0, delta * 2.6)
	spend_flash = move_toward(spend_flash, 0.0, delta * 1.8)

	var integrity: int = level.sera.integrity
	if last_integrity >= 0 and integrity < last_integrity:
		damage_flash = 1.0
	last_integrity = integrity
	damage_flash = move_toward(damage_flash, 0.0, delta * 2.2)

	_update_hints(delta)
	complete_age = complete_age + delta if level.complete else 0.0
	if level.feedback_left > feedback_last_left + 0.01:
		feedback_age = 0.0
	feedback_last_left = level.feedback_left
	feedback_age += delta
	queue_redraw()


func _draw() -> void:
	if level.flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(level.flash_tint, level.flash))
	_draw_danger()
	_draw_title()
	_draw_resources()
	if level.complete:
		_draw_summary()
	else:
		_draw_marker()
		_draw_hints()
	_draw_feedback()
	_draw_intro()


func _stage_index() -> int:
	return CampaignStore.SCENES.find(level.scene_file_path)


func _section_parts() -> PackedStringArray:
	var parts: PackedStringArray = level.hud_section().split("/")
	for i in parts.size():
		parts[i] = parts[i].strip_edges()
	return parts


func _draw_title() -> void:
	var parts := _section_parts()
	var plate := Rect2(26, 22, 318, 70)
	MenuTheme.slant_fade(self, plate, PLATE, CLEAR)
	MenuTheme.slant(self, Rect2(26, 22, 16, 70), CYAN)
	MenuTheme.slant(self, Rect2(30, 22, 12, 70), Color(0.02, 0.05, 0.075, 0.6))
	var index := _stage_index()
	var eyebrow: String = Texts.stage_number(index) if index >= 0 else Texts.HUD_STAGE_UNLISTED
	if level.play_mode == CampaignStore.Mode.PRACTICE:
		eyebrow = Texts.HUD_PRACTICE + " · " + eyebrow
	MenuTheme.spaced(self, number_font, Vector2(56, 43), eyebrow, 13, CYAN, 2.5)
	var clock: String = level.campaign.time_label(roundi(level.elapsed * 1000.0))
	draw_string(number_font, Vector2(56, 43), clock, HORIZONTAL_ALIGNMENT_RIGHT, 250, 15, MUTED)
	var x := 54.0
	draw_string(bold_font, Vector2(x, 76), parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, INK)
	if parts.size() > 1:
		x += bold_font.get_string_size(parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x + 10.0
		MenuTheme.slant(self, Rect2(x, 60, 9, 18), Color(CYAN, 0.6), 5.0)
		draw_string(text_font, Vector2(x + 16, 75), parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)


func _draw_resources() -> void:
	var energy: int = level.sera.energy
	var integrity: int = level.sera.integrity
	var x := size.x - 352.0
	var plate := Rect2(x, 22, 326, 112)
	MenuTheme.slant_fade(self, plate, CLEAR, PLATE)
	MenuTheme.slant(self, Rect2(plate.end.x - 16, 22, 16, 112), CYAN)
	MenuTheme.slant(self, Rect2(plate.end.x - 16, 22, 12, 112), Color(0.02, 0.05, 0.075, 0.6))

	var left := x + 34.0
	var right := plate.end.x - 30.0
	MenuTheme.spaced(self, number_font, Vector2(left, 44), Texts.HUD_MOMENTUM_EYEBROW, 13, CYAN, 2.5)
	draw_string(text_font, Vector2(left + 104, 44), Texts.HUD_MOMENTUM, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	var number := "%d" % roundi(shown_energy)
	var tint := CYAN.lerp(Color.WHITE, gain_flash * 0.8)
	if spend_flash > 0.0:
		tint = tint.lerp(AMBER, spend_flash * 0.6)
	var number_width := number_font.get_string_size("/100", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(number_font, Vector2(right - number_width, 58), "/100", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	draw_string_outline(display_font, Vector2(right - number_width - 120, 58), number, HORIZONTAL_ALIGNMENT_RIGHT, 116, 34, 4, Color(0, 0, 0, 0.5))
	draw_string(display_font, Vector2(right - number_width - 120, 58), number, HORIZONTAL_ALIGNMENT_RIGHT, 116, 34, tint)

	# Segmented gauge. Spent charge lingers in amber, gained charge glows white.
	var bar := Rect2(left - 6, 68, right - left + 6, 14)
	var gap := 3.0
	var cell := (bar.size.x - gap * (SEGMENTS - 1)) / SEGMENTS
	var per := float(_capacity()) / SEGMENTS
	for i in SEGMENTS:
		var r := Rect2(bar.position.x + i * (cell + gap), bar.position.y, cell, bar.size.y)
		MenuTheme.slant(self, r, EMPTY, 4.0)
		if spend_flash > 0.0:
			var ghost := clampf((spend_from - i * per) / per, 0.0, 1.0)
			if ghost > 0.0:
				MenuTheme.slant(self, Rect2(r.position, Vector2(r.size.x * ghost, r.size.y)), Color(AMBER, spend_flash * 0.85), 4.0)
		var fill := clampf((shown_energy - i * per) / per, 0.0, 1.0)
		if fill > 0.0:
			var color := CYAN.lerp(Color.WHITE, gain_flash * 0.55)
			if energy >= _capacity():
				color = color.lerp(Color.WHITE, 0.25 + sin(life * 7.0) * 0.2)
			MenuTheme.slant(self, Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), color, 4.0)
	if gain_flash > 0.0:
		var glow_width := bar.size.x * clampf(shown_energy / _capacity(), 0.0, 1.0)
		draw_rect(Rect2(bar.position - Vector2(0, 4), Vector2(glow_width, bar.size.y + 8)), Color(CYAN, 0.18 * gain_flash))

	# Cost ticks on the bar, then the abilities they unlock and the suit cells.
	for cost in [level.sera.BOOST_COST, level.sera.RELEASE_COST]:
		var px: float = bar.position.x + bar.size.x * cost / _capacity()
		var mark := CYAN if energy >= cost else DIM
		draw_colored_polygon(PackedVector2Array([Vector2(px - 4, bar.end.y + 8), Vector2(px + 4, bar.end.y + 8), Vector2(px, bar.end.y + 2)]), mark)
	var chip_y := 98.0
	var chip_x := left - 4.0
	chip_x += _ability(Vector2(chip_x, chip_y), ["Shift"], Texts.HUD_DASH, energy >= level.sera.BOOST_COST) + 14.0
	_ability(Vector2(chip_x, chip_y), ["RMB"], Texts.HUD_SHOCKWAVE, energy >= level.sera.RELEASE_COST)

	var cell_step := 25.0
	var cells_left: float = right - cell_step * level.sera.MAX_INTEGRITY + 3.0
	for index in level.sera.MAX_INTEGRITY:
		var cell_rect := Rect2(cells_left + index * cell_step, chip_y + 4.0, 22.0, 13.0)
		var alive: bool = index < integrity
		var color := Color("#f7b292") if alive else Color("#2c3a42")
		if alive and integrity == 1:
			color = color.lerp(HEAT, 0.5 + sin(life * 9.0) * 0.5)
		if not alive and index == integrity and damage_flash > 0.0:
			color = color.lerp(Color.WHITE, damage_flash)
		MenuTheme.slant(self, cell_rect, color, 5.0)


func _ability(origin: Vector2, tokens: Array, label: String, ready_now: bool) -> float:
	var alpha := 1.0 if ready_now else 0.38
	var width := MenuTheme.combo(self, origin, tokens, alpha, 12)
	draw_string(text_font, Vector2(origin.x + width + 6.0, origin.y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(CYAN if ready_now else MUTED, alpha))
	return width + 6.0 + text_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x


func _capacity() -> float:
	return float(level.sera.CAPACITY)


func _draw_danger() -> void:
	# Pulsing red edges warn when one more hit ends the run.
	var strength := damage_flash * 0.5
	if level.sera.integrity == 1 and not level.complete:
		strength = maxf(strength, 0.24 + sin(life * 4.0) * 0.1)
	if strength <= 0.0:
		return
	var edge := Color(HEAT, strength)
	var none := Color(HEAT, 0.0)
	var depth := 90.0
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - depth, depth), Vector2(depth, depth)]), PackedColorArray([edge, edge, none, none]))
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(depth, h - depth), Vector2(w - depth, h - depth), Vector2(w, h)]), PackedColorArray([edge, none, none, edge]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(depth, depth), Vector2(depth, h - depth), Vector2(0, h)]), PackedColorArray([edge, none, none, edge]))
	draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - depth, h - depth), Vector2(w - depth, depth)]), PackedColorArray([edge, edge, none, none]))


func _update_hints(delta: float) -> void:
	# Sera says one thing at a time: the first relevant line wins.
	var live := {}
	if not level.complete and not level.exiting and life > 1.1 and level.sera.integrity > 0:
		var lines: Array = level.hud_hints()
		if not lines.is_empty():
			live[lines[0]["id"]] = lines[0]
	for id in live:
		var state: Dictionary = hint_state.get(id, {"alpha": 0.0, "age": 0.0})
		state["data"] = live[id]
		state["alpha"] = move_toward(state["alpha"], 1.0, delta * 5.0)
		state["age"] += delta
		state["done"] = false
		hint_state[id] = state
	for id in hint_state.keys():
		if live.has(id):
			continue
		var state: Dictionary = hint_state[id]
		state["done"] = level.knows(id)
		state["alpha"] = move_toward(state["alpha"], 0.0, delta * (1.6 if state["done"] else 6.0))
		if state["alpha"] <= 0.0:
			hint_state.erase(id)


func _hint_points() -> Array:
	var points := []
	for state: Dictionary in hint_state.values():
		var at: Vector2 = state["data"]["at"]
		if at.is_finite():
			points.append(get_viewport().get_canvas_transform() * at)
	return points


func _speaker_point() -> Vector2:
	var head: Vector2 = get_viewport().get_canvas_transform() * (level.sera.global_position + Vector2(0.0, -132.0))
	return Vector2(clampf(head.x, 60.0, size.x - 60.0), clampf(head.y, 200.0, size.y - 30.0))


## Sera's lines appear in a speech bubble over her head; when she talks about
## something in the room, that spot gets a pulsing ring.
func _draw_hints() -> void:
	var head := _speaker_point()
	for state: Dictionary in hint_state.values():
		var data: Dictionary = state["data"]
		var alpha: float = ease(state["alpha"], -1.8)
		var done: bool = state["done"]
		var tint: Color = CYAN if done else data["tint"]
		var at: Vector2 = data["at"]
		var focus := Vector2.INF
		if at.is_finite():
			focus = get_viewport().get_canvas_transform() * at
			if not done:
				_draw_focus(focus, tint, alpha)

		var rows: Array = data["rows"]
		var width := 0.0
		var heights := []
		var keep_clear := Rect2(focus, Vector2.ZERO).grow(46.0) if focus.is_finite() else Rect2()
		for row: Array in rows:
			var tokens: Array = row[0]
			if focus.is_finite() and tokens.has("W") and tokens.has("RMB"):
				var origin: Vector2 = get_viewport().get_canvas_transform() * level.sera.release_origin(true)
				keep_clear = keep_clear.expand(origin)
			var spoken := tokens.is_empty()
			var lead := MenuTheme.combo(self, Vector2.ZERO, tokens, 1.0, 13, true) + 6.0 if not spoken else 0.0
			var font: Font = bold_font if spoken else text_font
			width = maxf(width, lead + font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16 if spoken else 14).x)
			heights.append(28.0 if spoken else 30.0)
		var body := Vector2(width + 36.0, 34.0 + _sum(heights))
		var rise := (1.0 - alpha) * (-16.0 if done else 10.0)
		var bubble := _hint_bubble(head, body, rise, keep_clear)

		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(12)
		box.bg_color = Color(0, 0, 0, 0.3 * alpha)
		draw_style_box(box, Rect2(bubble.position + Vector2(0, 5), bubble.size))
		box.bg_color = Color(0.03, 0.07, 0.095, 0.93 * alpha)
		box.border_color = Color(tint, 0.85 * alpha)
		box.set_border_width_all(2)
		draw_style_box(box, bubble)
		var tail_x := clampf(head.x, bubble.position.x + 22.0, bubble.end.x - 22.0)
		var toward := -1.0 if bubble.position.y > head.y else 1.0
		var rim := bubble.end.y if toward > 0.0 else bubble.position.y
		var tip := Vector2(clampf(head.x, tail_x - 38.0, tail_x + 38.0), rim + toward * 16.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 10, rim - toward * 2.0),
			Vector2(tail_x + 8, rim - toward * 2.0), tip]), Color(0.03, 0.07, 0.095, 0.93 * alpha))
		draw_polyline(PackedVector2Array([Vector2(tail_x - 10, rim), tip, Vector2(tail_x + 8, rim)]),
			Color(tint, 0.85 * alpha), 2.0, true)

		# Name tab
		MenuTheme.slant(self, Rect2(bubble.position + Vector2(14, -11), Vector2(54, 20)), Color(tint, alpha), 6.0)
		draw_string(bold_font, Vector2(bubble.position.x + 14, bubble.position.y + 4), Texts.HUD_SPEAKER, HORIZONTAL_ALIGNMENT_CENTER, 54, 13, Color(MenuTheme.INK, alpha))

		var y := bubble.position.y + 18.0
		for i in rows.size():
			var row: Array = rows[i]
			var tokens: Array = row[0]
			var x := bubble.position.x + 18.0
			if tokens.is_empty():
				draw_string(bold_font, Vector2(x, y + 18.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(INK, alpha))
			else:
				x += MenuTheme.combo(self, Vector2(x, y + 2.0), tokens, alpha, 13) + 6.0
				draw_string(text_font, Vector2(x, y + 19.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(tint.lerp(INK, 0.35), alpha))
			y += heights[i]
		if done:
			var badge := Vector2(bubble.end.x - 6.0, bubble.position.y + 4.0)
			draw_circle(badge, 11.0, Color(CYAN, alpha))
			draw_polyline(PackedVector2Array([badge + Vector2(-5, 0), badge + Vector2(-1, 4), badge + Vector2(5, -4)]), Color(MenuTheme.INK, alpha), 2.5, true)


func _hint_bubble(head: Vector2, body: Vector2, rise: float, keep_clear: Rect2) -> Rect2:
	var max_left := maxf(16.0, size.x - body.x - 16.0)
	var bubble := Rect2(Vector2(clampf(head.x - 46.0, 16.0, max_left), maxf(150.0, head.y - body.y - 22.0 + rise)), body)
	if not keep_clear.has_area() or not bubble.grow(10.0).intersects(keep_clear):
		return bubble
	var behind := keep_clear.position.x - body.x - 12.0
	var ahead := keep_clear.end.x + 12.0
	if behind >= 16.0 and (ahead > max_left or head.x <= keep_clear.get_center().x):
		bubble.position.x = behind
	elif ahead <= max_left:
		bubble.position.x = ahead
	else:
		var above := keep_clear.position.y - body.y - 12.0
		bubble.position.y = above if above >= 150.0 else minf(keep_clear.end.y + 12.0, size.y - body.y - 20.0)
	return bubble


func _draw_focus(point: Vector2, tint: Color, alpha: float) -> void:
	if point.x < 20.0 or point.x > size.x - 20.0 or point.y < 20.0 or point.y > size.y - 20.0:
		return
	var ring := fmod(life * 1.2, 1.0)
	draw_arc(point, 16.0 + ring * 26.0, 0.0, TAU, 36, Color(tint, 0.7 * (1.0 - ring) * alpha), 2.5, true)
	draw_arc(point, 13.0, 0.0, TAU, 28, Color(tint, 0.8 * alpha), 2.0, true)
	var bob := sin(life * 5.0) * 4.0
	var tip := point + Vector2(0.0, -24.0 + bob)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, -11), tip + Vector2(8, -11), tip]), Color(tint, alpha))


func _sum(values: Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total


func _keycap_width(key: String, action: String) -> float:
	var key_width := maxf(24.0, number_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0)
	return key_width + 8.0 + text_font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x


func _draw_feedback() -> void:
	var message: String = level.feedback
	var tint: Color = level.feedback_tint
	var opacity := clampf(level.feedback_left * 2.0, 0.0, 1.0)
	var age := feedback_age
	if level.sera.hint_left > 0.0:
		var cost: int = level.sera.RELEASE_COST if level.sera.empty_action == &"release_force" else level.sera.BOOST_COST
		message = Texts.HUD_NOT_ENOUGH.format({"숫자": cost})
		tint = AMBER
		opacity = clampf(level.sera.hint_left * 2.5, 0.0, 1.0)
		age = 1.0
	if opacity <= 0.0 or message.is_empty():
		return
	var font_size := 21
	var width := bold_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 64.0
	var top := 104.0 if get_parent().has_node("CoreStatus") else 30.0
	var center := Vector2(size.x * 0.5, top + 22.0)
	var pop := 1.0 + 0.35 * exp(-age * 14.0)
	draw_set_transform(center, 0.0, Vector2(pop, pop))
	var plate := Rect2(-width * 0.5, -22, width, 44)
	MenuTheme.slant(self, plate, Color(0.02, 0.05, 0.075, 0.88 * opacity), 14.0)
	MenuTheme.slant(self, Rect2(plate.position.x, plate.end.y - 3, width, 3), Color(tint, opacity), 1.0)
	if age < 0.35:
		MenuTheme.slant(self, plate, Color(tint, 0.35 * (1.0 - age / 0.35) * opacity), 14.0)
	draw_string_outline(bold_font, Vector2(plate.position.x, 8), message, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 4, Color(0, 0, 0, 0.45 * opacity))
	draw_string(bold_font, Vector2(plate.position.x, 8), message, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(tint.lerp(Color.WHITE, 0.25), opacity))
	draw_set_transform(Vector2.ZERO)


func _draw_marker() -> void:
	var marker: Array = level.hud_marker()
	if marker.is_empty():
		return
	var screen := get_viewport().get_canvas_transform() * (marker[0] as Vector2)
	for point: Vector2 in _hint_points():
		if point.distance_to(screen) < 170.0:
			return
	_tag(marker[0], marker[1], marker[2])


func _tag(point: Vector2, caption: String, tint: Color) -> void:
	var screen := get_viewport().get_canvas_transform() * point
	if screen.x < 75.0 or screen.x > size.x - 75.0 or screen.y < 150.0 or screen.y > size.y - 50.0:
		return
	var bob := sin(life * 5.0) * 3.0
	var width := bold_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 30.0
	var plate := Rect2(screen + Vector2(-width * 0.5, -40 + bob), Vector2(width, 26))
	MenuTheme.slant(self, plate, Color(0.02, 0.05, 0.075, 0.9), 8.0)
	MenuTheme.slant(self, Rect2(plate.position.x, plate.end.y - 2, width, 2), tint, 0.0)
	draw_string(bold_font, Vector2(plate.position.x, plate.position.y + 18), caption, HORIZONTAL_ALIGNMENT_CENTER, width, 14, tint)
	var tip := screen + Vector2(0, -2 + bob)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -9), tip + Vector2(7, -9), tip]), tint)
	var ring := fmod(life * 1.4, 1.0)
	draw_arc(screen + Vector2(0, 10), 6.0 + ring * 18.0, 0.0, TAU, 28, Color(tint, 0.6 * (1.0 - ring)), 2.0, true)


func _draw_intro() -> void:
	if life >= INTRO_TIME:
		return
	if life < 0.45:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - life / 0.45))
	var t := life / INTRO_TIME
	var alpha := clampf(minf((life - 0.15) / 0.3, (INTRO_TIME - life) / 0.5), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var index := _stage_index()
	var stage_name: String = Texts.stage_name(index) if index >= 0 else _section_parts()[0]
	var subtitle: String = _section_parts()[1] if _section_parts().size() > 1 else ""
	if index >= 0 and level.checkpoint > 0:
		subtitle = Texts.HUD_FROM_CHECKPOINT.format({"구간": Texts.section(index, level.checkpoint)})
	var cy := size.y * 0.36
	var band := Rect2(0, cy - 70, size.x, 140)
	var dark := Color(0.01, 0.025, 0.035, 0.78 * alpha)
	var half := size.x * 0.5
	for side in [-1.0, 1.0]:
		var edge: float = half + side * half
		draw_polygon(PackedVector2Array([Vector2(half, band.position.y), Vector2(edge, band.position.y), Vector2(edge, band.end.y), Vector2(half, band.end.y)]),
			PackedColorArray([dark, Color(dark, 0.0), Color(dark, 0.0), dark]))
	var line := size.x * 0.42 * ease(clampf((life - 0.1) / 0.5, 0.0, 1.0), -2.4)
	draw_rect(Rect2(half - line, band.position.y, line * 2.0, 2), Color(CYAN, 0.8 * alpha))
	draw_rect(Rect2(half - line, band.end.y - 2, line * 2.0, 2), Color(CYAN, 0.4 * alpha))

	var eyebrow: String = Texts.stage_number(index) if index >= 0 else Texts.HUD_STAGE_UNLISTED
	if level.play_mode == CampaignStore.Mode.PRACTICE:
		eyebrow = Texts.HUD_PRACTICE + "  ·  " + eyebrow
	elif index >= 0:
		eyebrow = Texts.act_label(index) + "  ·  " + eyebrow
	var spacing := 6.0 + t * 3.0
	var eyebrow_width := MenuTheme.spaced_width(number_font, eyebrow, 15, spacing)
	MenuTheme.spaced(self, number_font, Vector2(half - eyebrow_width * 0.5, cy - 32), eyebrow, 15, Color(CYAN, alpha), spacing)
	var title_size := 52
	draw_string_outline(bold_font, Vector2(0, cy + 22), stage_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, 8, Color(0, 0, 0, 0.5 * alpha))
	draw_string(bold_font, Vector2(0, cy + 22), stage_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(Color.WHITE, alpha))
	if not subtitle.is_empty():
		draw_string(text_font, Vector2(0, cy + 52), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(MUTED, alpha))


func _draw_summary() -> void:
	var t := complete_age
	var dim := ease(clampf(t / 0.45, 0.0, 1.0), -2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.015, 0.024, 0.55 * dim))
	var cy := size.y * 0.42
	var drop := 0.0 if level.clear_note.is_empty() else 18.0
	var practice: bool = level.play_mode == CampaignStore.Mode.PRACTICE
	var band := Rect2(0, cy - 120, size.x, 250 + drop + (78.0 if practice else 0.0))
	var half := size.x * 0.5
	var dark := Color(0.01, 0.03, 0.045, 0.9 * dim)
	for side in [-1.0, 1.0]:
		var edge: float = half + side * half
		draw_polygon(PackedVector2Array([Vector2(half, band.position.y), Vector2(edge, band.position.y), Vector2(edge, band.end.y), Vector2(half, band.end.y)]),
			PackedColorArray([dark, Color(dark, 0.0), Color(dark, 0.0), dark]))
	var line := size.x * 0.4 * ease(clampf((t - 0.1) / 0.5, 0.0, 1.0), -2.4)
	draw_rect(Rect2(half - line, band.position.y, line * 2.0, 2), CYAN)
	draw_rect(Rect2(half - line, band.end.y - 2, line * 2.0, 2), Color(CYAN, 0.45))

	# Headline slams in, then the stats count up one by one.
	var slam := clampf((t - 0.15) / 0.28, 0.0, 1.0)
	if slam > 0.0:
		var zoom := lerpf(1.6, 1.0, ease(slam, -2.6))
		var head_alpha := slam
		var headline: String = Texts.CLEAR_HEADLINE
		var head_size := 58
		var head_width := MenuTheme.spaced_width(display_font, headline, head_size, 8.0)
		draw_set_transform(Vector2(half, cy - 52), 0.0, Vector2(zoom, zoom))
		for spread in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
			MenuTheme.spaced(self, display_font, Vector2(-head_width * 0.5, 0) + spread, headline, head_size, Color(CYAN, 0.18 * head_alpha), 8.0)
		MenuTheme.spaced(self, display_font, Vector2(-head_width * 0.5, 0), headline, head_size, Color(Color.WHITE, head_alpha), 8.0)
		draw_set_transform(Vector2.ZERO)
		if slam < 1.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12 * (1.0 - slam)))
		draw_string(bold_font, Vector2(0, cy - 14), level.clear_title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(CYAN, head_alpha))
		if not level.clear_note.is_empty():
			draw_string(text_font, Vector2(0, cy + 10), level.clear_note, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(MUTED, head_alpha))

	var seconds_ms := roundi(level.elapsed * 1000.0)
	var stats := [
		[Texts.CLEAR_TIME, level.campaign.time_label(seconds_ms)],
		[Texts.CLEAR_PERFECT, "%d" % level.perfect_shots],
		[Texts.CLEAR_RETRIES, "%d" % level.retries],
	]
	var column := 190.0
	var start := half - column * (stats.size() - 1) * 0.5
	for i in stats.size():
		var reveal := clampf((t - 0.55 - i * 0.14) / 0.25, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var x := start + column * i
		var rise := (1.0 - ease(reveal, -2.0)) * 14.0
		draw_string(text_font, Vector2(x - 90, cy + 32 + drop + rise), stats[i][0], HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(MUTED, reveal))
		draw_string(display_font, Vector2(x - 90, cy + 72 + drop + rise), stats[i][1], HORIZONTAL_ALIGNMENT_CENTER, 180, 36, Color(Color.WHITE, reveal))
		if i > 0:
			draw_line(Vector2(x - column * 0.5, cy + 22 + drop), Vector2(x - column * 0.5, cy + 76 + drop), Color(MenuTheme.EDGE, reveal))

	if level.new_record and t > 1.05:
		var badge_alpha := clampf((t - 1.05) / 0.2, 0.0, 1.0)
		var pulse := 1.0 + 0.04 * sin(t * 6.0)
		var badge: String = Texts.CLEAR_NEW_RECORD
		var badge_width := bold_font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 40.0
		draw_set_transform(Vector2(start, cy + 2), -0.08, Vector2(pulse, pulse))
		MenuTheme.slant(self, Rect2(-badge_width * 0.5, -14, badge_width, 26), Color(AMBER, badge_alpha), 8.0)
		draw_string(bold_font, Vector2(-badge_width * 0.5, 5), badge, HORIZONTAL_ALIGNMENT_CENTER, badge_width, 15, Color(MenuTheme.INK, badge_alpha))
		draw_set_transform(Vector2.ZERO)

	if practice:
		var splits_alpha := clampf((t - 0.93) / 0.3, 0.0, 1.0)
		_draw_practice_splits(cy + 97.0 + drop, start, column, splits_alpha)

	var keys_alpha := clampf((t - 1.0) / 0.3, 0.0, 1.0)
	if keys_alpha > 0.0:
		var action: String = level.result_action_label()
		var retry_width := _keycap_width("R", Texts.CLEAR_REPLAY)
		var next_width := _keycap_width("Enter", action) if not action.is_empty() else 0.0
		var total := retry_width + (next_width + 34.0 if next_width > 0.0 else 0.0)
		var x := half - total * 0.5
		var y := band.end.y - 40.0
		if next_width > 0.0:
			MenuTheme.keycap(self, Vector2(x, y), "Enter", action, keys_alpha)
			x += next_width + 34.0
		MenuTheme.keycap(self, Vector2(x, y), "R", Texts.CLEAR_REPLAY, keys_alpha)


func _draw_practice_splits(y: float, start: float, column: float, opacity: float) -> void:
	var splits: Array[int] = level.practice_splits_ms
	var best_splits: Array[int] = level.practice_previous_ms
	for i in splits.size():
		var time := CampaignStore.practice_segment_ms(splits, i)
		var previous := CampaignStore.practice_segment_ms(best_splits, i)
		var label := Texts.CLEAR_PRACTICE_SEGMENT.format({"번호": i + 1})
		var mark := "--:--.-"
		var tint := INK
		if time >= 0:
			mark = level.campaign.time_label(time)
			if previous >= 0:
				mark = Texts.CLEAR_PRACTICE_SPLIT.format({"기록": mark, "차이": CampaignStore.practice_delta_label(time - previous)})
				tint = CYAN if time < previous else (AMBER if time > previous else INK)
		var x := start + column * i - 90.0
		draw_string(text_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(MUTED, opacity))
		draw_string(bold_font, Vector2(x, y + 22.0), mark, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color(tint, opacity))
	var last := best_splits[-1]
	if last > 0:
		var label := Texts.CLEAR_PRACTICE_PREVIOUS.format({"기록": level.campaign.time_label(last)})
		draw_string(text_font, Vector2(0, y + 43.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(MUTED, opacity))
