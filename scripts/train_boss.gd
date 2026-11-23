extends Node2D

## 장갑 열차. An armoured locomotive parked across the line, its nose to the
## left. It fires bolts at chest height from the nose, sweeps along the floor,
## and lobs heavy shells from its turret that pass over a standing Sera. Catch a
## heavy shell in the air and the blast shutter over its nose core opens for a
## few seconds: walk in and answer with a shockwave. In the second phase it
## creeps forward between hits; in the last it pairs a low bolt with a shell.
## The node sits at the world origin; everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal heavy_fired(origin: Vector2)

enum State { IDLE, WINDUP, OPEN, RECOVER, DOWN }

const Texts = preload("res://texts.gd")
const HITS := 3
const OPEN_TIME := 3.2
const CORE_WIDTH := 46.0
const FLOOR_Y := 520.0
const HOME_X := 900.0
const PUSH_X := 700.0
const DORMANT_X := 1010.0
const ROOF_Y := 296.0
const LOW_Y := 435.0
const HIGH_Y := 380.0
## What each phase does in a loop, by remaining health.
const PLANS := {3: ["bolt", "heavy"], 2: ["sweep", "bolt", "heavy"], 1: ["pair", "sweep", "heavy"]}
const ICE := Color("#84ebff")
const HEAT := Color("#ff7251")
const AMBER := Color("#ffc186")
const STEEL := Color("#29353b")
const PLATE := Color("#56656b")
const BLACK := Color("#0f181d")

var player: Node2D
var health := HITS
var state := State.IDLE
var left := 1.0
var duration := 1.0
var attack := ""
var step := 0
var dormant := false
var front_x := DORMANT_X
var flash := 0.0
var clock := 0.0
## The heavy shell that follows a low bolt in the last phase.
var pair_left := 0.0
var hull: AnimatableBody2D


func _ready() -> void:
	hull = AnimatableBody2D.new()
	hull.collision_layer = 1
	hull.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(520.0, FLOOR_Y - ROOF_Y)
	shape.shape = box
	shape.position = Vector2(260.0, (FLOOR_Y - ROOF_Y) * 0.5)
	hull.add_child(shape)
	add_child(hull)
	hull.position = Vector2(front_x, ROOF_Y)


func reset_attempt() -> void:
	state = State.IDLE
	left = 1.3
	step = 0
	pair_left = 0.0
	flash = 0.0
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	step = 0
	state = State.IDLE
	left = 1.4
	return true


func is_open() -> bool:
	return state == State.OPEN


func open_ratio() -> float:
	return left / OPEN_TIME if is_open() else 0.0


func status_text() -> String:
	if state == State.DOWN:
		return Texts.TRAIN_STATUS_STOPPED
	return Texts.TRAIN_STATUS_OPEN if is_open() else Texts.TRAIN_STATUS_SHUT


func core_point() -> Vector2:
	return Vector2(front_x - 4.0, LOW_Y)


func turret_point() -> Vector2:
	return Vector2(front_x + 30.0, HIGH_Y)


## True while a heavy shell is being readied.
func heavy_coming() -> bool:
	return (state == State.WINDUP and (attack == "heavy" or attack == "pair")) or pair_left > 0.0


func open_core() -> void:
	if state == State.DOWN or dormant:
		return
	pair_left = 0.0
	_enter(State.OPEN, OPEN_TIME)


func hit_core() -> bool:
	if not is_open():
		flash = 0.3
		return false
	health -= 1
	step = 0
	pair_left = 0.0
	if health == 0:
		_enter(State.DOWN, 0.0)
	else:
		_enter(State.RECOVER, 1.5)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	_roll(delta)
	if dormant or state == State.DOWN:
		queue_redraw()
		return
	if pair_left > 0.0:
		pair_left -= delta
		if pair_left <= 0.0:
			heavy_fired.emit(turret_point() + Vector2(-46.0, 0.0))
	left = maxf(0.0, left - delta)
	if left == 0.0:
		_advance()
	queue_redraw()


## The hull rolls to where the phase wants it; it creeps in while closed and
## backs off after a hit.
func _roll(delta: float) -> void:
	var goal := HOME_X
	var pace := 260.0
	if dormant:
		goal = DORMANT_X
	elif health < HITS and (state == State.IDLE or state == State.WINDUP):
		goal = PUSH_X
		pace = 24.0 if health == 2 else 34.0
	elif state == State.RECOVER:
		goal = HOME_X
		pace = 320.0
	front_x = move_toward(front_x, goal, pace * delta)
	hull.position = Vector2(front_x, ROOF_Y)


func _advance() -> void:
	match state:
		State.IDLE:
			var plan: Array = PLANS[health]
			attack = plan[step % plan.size()]
			step += 1
			var windup := 0.62
			if attack == "heavy":
				windup = 0.95 if health == 3 else 0.82
			elif attack == "sweep":
				windup = 0.8
			_enter(State.WINDUP, windup)
			attack_prepared.emit(attack == "sweep")
		State.WINDUP:
			_fire()
			_enter(State.IDLE, 1.25 if health == 3 else (1.05 if health == 2 else 0.9))
		State.OPEN, State.RECOVER:
			_enter(State.IDLE, 0.9)


func _fire() -> void:
	match attack:
		"bolt":
			attack_fired.emit(core_point() + Vector2(-34.0, 0.0), -1.0, false)
		"pair":
			attack_fired.emit(core_point() + Vector2(-34.0, 0.0), -1.0, false)
			pair_left = 0.42
		"sweep":
			attack_fired.emit(Vector2(front_x - 34.0, FLOOR_Y - 10.0), -1.0, true)
		"heavy":
			heavy_fired.emit(turret_point() + Vector2(-46.0, 0.0))


func _enter(next_state: State, time: float) -> void:
	state = next_state
	left = time
	duration = time


func _draw() -> void:
	var x := front_x
	var dead := state == State.DOWN
	# Rails under it.
	draw_line(Vector2(x - 40.0, FLOOR_Y - 2.0), Vector2(1260.0, FLOOR_Y - 2.0), Color("#3c4a50"), 3.0)
	# Hull: a sloped armoured nose, the boiler body and the cab behind it.
	var hull_tint := STEEL.darkened(0.25) if dead else STEEL
	draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_Y - 26.0), Vector2(x + 22.0, ROOF_Y + 40.0), Vector2(x + 90.0, ROOF_Y),
		Vector2(x + 560.0, ROOF_Y), Vector2(x + 560.0, FLOOR_Y - 26.0)]), hull_tint)
	draw_polyline(PackedVector2Array([Vector2(x + 22.0, ROOF_Y + 40.0), Vector2(x + 90.0, ROOF_Y), Vector2(x + 560.0, ROOF_Y)]), PLATE, 3.0, true)
	for rib in range(int(x) + 130, int(x) + 560, 56):
		draw_line(Vector2(rib, ROOF_Y + 8.0), Vector2(rib, FLOOR_Y - 32.0), BLACK, 3.0)
	draw_rect(Rect2(x + 230.0, ROOF_Y - 70.0, 120.0, 70.0), hull_tint)
	draw_rect(Rect2(x + 246.0, ROOF_Y - 58.0, 46.0, 24.0), Color("#9fe9f2", 0.2 if dead else 0.45))
	# Wheels and the cow-catcher.
	for wheel in [x + 70.0, x + 150.0, x + 230.0, x + 380.0, x + 460.0]:
		draw_circle(Vector2(wheel, FLOOR_Y - 18.0), 18.0, BLACK)
		draw_arc(Vector2(wheel, FLOOR_Y - 18.0), 18.0, 0.0, TAU, 22, PLATE, 2.0, true)
		var spoke := Vector2.from_angle(-front_x * 0.06) * 13.0
		draw_line(Vector2(wheel, FLOOR_Y - 18.0) - spoke, Vector2(wheel, FLOOR_Y - 18.0) + spoke, PLATE, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 18.0, FLOOR_Y - 2.0), Vector2(x + 10.0, FLOOR_Y - 34.0), Vector2(x + 40.0, FLOOR_Y - 34.0),
		Vector2(x + 30.0, FLOOR_Y - 2.0)]), BLACK)
	_draw_turret(dead)
	_draw_core(dead)
	_draw_warning()


func _draw_turret(dead: bool) -> void:
	var at := turret_point()
	var charging := heavy_coming() and state == State.WINDUP
	draw_circle(at + Vector2(22.0, 8.0), 34.0, STEEL.darkened(0.2) if dead else STEEL)
	draw_arc(at + Vector2(22.0, 8.0), 34.0, PI, TAU, 28, PLATE, 2.0, true)
	draw_rect(Rect2(at.x - 46.0, at.y - 7.0, 60.0, 14.0), BLACK)
	if charging:
		var charge := 1.0 - left / duration
		draw_circle(at + Vector2(-46.0, 0.0), 8.0 + 12.0 * charge, Color(ICE, 0.35 + 0.3 * charge), true, -1.0, true)
		draw_dashed_line(at + Vector2(-60.0, 0.0), Vector2(60.0, at.y), Color(ICE, 0.25 + 0.5 * charge), 2.4, 12.0)
	elif pair_left > 0.0:
		draw_circle(at + Vector2(-46.0, 0.0), 18.0, Color(ICE, 0.6), true, -1.0, true)


func _draw_core(dead: bool) -> void:
	var point := core_point()
	var open := is_open()
	var tint := ICE if open else AMBER
	if dead:
		tint = Color("#5d686e")
	draw_circle(point, 28.0, BLACK, true, -1.0, true)
	draw_circle(point, 23.0, Color("#3e4b4d"), true, -1.0, true)
	draw_circle(point, 15.0, Color(tint, 0.36), true, -1.0, true)
	if open:
		var breathe := 0.58 + sin(clock * 16.0) * 0.18
		draw_arc(point, 34.0, -PI * 0.5, -PI * 0.5 + TAU * left / OPEN_TIME, 44, Color(ICE, 0.9), 2.8, true)
		draw_circle(point, 11.0 + 4.0 * breathe, Color(ICE, breathe), true, -1.0, true)
	else:
		# The blast shutter: two plates across the core.
		draw_rect(Rect2(point.x - 26.0, point.y - 24.0, 52.0, 20.0), PLATE.darkened(0.2))
		draw_rect(Rect2(point.x - 26.0, point.y + 4.0, 52.0, 20.0), PLATE.darkened(0.2))
		draw_line(point + Vector2(-26.0, -2.0), point + Vector2(26.0, -2.0), tint, 2.0)
		if flash > 0.0:
			draw_arc(point, 28.0 + (0.3 - flash) * 80.0, -PI, PI, 40, Color(AMBER, flash * 2.5), 3.0, true)


func _draw_warning() -> void:
	if state != State.WINDUP or attack == "heavy":
		return
	var charge := 1.0 - left / duration
	var sweep := attack == "sweep"
	var tint := HEAT if sweep else ICE
	var from := Vector2(front_x - 34.0, FLOOR_Y - 10.0 if sweep else LOW_Y)
	draw_dashed_line(from, Vector2(40.0, from.y), Color(tint, 0.25 + 0.45 * charge), 2.0 if sweep else 1.4, 12.0)
	draw_circle(from, 6.0 + 9.0 * charge, Color(tint, 0.4), true, -1.0, true)
	draw_arc(from, 20.0 - 9.0 * charge, 0.0, TAU, 28, Color(tint, 0.8), 2.0, true)
