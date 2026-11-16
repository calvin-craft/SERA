extends Node2D

const Tower = preload("res://scripts/cooling_tower.gd")
const DARK := Color("#10212a")
const STEEL := Color("#263d45")
const EDGE := Color("#769499")
const LIVE := Color("#77e7d2")
const STANDBY := Color("#f4be7a")

@onready var level: Tower = $"../.."


func _draw() -> void:
	_draw_shaft()
	_draw_circuit(level.lift_relay.position, Vector2(917, 606), 830.0, level.lift_relay.powered)
	_draw_circuit(level.shield_relay.position, Vector2(2622, 532), 2588.0, not level.shield_relay.powered)
	_draw_deck(-80.0, 840.0, 1010.0)
	_draw_deck(1000.0, 1695.0, 687.0)
	_draw_deck(1940.0, 3300.0, 600.0)
	_draw_marker_pad(Tower.LIFT_AIM_X, 1010.0, STANDBY)
	_draw_marker_pad(Tower.SHIELD_AIM_X, 600.0, STANDBY)
	_draw_marker_pad(1663.0, 687.0, LIVE)
	_draw_beacon(Tower.UPPER_CHECKPOINT, level.checkpoint >= 1)
	_draw_beacon(Tower.ARENA_CHECKPOINT, level.checkpoint >= 2)
	_draw_exit_marks()


func _draw_shaft() -> void:
	var rails := PackedVector2Array([Vector2(812, 450), Vector2(1020, 450), Vector2(1020, 1280), Vector2(812, 1280)])
	draw_colored_polygon(rails, Color(0.04, 0.10, 0.15, 0.34))
	for x in [816.0, 1007.0]:
		draw_rect(Rect2(x - 4, 454, 12, 763), Color("#1d333e"))
		draw_line(Vector2(x + 1, 453), Vector2(x + 1, 1209), EDGE.darkened(0.32), 3.0)
		for y in range(520, 1217, 106):
			draw_rect(Rect2(x - 4, y, 13, 21), Color("#344c56"))
	draw_rect(Rect2(804, 452, 225, 17), DARK)
	draw_line(Vector2(804, 453), Vector2(1029, 453), EDGE, 2.0, true)
	for y in range(516, 1220, 112):
		draw_line(Vector2(831, y), Vector2(1006, y + 47), Color(0.063, 0.126, 0.15, 0.46), 6.0, true)
	var chasm := PackedVector2Array([Vector2(1695, 687), Vector2(1940, 600), Vector2(1940, 1120), Vector2(1695, 1120)])
	draw_polygon(chasm, PackedColorArray([Color(0.09, 0.15, 0.2, 0.09), Color(0.09, 0.15, 0.2, 0.09),
		Color("#101f2d"), Color("#101f2d")]))


func _draw_circuit(start: Vector2, finish: Vector2, corner: float, active: bool) -> void:
	var cable := PackedVector2Array([start, Vector2(corner, start.y), Vector2(corner, finish.y), finish])
	draw_polyline(cable, Color("#13272d"), 9.0, true)
	draw_polyline(cable, Color("#538a7c") if active else Color("#31454a"), 3.0, true)
	draw_rect(Rect2(finish - Vector2(14, 9), Vector2(28, 18)), DARK)
	draw_rect(Rect2(finish - Vector2(10, 4), Vector2(20, 7)), LIVE if active else Color("#476270"))


func _draw_deck(left: float, right: float, y: float) -> void:
	draw_rect(Rect2(left, y, right - left, 125.0), DARK)
	draw_rect(Rect2(left, y, right - left, 40.0), STEEL)
	draw_line(Vector2(left, y + 1.0), Vector2(right, y + 1.0), EDGE, 2.0)
	draw_line(Vector2(left, y + 33.0), Vector2(right, y + 33.0), EDGE.darkened(0.50), 2.0)
	for x in range(int(left) + 32, int(right) - 12, 92):
		draw_rect(Rect2(x, y + 6.0, 2, 25), DARK)
		draw_circle(Vector2(x + 6, y + 11), 1.8, EDGE)
		draw_circle(Vector2(x + 6, y + 27), 1.8, EDGE)
	for x in range(int(left) + 15, int(right) - 30, 168):
		draw_rect(Rect2(x, y + 40.0, 15, 115), STEEL)
		draw_line(Vector2(x + 15, y + 42), Vector2(minf(x + 145, right), y + 123), STEEL, 7.0, true)


func _draw_marker_pad(x: float, floor_y: float, tint: Color) -> void:
	draw_rect(Rect2(x - 49.0, floor_y + 5.0, 98, 11), Color("#14272d"))
	draw_line(Vector2(x - 48, floor_y + 5.0), Vector2(x + 48, floor_y + 5.0), tint, 2.6, true)
	draw_line(Vector2(x - 48, floor_y - 17.0), Vector2(x - 48, floor_y + 1.0), Color(tint, 0.75), 2.0, true)
	draw_line(Vector2(x + 48, floor_y - 17.0), Vector2(x + 48, floor_y + 1.0), Color(tint, 0.75), 2.0, true)


func _draw_beacon(point: Vector2, active: bool) -> void:
	var tint := LIVE if active else Color("#617b82")
	var top := point - Vector2(0.0, 49.0)
	draw_line(top, point, STEEL, 8.0)
	draw_rect(Rect2(top - Vector2(12.0, 14.0), Vector2(24, 27)), DARK)
	draw_rect(Rect2(top - Vector2(8.0, 9.0), Vector2(16, 15)), Color(tint, 0.28))
	draw_line(top - Vector2(6.0, 0.0), top + Vector2(6.0, 0.0), tint, 2.0)


func _draw_exit_marks() -> void:
	for x in range(3110, 3248, 32):
		draw_line(Vector2(x, 607), Vector2(x + 19, 607), LIVE.darkened(0.3), 2.0, true)
