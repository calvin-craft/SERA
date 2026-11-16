extends Node2D

## Floor art for a sector stage. It draws every deck the stage found under
## Walkways, the pits between them, checkpoint beacons, aim pads, relay cables
## and the exit apron, so moving a collision shape in the editor moves its art.

@export var iron := Color("#172735")
@export var edge := Color("#647f89")
@export var seam := Color("#314651")
@export var dark := Color("#0b151f")
@export var accent := Color("#e6ad65")
@export var live := Color("#76e4ff")

@onready var level = $"../.."


func _draw() -> void:
	var decks: Array[Rect2] = level.decks.duplicate()
	decks.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	for i in decks.size() - 1:
		var gap := decks[i + 1].position.x - decks[i].end.x
		if gap > 30.0 and gap < 760.0 and absf(decks[i + 1].position.y - decks[i].position.y) < 140.0:
			_draw_pit(decks[i].end.x, decks[i + 1].position.x, decks[i].position.y, decks[i + 1].position.y)
	for link: Array in level.power_links:
		_draw_cable(link[0], link[1])
	for deck in decks:
		_draw_deck(deck)
	for pad: Vector2 in level.aim_pads:
		_draw_aim_pad(pad)
	for index in range(1, level.spawns.size()):
		_draw_beacon(level.spawns[index], level.checkpoint >= index)
	if level.exit_point.is_finite():
		var exit: Vector2 = level.exit_point
		for x in range(int(exit.x) + 70, int(exit.x) + 190, 31):
			draw_line(Vector2(x, exit.y + 6.0), Vector2(x + 18, exit.y + 6.0), live.darkened(0.32), 2.0)


func _draw_pit(left: float, right: float, start_y: float, end_y: float) -> void:
	var deep := maxf(start_y, end_y) + 300.0
	draw_polygon(PackedVector2Array([Vector2(left, start_y), Vector2(right, end_y), Vector2(right, deep), Vector2(left, deep)]),
		PackedColorArray([Color(dark, 0.08), Color(dark, 0.08), dark.darkened(0.2), dark.darkened(0.2)]))
	for i in 2:
		var x := left + 11.0 if i == 0 else right - 11.0
		var top := start_y if i == 0 else end_y
		draw_line(Vector2(x, top + 11.0), Vector2(x, top + 173.0), iron.lightened(0.04), 3.0)
		draw_rect(Rect2(x - 2.0, top + 39.0, 4, 14), accent)


func _draw_deck(deck: Rect2) -> void:
	var left := deck.position.x
	var right := deck.end.x
	var y := deck.position.y
	var width := right - left
	draw_rect(Rect2(left, y, width, 260), dark)
	draw_rect(Rect2(left, y, width, 56), iron)
	draw_rect(Rect2(left, y + 2, width, 9), iron.lightened(0.16))
	draw_line(Vector2(left, y), Vector2(right, y), edge, 2.0)
	draw_line(Vector2(left, y + 26), Vector2(right, y + 26), seam, 1.0)
	draw_line(Vector2(left, y + 53), Vector2(right, y + 53), edge.darkened(0.5), 2.0)
	for x in range(int(left) + 38, int(right) - 8, 108):
		draw_line(Vector2(x, y + 9), Vector2(x, y + 53), dark, 2.0)
		draw_line(Vector2(x + 3, y + 12), Vector2(minf(x + 100, right), y + 40), seam.darkened(0.35), 3.0)
		draw_circle(Vector2(x + 8, y + 15), 2.0, edge)
		draw_circle(Vector2(x + 8, y + 46), 2.0, edge)
	for x in range(int(left) + 80, int(right) - 35, 216):
		draw_rect(Rect2(x, y + 56, 22, 176), iron)
		draw_line(Vector2(x + 22, y + 60), Vector2(minf(x + 157, right), y + 155), iron, 9.0)
		draw_line(Vector2(x + 24, y + 62), Vector2(minf(x + 157, right), y + 155), seam, 1.0)


func _draw_aim_pad(pad: Vector2) -> void:
	draw_rect(Rect2(pad.x - 49.0, pad.y + 5.0, 98, 11), dark.lightened(0.05))
	draw_line(Vector2(pad.x - 48, pad.y + 5.0), Vector2(pad.x + 48, pad.y + 5.0), accent, 2.6, true)
	for x in [pad.x - 48.0, pad.x + 48.0]:
		draw_line(Vector2(x, pad.y - 17.0), Vector2(x, pad.y + 1.0), Color(accent, 0.75), 2.0, true)
	# A small chevron pointing up and to the right, the way the shot goes.
	draw_polyline(PackedVector2Array([Vector2(pad.x - 8, pad.y - 24), Vector2(pad.x + 8, pad.y - 40), Vector2(pad.x - 3, pad.y - 40)]), Color(accent, 0.8), 2.0, true)
	draw_line(Vector2(pad.x + 8, pad.y - 40), Vector2(pad.x + 8, pad.y - 29), Color(accent, 0.8), 2.0, true)


func _draw_beacon(point: Vector2, active: bool) -> void:
	var tint := live if active else edge.darkened(0.1)
	var top := point + Vector2(0.0, -52.0)
	draw_line(top, point + Vector2(0.0, 1.0), iron.lightened(0.06), 8.0)
	draw_rect(Rect2(top - Vector2(12, 15), Vector2(24, 31)), dark.lightened(0.04))
	draw_rect(Rect2(top - Vector2(8, 10), Vector2(16, 17)), Color(tint, 0.25))
	draw_line(top - Vector2(5, 2), top + Vector2(5, -2), tint, 3.0)
	draw_line(Vector2(point.x - 33, point.y + 7), Vector2(point.x + 33, point.y + 7), tint, 2.0)


## A cable from a relay to whatever it powers, lit while the power is on.
func _draw_cable(relay: Node2D, target: Node2D) -> void:
	var start := relay.position
	var anchor: Vector2 = target.get("home") if target.get("home") != null else target.position
	var cable := PackedVector2Array([start, Vector2(anchor.x, start.y), Vector2(anchor.x, maxf(start.y, anchor.y - 300.0))])
	draw_polyline(cable, dark.lightened(0.05), 9.0, true)
	draw_polyline(cable, Color("#538a7c") if relay.powered else Color("#31454a"), 3.0, true)
