extends Node2D

const IRON := Color("#172735")
const EDGE := Color("#647f89")
const SEAM := Color("#314651")
const DARK := Color("#0b151f")
const AMBER := Color("#e6ad65")
const CYAN := Color("#76e4ff")


func _draw() -> void:
	_draw_crane(448.0)
	_draw_crane(2200.0)
	_draw_pit(1020.0, 1208.0, 520.0, 520.0)
	_draw_pit(2600.0, 2828.0, 520.0, 444.0)
	_draw_deck(-100.0, 1020.0, 520.0)
	_draw_deck(1208.0, 2600.0, 520.0)
	_draw_deck(2828.0, 4576.0, 444.0)
	_draw_warning_zone(448.0, 120.0)
	_draw_warning_zone(993.0, 27.0)
	_draw_warning_zone(2200.0, 122.0)
	_draw_warning_zone(2573.0, 27.0)
	_draw_beacon(1290.0, 520.0, 1)
	_draw_beacon(2880.0, 444.0, 2)
	_draw_furnace()


func _draw_crane(center: float) -> void:
	draw_set_transform(Vector2(center - 448.0, 0))
	draw_rect(Rect2(182, -180, 27, 700), Color("#142633"))
	draw_rect(Rect2(203, -180, 5, 700), Color("#263d4b"))
	draw_rect(Rect2(682, -180, 26, 700), Color("#142633"))
	draw_rect(Rect2(682, -180, 4, 700), Color("#36515b"))
	draw_rect(Rect2(169, 99, 558, 18), Color("#192e3c"))
	draw_line(Vector2(169, 100), Vector2(727, 100), Color("#4f6d76"), 2.0)
	draw_rect(Rect2(413, 89, 69, 31), IRON)
	draw_rect(Rect2(422, 94, 51, 6), EDGE)
	draw_rect(Rect2(433, 119, 30, 11), DARK)
	draw_circle(Vector2(426, 110), 2.5, AMBER)
	draw_circle(Vector2(469, 110), 2.5, AMBER)
	draw_set_transform(Vector2.ZERO)


func _draw_pit(left: float, right: float, start_y: float, end_y: float) -> void:
	var corners := PackedVector2Array([
		Vector2(left, start_y), Vector2(right, end_y), Vector2(right, 780), Vector2(left, 780)])
	var shades := PackedColorArray([
		Color(0.028, 0.067, 0.09, 0.08), Color(0.028, 0.067, 0.09, 0.08),
		Color("#08111a"), Color("#08111a")])
	draw_polygon(corners, shades)
	for i in 2:
		var x := left + 11.0 if i == 0 else right - 11.0
		var top := start_y if i == 0 else end_y
		draw_line(Vector2(x, top + 11.0), Vector2(x, 693), Color("#192e38"), 3.0)
		draw_rect(Rect2(x - 2.0, top + 39.0, 4, 14), Color("#f0a56c"))


func _draw_deck(left: float, right: float, height: float) -> void:
	var width := right - left
	draw_set_transform(Vector2(0.0, height - 520.0))
	draw_rect(Rect2(left, 520, width, 260), DARK)
	draw_rect(Rect2(left, 520, width, 56), IRON)
	draw_rect(Rect2(left, 522, width, 9), Color("#3c5663"))
	draw_line(Vector2(left, 520), Vector2(right, 520), EDGE, 2.0)
	draw_line(Vector2(left, 546), Vector2(right, 546), SEAM, 1.0)
	draw_line(Vector2(left, 573), Vector2(right, 573), EDGE.darkened(0.5), 2.0)
	for x in range(int(left) + 38, int(right), 108):
		draw_line(Vector2(x, 529), Vector2(x, 573), DARK, 2.0)
		draw_line(Vector2(x + 3, 532), Vector2(x + 100, 560), SEAM.darkened(0.35), 3.0)
		draw_circle(Vector2(x + 8, 535), 2.0, EDGE)
		draw_circle(Vector2(x + 8, 566), 2.0, EDGE)
	for x in range(int(left) + 80, int(right) - 35, 216):
		draw_rect(Rect2(x, 576, 22, 176), IRON)
		draw_line(Vector2(x + 22, 580), Vector2(x + 157, 675), IRON, 9.0)
		draw_line(Vector2(x + 24, 582), Vector2(x + 157, 675), SEAM, 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_warning_zone(center: float, half_width: float) -> void:
	var left := center - half_width
	var right := center + half_width
	draw_rect(Rect2(left, 522, half_width * 2.0, 12.0), Color("#39322f"))
	for x in range(int(left) + 4, int(right) - 11, 15):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 5, 523), Vector2(x + 12, 523),
			Vector2(x + 7, 533), Vector2(x, 533)]), AMBER.darkened(0.17))
	for x in [left, right]:
		draw_line(Vector2(x, 520), Vector2(x, 505), AMBER, 2.0)


func _draw_beacon(x: float, floor_y: float, number: int) -> void:
	var active: bool = get_parent().get_parent().checkpoint >= number
	var tint := CYAN if active else Color("#718e91")
	var center := Vector2(x, floor_y - 53.0)
	draw_line(center, Vector2(x, floor_y), Color("#233640"), 8.0)
	draw_rect(Rect2(center - Vector2(12, 15), Vector2(24, 31)), Color("#14232d"))
	draw_rect(Rect2(center - Vector2(8, 10), Vector2(16, 17)), Color(tint, 0.25))
	draw_line(center - Vector2(5, 2), center + Vector2(5, -2), tint, 3.0)
	draw_line(Vector2(x - 33, floor_y + 6), Vector2(x + 33, floor_y + 6), tint, 2.0)


func _draw_furnace() -> void:
	for x in range(3100, 4090, 360):
		draw_rect(Rect2(x, 151, 13, 293), Color(0.08, 0.09, 0.13, 0.54))
		draw_line(Vector2(x, 149), Vector2(x + 202, 149), EDGE.darkened(0.42), 3.0)
		draw_rect(Rect2(x + 12, 177, 4, 11), Color("#ef885b"))
	for x in range(3996, 4174, 31):
		draw_line(Vector2(x, 450), Vector2(x + 18, 450), CYAN.darkened(0.32), 2.0)
