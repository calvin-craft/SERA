extends Node2D

## 화물 통 걸이. Lashed barrels at one stretch of deck. Each time the ship
## leans, the rack lets one go from the uphill end and it rolls the length of
## the lane, faster the steeper the lean, and bursts on the low end's post. Blue
## barrels can be braced and caught like a ram (a charge for the suit); red
## ones are too heavy and have to be jumped. A shockwave smashes either.
## The node marks the left end of the lane, on the deck surface.

signal caught(origin: Vector2, charge: int, precise: bool)
signal smashed(origin: Vector2, hit_player: bool)

const Sera = preload("res://scripts/sera.gd")
const RADIUS := 26.0
const GAIN := 64
const PRECISE_GAIN := 90
const BLUE := Color("#3f6f86")
const RED := Color("#a8432f")
const BAND := Color("#c7d3d6")
const DARK := Color("#101a1f")

## How far right the lane runs from the node.
@export var length := 700.0
## One letter per lean: B blue, R red, - none. Repeats.
@export var pattern := "B"

var target: Sera
## The ship it rides on; set by the stage.
var sway: Node
var barrels: Array[Dictionary] = []
var count := 0
var clock := 0.0


func restart() -> void:
	barrels.clear()
	count = 0
	queue_redraw()


## Called when the ship starts a lean toward `side`.
func let_go(side: float) -> void:
	if pattern.is_empty():
		return
	var kind := pattern[count % pattern.length()]
	count += 1
	if kind == "-":
		return
	var start := RADIUS if side > 0.0 else length - RADIUS
	barrels.append({"x": start, "side": side, "speed": 40.0, "spin": 0.0, "red": kind == "R", "fall": 0.0, "drop": 0.0})


## True when a barrel is near the low end of the deck Sera is standing on.
func has_barrel_near(point: Vector2, distance: float) -> bool:
	for barrel in barrels:
		if barrel["fall"] == 0.0 and absf(barrel_point(barrel).x - point.x) < distance and absf(global_position.y - point.y) < 40.0:
			return true
	return false


func barrel_point(barrel: Dictionary) -> Vector2:
	return global_position + Vector2(barrel["x"], -RADIUS + barrel["drop"])


func next_is_red() -> bool:
	return not pattern.is_empty() and pattern[count % pattern.length()] == "R"


func smash(barrel: Dictionary, hit_player: bool = false) -> void:
	barrels.erase(barrel)
	smashed.emit(barrel_point(barrel), hit_player)
	queue_redraw()


func _physics_process(delta: float) -> void:
	clock += delta
	var lean: float = sway.lean if is_instance_valid(sway) else 0.0
	for barrel in barrels.duplicate():
		var side: float = barrel["side"]
		if barrel["fall"] > 0.0:
			barrel["fall"] += delta
			barrel["drop"] += 900.0 * barrel["fall"] * delta
			barrel["x"] += side * barrel["speed"] * delta
			if barrel["fall"] > 1.0:
				barrels.erase(barrel)
			continue
		# Downhill along the lean; on a level deck it keeps rolling, slowing a little.
		var pull := absf(lean) if signf(lean) == side else 0.0
		barrel["speed"] = minf(barrel["speed"] + (420.0 * pull - 30.0) * delta, 360.0) if pull > 0.0 else maxf(120.0, barrel["speed"] - 40.0 * delta)
		barrel["x"] += side * barrel["speed"] * delta
		barrel["spin"] += side * barrel["speed"] * delta / RADIUS
		if barrel["x"] < RADIUS * 0.5 or barrel["x"] > length - RADIUS * 0.5:
			# The low end's lashing post stops it: it bursts there.
			smash(barrel)
			continue
		_meet_player(barrel)
	queue_redraw()


func _meet_player(barrel: Dictionary) -> void:
	if not is_instance_valid(target) or target.integrity <= 0:
		return
	var feet := target.global_position
	var point := barrel_point(barrel)
	if feet.y < global_position.y - RADIUS * 2.0 + 4.0 or feet.y > global_position.y + 30.0:
		return
	var side: float = barrel["side"]
	var gap := point.x - feet.x
	if absf(gap) > 70.0:
		return
	var facing_it := target.facing == -side and signf(gap) == target.facing
	if not barrel["red"] and facing_it and target.can_absorb() and absf(gap) < 36.0 + RADIUS:
		var precise := target.absorb_age <= Sera.PERFECT_WINDOW
		var charge := mini(PRECISE_GAIN if precise else GAIN, Sera.CAPACITY - target.energy)
		target.absorb(charge, false)
		barrels.erase(barrel)
		caught.emit(point, charge, precise)
		return
	if absf(gap) < RADIUS + 14.0 and target.take_hit(side):
		smash(barrel, true)


func _draw() -> void:
	# The lashing posts at both ends of the lane.
	for x in [0.0, length]:
		draw_rect(Rect2(x - 5.0, -46.0, 10.0, 46.0), DARK.lightened(0.12))
		draw_circle(Vector2(x, -46.0), 6.0, BAND.darkened(0.4))
	var warn: bool = is_instance_valid(sway) and sway.warning()
	if warn and int(clock * 10.0) % 2 == 0:
		var end := 0.0 if sway.coming_side() > 0.0 else length
		draw_circle(Vector2(end, -60.0), 7.0, Color(RED if next_is_red() else Color("#7ce9ff"), 0.9))
	for barrel in barrels:
		var center := Vector2(barrel["x"], -RADIUS + barrel["drop"])
		var tint := RED if barrel["red"] else BLUE
		draw_circle(center, RADIUS, tint)
		draw_arc(center, RADIUS, 0.0, TAU, 32, DARK, 3.0, true)
		draw_arc(center, RADIUS - 8.0, 0.0, TAU, 28, Color(BAND, 0.6), 2.0, true)
		for spoke in 3:
			var angle: float = barrel["spin"] + TAU * spoke / 3.0
			draw_line(center, center + Vector2.from_angle(angle) * (RADIUS - 4.0), Color(BAND, 0.7), 3.0, true)
		draw_circle(center, 5.0, BAND)
