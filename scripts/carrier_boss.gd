extends Node2D

## 스트래들 캐리어. A port straddle carrier: a roof beam on four tall legs that
## drives over the yard with a container hung under it. It lines up over Sera
## and lets go. A blue container can be caught; that empties the spreader and
## unlocks the core plate on the roof for a few seconds. Fire at your own feet
## to bounce up through the roof, then fire down onto the core from on top.
## Red containers are too heavy to catch. Later phases add floor sweeps and a
## jolt that throws Sera off the roof. The node sits at the world origin;
## everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal load_caught(origin: Vector2, charge: int)
signal load_crashed(point: Vector2, hit_player: bool)
signal jolted

enum State { TRACK, LOCK, DROP, OPEN, RECOVER, DOWN }

const Sera = preload("res://scripts/sera.gd")
const DropLoad = preload("res://scripts/drop_load.gd")
const Texts = preload("res://texts.gd")
const HITS := 3
const OPEN_TIME := 4.2
## How far from the roof's middle a downward shot still lands on the core.
const CORE_WIDTH := 72.0
const FLOOR_Y := 520.0
const ROOF_Y := 320.0
## Half the roof's width; the legs stand at its ends.
const HALF := 150.0
const HOLD_Y := 372.0
const MIN_X := 260.0
const MAX_X := 890.0
const EMITTERS := [Vector2(86.0, 510.0), Vector2(1066.0, 510.0)]
const PLANS := {3: ["blue"], 2: ["red", "sweep", "blue"], 1: ["red", "blue"]}
const ICE := Color("#84ebff")
const RED := Color("#ff7251")
const AMBER := Color("#ffc186")
const STEEL := Color("#2a363c")
const PLATE := Color("#5b6a70")
const STRIPE := Color("#c9a046")
const BLACK := Color("#0f181d")

var player: Sera
var health := HITS
var state := State.TRACK
var left := 1.2
var duration := 1.2
var cx := 700.0
var step := 0
var heavy := false
var dormant := false
var sweep_from := 1
var sweep_warning := 0.0
## Counts down while Sera stands on the roof; at zero the carrier jolts her off.
var jolt_left := -1.0
var flash := 0.0
var clock := 0.0
var roof: AnimatableBody2D

@onready var cargo: DropLoad = $Load


func _ready() -> void:
	cargo.caught.connect(_on_cargo_caught)
	cargo.crashed.connect(_on_cargo_crashed)
	roof = AnimatableBody2D.new()
	roof.collision_layer = 1
	roof.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(HALF * 2.0, 18.0)
	shape.shape = box
	shape.position = Vector2(0.0, 9.0)
	# The roof is solid only from above, so Sera can bounce up through it.
	shape.one_way_collision = true
	roof.add_child(shape)
	add_child(roof)
	roof.position = Vector2(cx, ROOF_Y)


func reset_attempt() -> void:
	cargo.clear()
	step = 0
	sweep_warning = 0.0
	jolt_left = -1.0
	flash = 0.0
	if health > 0:
		_begin_step(1.3)
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	step = 0
	_begin_step(1.0)
	return true


func is_open() -> bool:
	return state == State.OPEN


func open_ratio() -> float:
	return left / OPEN_TIME if is_open() else 0.0


func status_text() -> String:
	if state == State.DOWN:
		return Texts.CARRIER_STATUS_STOPPED
	return Texts.CARRIER_STATUS_OPEN if is_open() else Texts.CARRIER_STATUS_SHUT


func core_point() -> Vector2:
	return Vector2(cx, ROOF_Y)


func threatens_from_above() -> bool:
	return state == State.LOCK or state == State.DROP


func on_roof(body: Node2D) -> bool:
	return absf(body.global_position.y - ROOF_Y) < 6.0 and absf(body.global_position.x - cx) < HALF + 14.0


## A downward shot from on or above the roof, near its middle, reaches the core.
func stomp_reaches(body: Node2D) -> bool:
	var height := ROOF_Y - body.global_position.y
	return absf(body.global_position.x - cx) < CORE_WIDTH and height > -6.0 and height < 326.0


func hit_core() -> bool:
	if not is_open():
		flash = 0.3
		return false
	health -= 1
	step = 0
	sweep_warning = 0.0
	if health == 0:
		_enter(State.DOWN, 0.0)
	else:
		_enter(State.RECOVER, 1.6)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	cargo.advance(delta, player)
	if state == State.TRACK and not dormant:
		var pace := 300.0 if health == 1 else (250.0 if health == 2 else 210.0)
		cx = move_toward(cx, clampf(player.global_position.x, MIN_X, MAX_X), pace * delta)
	roof.position = Vector2(cx, ROOF_Y)
	if state == State.DOWN or dormant:
		queue_redraw()
		return
	_run_side_sweep(delta)
	_check_jolt(delta)
	left = maxf(0.0, left - delta)
	if left == 0.0:
		_advance()
	queue_redraw()


## Standing on the roof is allowed, not camping: after a while the carrier
## shakes Sera off, sooner in later phases and sooner while the core is shut.
func _check_jolt(delta: float) -> void:
	if not player.is_on_floor() or not on_roof(player):
		jolt_left = -1.0
		return
	if jolt_left < 0.0:
		jolt_left = _jolt_delay()
	jolt_left -= delta
	if jolt_left > 0.0:
		return
	jolt_left = -1.0
	var side := signf(player.global_position.x - cx)
	player.velocity = Vector2((side if side != 0.0 else 1.0) * 520.0, -420.0)
	# Keep the throw going in the air so it actually clears the roof.
	player.air_carry = true
	jolted.emit()


func _jolt_delay() -> float:
	if is_open():
		return 1.6 if health == 1 else 60.0
	return 2.6 if health == 3 else (1.6 if health == 2 else 1.0)


func _run_side_sweep(delta: float) -> void:
	if sweep_warning > 0.0:
		sweep_warning -= delta
		if sweep_warning <= 0.0:
			var origin: Vector2 = EMITTERS[sweep_from]
			attack_fired.emit(origin, 1.0 if sweep_from == 0 else -1.0, true)


func _advance() -> void:
	match state:
		State.TRACK:
			_enter(State.LOCK, 0.6 if health == 1 else (0.72 if health == 2 else 0.85))
			attack_prepared.emit(heavy)
		State.LOCK:
			_enter(State.DROP, 3.0)
			cargo.drop(Vector2(cx, HOLD_Y), FLOOR_Y, heavy)
		State.DROP, State.OPEN, State.RECOVER:
			_begin_step(0.0)


func _begin_step(pause: float) -> void:
	var plan: Array = PLANS[health]
	var kind: String = plan[step % plan.size()]
	step += 1
	if kind == "sweep":
		sweep_from = 0 if player.global_position.x > 576.0 else 1
		sweep_warning = 0.8
		attack_prepared.emit(true)
		_enter(State.RECOVER, 1.6)
		return
	heavy = kind == "red"
	_enter(State.TRACK, pause + (0.8 if health == 1 else (1.0 if health == 2 else 1.2)))


func _on_cargo_caught(origin: Vector2, charge: int) -> void:
	_enter(State.OPEN, OPEN_TIME)
	jolt_left = -1.0
	load_caught.emit(origin, charge)


func _on_cargo_crashed(point: Vector2, hit_player: bool) -> void:
	if state == State.DROP:
		_enter(State.RECOVER, 0.7)
	load_crashed.emit(point, hit_player)


func _enter(next_state: State, time: float) -> void:
	state = next_state
	left = time
	duration = time


func _draw() -> void:
	var dead := state == State.DOWN
	var body := STEEL.darkened(0.25) if dead else STEEL
	_draw_emitters()
	if threatens_from_above():
		_draw_drop_zone()
	# Legs: an A-frame at each end of the roof, on bogies.
	for side in [-1.0, 1.0]:
		var foot: float = cx + side * HALF
		draw_line(Vector2(foot - 18.0, FLOOR_Y - 26.0), Vector2(foot, ROOF_Y + 18.0), body, 12.0)
		draw_line(Vector2(foot + 18.0, FLOOR_Y - 26.0), Vector2(foot, ROOF_Y + 18.0), body, 12.0)
		draw_line(Vector2(foot - 12.0, FLOOR_Y - 90.0), Vector2(foot + 12.0, FLOOR_Y - 90.0), PLATE, 4.0)
		draw_rect(Rect2(foot - 34.0, FLOOR_Y - 30.0, 68.0, 14.0), BLACK)
		for wheel in [-20.0, 20.0]:
			draw_circle(Vector2(foot + wheel, FLOOR_Y - 10.0), 10.0, BLACK)
			draw_arc(Vector2(foot + wheel, FLOOR_Y - 10.0), 10.0, 0.0, TAU, 16, PLATE, 1.5, true)
	# Roof beam with hazard stripes and the operator's cab hanging under one end.
	draw_rect(Rect2(cx - HALF - 10.0, ROOF_Y, HALF * 2.0 + 20.0, 20.0), body)
	draw_line(Vector2(cx - HALF - 10.0, ROOF_Y), Vector2(cx + HALF + 10.0, ROOF_Y), PLATE.lightened(0.2), 2.0)
	for x in range(int(cx - HALF), int(cx + HALF), 28):
		draw_line(Vector2(x, ROOF_Y + 18.0), Vector2(x + 12.0, ROOF_Y + 6.0), Color(STRIPE, 0.5), 3.0)
	draw_rect(Rect2(cx - HALF + 6.0, ROOF_Y + 20.0, 54.0, 40.0), body)
	draw_rect(Rect2(cx - HALF + 12.0, ROOF_Y + 26.0, 30.0, 16.0), Color("#9fe9f2", 0.2 if dead else 0.45))
	# Spreader and what it still holds.
	var holding := dormant or state == State.TRACK or state == State.LOCK
	draw_line(Vector2(cx - 60.0, ROOF_Y + 20.0), Vector2(cx - 80.0, HOLD_Y - 30.0), BLACK, 3.0)
	draw_line(Vector2(cx + 60.0, ROOF_Y + 20.0), Vector2(cx + 80.0, HOLD_Y - 30.0), BLACK, 3.0)
	draw_rect(Rect2(cx - 104.0, HOLD_Y - 34.0, 208.0, 8.0), PLATE.darkened(0.3))
	if holding and not dead:
		var sway := sin(clock * 22.0) * 2.0 if state == State.LOCK else 0.0
		DropLoad.draw_load(self, Vector2(cx + sway, HOLD_Y), heavy and not dormant, clock)
	_draw_core(dead)


func _draw_core(dead: bool) -> void:
	var point := core_point() + Vector2(0.0, 4.0)
	var open := is_open()
	var tint := ICE if open else AMBER
	if dead:
		tint = Color("#5d686e")
	draw_rect(Rect2(point.x - 46.0, point.y - 8.0, 92.0, 12.0), BLACK)
	draw_circle(point + Vector2(0.0, -6.0), 20.0, Color(tint, 0.32 if open else 0.18), true, -1.0, true)
	if open:
		var breathe := 0.6 + sin(clock * 15.0) * 0.18
		draw_arc(point + Vector2(0.0, -6.0), 28.0, -PI * 0.5, -PI * 0.5 + TAU * left / OPEN_TIME, 40, Color(ICE, 0.9), 2.6, true)
		draw_circle(point + Vector2(0.0, -6.0), 9.0 + 4.0 * breathe, Color(ICE, breathe), true, -1.0, true)
		# A ring of arrows pointing down: hit it from above.
		for side in [-1.0, 1.0]:
			var x: float = point.x + side * 34.0
			draw_polyline(PackedVector2Array([Vector2(x - 6.0, point.y - 40.0), Vector2(x, point.y - 30.0), Vector2(x + 6.0, point.y - 40.0)]),
				Color(ICE, breathe), 2.0, true)
	else:
		draw_rect(Rect2(point.x - 30.0, point.y - 14.0, 60.0, 8.0), PLATE)
		draw_line(point + Vector2(-26.0, -10.0), point + Vector2(26.0, -10.0), tint, 2.0)
		if flash > 0.0:
			draw_arc(point, 26.0 + (0.3 - flash) * 80.0, PI, TAU, 40, Color(AMBER, flash * 2.5), 3.0, true)


func _draw_drop_zone() -> void:
	var tint := RED if heavy else ICE
	var pulse := 0.14 + 0.07 * sin(clock * 20.0)
	var half := DropLoad.HALF + (10.0 if heavy else 0.0)
	draw_rect(Rect2(cx - half, HOLD_Y + 30.0, half * 2.0, FLOOR_Y - HOLD_Y - 30.0), Color(tint, pulse * 0.45))
	draw_rect(Rect2(cx - half, FLOOR_Y - 15.0, half * 2.0, 14.0), Color(tint, pulse * 1.6))


func _draw_emitters() -> void:
	for index in EMITTERS.size():
		var point: Vector2 = EMITTERS[index]
		var out := 1.0 if index == 0 else -1.0
		var warming := sweep_warning > 0.0 and sweep_from == index
		draw_rect(Rect2(point.x - 16.0, point.y - 34.0, 32.0, 44.0), STEEL)
		draw_rect(Rect2(point.x - 12.0, point.y - 30.0, 24.0, 5.0), PLATE)
		draw_circle(point + Vector2(out * 10.0, -6.0), 6.0, RED if warming else Color("#5b4a44"))
		if warming:
			var charge := 1.0 - sweep_warning / 0.8
			draw_dashed_line(point + Vector2(out * 18.0, 0.0), point + Vector2(out * 880.0, 0.0), Color(RED, 0.3 + 0.45 * charge), 2.0, 10.0)
