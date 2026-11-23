extends Node2D

## 디스패처. The harbour's dispatch intelligence, in a control cab hung from an
## overhead rail between two signal masts. It works two ways, and its last
## phase alternates them:
##  · 신호 (signal): the cab rides high behind a signal field while the masts
##    fire heavy shells across the pier. Catch one in the air and the field
##    drops: hit the core under the cab with a diagonal shot from a floor mark.
##  · 배차 (dispatch): the cab comes down with a container under it, its roof
##    200 above the floor. Catch a blue container and the roof core unlocks:
##    bounce up through the roof and fire down onto it, as with the carrier.
## The node sits at the world origin; everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal heavy_fired(origin: Vector2, direction: float)
signal load_caught(origin: Vector2, charge: int)
signal load_crashed(point: Vector2, hit_player: bool)
signal jolted
signal mode_changed

enum Mode { SIGNAL, DISPATCH }
enum State { IDLE, WINDUP, TRACK, LOCK, DROP, OPEN, RECOVER, DOWN }

const Sera = preload("res://scripts/sera.gd")
const DropLoad = preload("res://scripts/drop_load.gd")
const Texts = preload("res://texts.gd")
const HITS := 3
const FLOOR_Y := 520.0
const RAIL_Y := 118.0
## Roof height while signalling: the core hangs 70 below it, 220 above the floor.
const HIGH_ROOF := 230.0
## Roof height while dispatching: 200 above the floor, a bounce up from below.
const LOW_ROOF := 320.0
const CORE_DROP := 70.0
const HALF := 120.0
const HOLD_Y := 372.0
const SIGNAL_OPEN := 3.2
const ROOF_OPEN := 4.2
const CORE_WIDTH := 46.0
const STOMP_WIDTH := 64.0
## Standing this far to either side of the cab lines a diagonal shot up with the core.
const AIM_OFFSET := 148.0
const MIN_X := 330.0
const MAX_X := 822.0
const SHELL_Y := 380.0
const MASTS := [56.0, 1096.0]
const ICE := Color("#84ebff")
const RED := Color("#ff7251")
const AMBER := Color("#ffc186")
const SIGNAL := Color("#ff9b5c")
const STEEL := Color("#283439")
const PLATE := Color("#5a6a70")
const BLACK := Color("#0e171c")

var player: Sera
var health := HITS
var mode := Mode.SIGNAL
var state := State.IDLE
var left := 1.2
var duration := 1.2
var cx := 576.0
var roof_y := HIGH_ROOF
var step := 0
var heavy := false
var mast := 0
var volley := 0
var dormant := false
var sweep_from := 1
var sweep_warning := 0.0
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
	box.size = Vector2(HALF * 2.0, 16.0)
	shape.shape = box
	shape.position = Vector2(0.0, 8.0)
	shape.one_way_collision = true
	roof.add_child(shape)
	add_child(roof)
	roof.position = Vector2(cx, roof_y)


func reset_attempt() -> void:
	cargo.clear()
	step = 0
	volley = 0
	sweep_warning = 0.0
	jolt_left = -1.0
	flash = 0.0
	mode = _phase_mode()
	roof_y = HIGH_ROOF if mode == Mode.SIGNAL else LOW_ROOF
	if health > 0:
		_enter(State.IDLE, 1.3)
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	step = 0
	_enter(State.IDLE, 1.1)
	return true


## The first phase signals, the second dispatches, the last starts with a signal.
func _phase_mode() -> Mode:
	return Mode.DISPATCH if health == 2 else Mode.SIGNAL


func is_open() -> bool:
	return state == State.OPEN


func open_ratio() -> float:
	return left / duration if is_open() and duration > 0.0 else 0.0


func status_text() -> String:
	if state == State.DOWN:
		return Texts.DISPATCHER_STATUS_STOPPED
	if is_open():
		return Texts.DISPATCHER_STATUS_OPEN
	return Texts.DISPATCHER_STATUS_SIGNAL if mode == Mode.SIGNAL else Texts.DISPATCHER_STATUS_ROOF


func core_point() -> Vector2:
	return Vector2(cx, roof_y + CORE_DROP) if mode == Mode.SIGNAL else Vector2(cx, roof_y)


func aim_marks() -> Array:
	if mode != Mode.SIGNAL:
		return []
	return [Vector2(cx - AIM_OFFSET, FLOOR_Y), Vector2(cx + AIM_OFFSET, FLOOR_Y)]


func mast_point(index: int) -> Vector2:
	return Vector2(MASTS[index], SHELL_Y)


func shell_coming() -> bool:
	return mode == Mode.SIGNAL and state == State.WINDUP


func threatens_from_above() -> bool:
	return mode == Mode.DISPATCH and (state == State.LOCK or state == State.DROP)


func on_roof(body: Node2D) -> bool:
	return absf(body.global_position.y - roof_y) < 6.0 and absf(body.global_position.x - cx) < HALF + 14.0


func stomp_reaches(body: Node2D) -> bool:
	if mode != Mode.DISPATCH:
		return false
	var height := roof_y - body.global_position.y
	return absf(body.global_position.x - cx) < STOMP_WIDTH and height > -6.0 and height < 326.0


## A heavy shell was caught: in signal mode that drops the field.
func catch_shell() -> void:
	if mode != Mode.SIGNAL or state == State.DOWN or dormant:
		return
	volley = 0
	_enter(State.OPEN, SIGNAL_OPEN)


## `from_above` is a downward shot; the other kind is a diagonal one from below.
func hit_core(from_above: bool) -> bool:
	if not is_open() or from_above != (mode == Mode.DISPATCH):
		flash = 0.3
		return false
	health -= 1
	step = 0
	volley = 0
	sweep_warning = 0.0
	if health == 0:
		_enter(State.DOWN, 0.0)
		return true
	_enter(State.RECOVER, 1.6)
	var next := _phase_mode()
	if next != mode:
		mode = next
		mode_changed.emit()
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	cargo.advance(delta, player)
	_move(delta)
	if state == State.DOWN or dormant:
		queue_redraw()
		return
	_run_side_sweep(delta)
	if mode == Mode.DISPATCH:
		_check_jolt(delta)
	left = maxf(0.0, left - delta)
	if left == 0.0:
		_advance()
	queue_redraw()


func _move(delta: float) -> void:
	var goal_y := HIGH_ROOF if mode == Mode.SIGNAL else LOW_ROOF
	roof_y = move_toward(roof_y, goal_y, 150.0 * delta)
	var pace := 0.0
	if not dormant and state != State.DOWN:
		if mode == Mode.SIGNAL and state != State.OPEN:
			pace = 110.0
		elif mode == Mode.DISPATCH and state == State.TRACK:
			pace = 280.0 if health == 1 else 230.0
	if pace > 0.0:
		cx = move_toward(cx, clampf(player.global_position.x, MIN_X, MAX_X), pace * delta)
	roof.position = Vector2(cx, roof_y)


func _check_jolt(delta: float) -> void:
	if not player.is_on_floor() or not on_roof(player):
		jolt_left = -1.0
		return
	if jolt_left < 0.0:
		jolt_left = (1.4 if health == 1 else 60.0) if is_open() else (1.5 if health == 2 else 1.0)
	jolt_left -= delta
	if jolt_left > 0.0:
		return
	jolt_left = -1.0
	var side := signf(player.global_position.x - cx)
	player.velocity = Vector2((side if side != 0.0 else 1.0) * 520.0, -420.0)
	player.air_carry = true
	jolted.emit()


func _run_side_sweep(delta: float) -> void:
	if sweep_warning > 0.0:
		sweep_warning -= delta
		if sweep_warning <= 0.0:
			var x: float = MASTS[sweep_from] + (30.0 if sweep_from == 0 else -30.0)
			attack_fired.emit(Vector2(x, FLOOR_Y - 10.0), 1.0 if sweep_from == 0 else -1.0, true)


func _advance() -> void:
	match state:
		State.IDLE:
			_begin_cycle()
		State.WINDUP:
			var from := mast_point(mast) + Vector2(40.0 if mast == 0 else -40.0, 0.0)
			heavy_fired.emit(from, 1.0 if mast == 0 else -1.0)
			volley -= 1
			if volley > 0:
				mast = 1 - mast
				_enter(State.WINDUP, 0.6)
				attack_prepared.emit(false)
			else:
				_enter(State.RECOVER, 1.2)
		State.TRACK:
			_enter(State.LOCK, 0.62 if health == 1 else 0.75)
			attack_prepared.emit(heavy)
		State.LOCK:
			_enter(State.DROP, 3.0)
			cargo.drop(Vector2(cx, HOLD_Y), FLOOR_Y, heavy)
		State.DROP, State.OPEN, State.RECOVER:
			_cycle_done()


func _begin_cycle() -> void:
	if mode == Mode.SIGNAL:
		volley = 1 if health == 3 else 2
		# From the mast farther from Sera, so the shell crosses the pier toward her.
		mast = 0 if player.global_position.x > 576.0 else 1
		_enter(State.WINDUP, 0.95 if health == 3 else 0.8)
		attack_prepared.emit(false)
		return
	var plan: Array = ["blue", "sweep", "red", "blue"] if health == 2 else ["red", "blue"]
	var kind: String = plan[step % plan.size()]
	step += 1
	if kind == "sweep":
		sweep_from = 0 if player.global_position.x > 576.0 else 1
		sweep_warning = 0.8
		attack_prepared.emit(true)
		_enter(State.RECOVER, 1.5)
		return
	heavy = kind == "red"
	_enter(State.TRACK, 1.0 if health == 2 else 0.8)


## The last phase switches between signalling and dispatching after every round.
func _cycle_done() -> void:
	if health == 1 and (mode == Mode.SIGNAL or step % 2 == 0):
		mode = Mode.DISPATCH if mode == Mode.SIGNAL else Mode.SIGNAL
		mode_changed.emit()
		_enter(State.IDLE, 1.1)
		return
	_enter(State.IDLE, 0.9 if health == 3 else 0.7)


func _on_cargo_caught(origin: Vector2, charge: int) -> void:
	_enter(State.OPEN, ROOF_OPEN)
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
	_draw_masts()
	# The rail and the hoist cables.
	draw_rect(Rect2(20.0, RAIL_Y - 14.0, 1112.0, 18.0), BLACK)
	draw_line(Vector2(20.0, RAIL_Y - 13.0), Vector2(1132.0, RAIL_Y - 13.0), PLATE, 2.0)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(cx + side * 60.0, RAIL_Y + 4.0), Vector2(cx + side * 80.0, roof_y), BLACK, 3.0)
	draw_rect(Rect2(cx - 70.0, RAIL_Y - 20.0, 140.0, 24.0), STEEL)
	if threatens_from_above():
		var tint := RED if heavy else ICE
		var pulse := 0.14 + 0.07 * sin(clock * 20.0)
		draw_rect(Rect2(cx - DropLoad.HALF, HOLD_Y + 30.0, DropLoad.HALF * 2.0, FLOOR_Y - HOLD_Y - 30.0), Color(tint, pulse * 0.45))
	# The cab: a roof the size of a platform, glass on the front, the core under it.
	var body := STEEL.darkened(0.25) if dead else STEEL
	draw_rect(Rect2(cx - HALF, roof_y, HALF * 2.0, 16.0), PLATE.darkened(0.15))
	draw_line(Vector2(cx - HALF, roof_y), Vector2(cx + HALF, roof_y), PLATE.lightened(0.25), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - HALF + 10.0, roof_y + 16.0), Vector2(cx + HALF - 10.0, roof_y + 16.0),
		Vector2(cx + HALF - 34.0, roof_y + 52.0), Vector2(cx - HALF + 34.0, roof_y + 52.0)]), body)
	for window in 4:
		var wx := cx - 66.0 + window * 36.0
		draw_rect(Rect2(wx, roof_y + 22.0, 26.0, 16.0), Color("#ffcf8a", 0.15 if dead else 0.5))
	if mode == Mode.DISPATCH or roof_y > HIGH_ROOF + 10.0:
		var holding := state == State.TRACK or state == State.LOCK or (dormant and mode == Mode.DISPATCH)
		draw_rect(Rect2(cx - 104.0, HOLD_Y - 34.0, 208.0, 8.0), PLATE.darkened(0.3))
		if holding and not dead:
			DropLoad.draw_load(self, Vector2(cx, HOLD_Y), heavy, clock)
	_draw_core(dead)


func _draw_core(dead: bool) -> void:
	var point := core_point()
	var open := is_open()
	var tint := ICE if open else AMBER
	if dead:
		tint = Color("#5d686e")
	if mode == Mode.SIGNAL:
		draw_line(Vector2(cx, roof_y + 52.0), point, BLACK, 6.0)
		draw_circle(point, 24.0, BLACK, true, -1.0, true)
		draw_circle(point, 19.0, Color("#3e4b4d"), true, -1.0, true)
		draw_circle(point, 12.0, Color(tint, 0.4), true, -1.0, true)
		if not open and not dead:
			# The signal field around the cab.
			var glow := 0.18 + 0.06 * sin(clock * 6.0) + flash
			draw_set_transform(Vector2(cx, roof_y + 40.0), 0.0, Vector2(1.0, 0.62))
			draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 60, Color(SIGNAL, glow * 2.0), 3.0, true)
			draw_circle(Vector2.ZERO, 150.0, Color(SIGNAL, glow * 0.35))
			draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(point.x - 40.0, point.y - 6.0, 80.0, 10.0), BLACK)
		draw_circle(point + Vector2(0.0, -4.0), 16.0, Color(tint, 0.3), true, -1.0, true)
		if not open and flash > 0.0:
			draw_arc(point, 24.0 + (0.3 - flash) * 80.0, PI, TAU, 40, Color(AMBER, flash * 2.5), 3.0, true)
	if open:
		var breathe := 0.6 + sin(clock * 15.0) * 0.18
		draw_arc(point, 30.0, -PI * 0.5, -PI * 0.5 + TAU * open_ratio(), 40, Color(ICE, 0.9), 2.6, true)
		draw_circle(point, 9.0 + 4.0 * breathe, Color(ICE, breathe), true, -1.0, true)


func _draw_masts() -> void:
	for index in MASTS.size():
		var x: float = MASTS[index]
		var inward := 1.0 if index == 0 else -1.0
		draw_rect(Rect2(x - 12.0, SHELL_Y - 40.0, 24.0, FLOOR_Y - SHELL_Y + 40.0), STEEL)
		draw_rect(Rect2(x - 22.0, SHELL_Y - 26.0, 44.0, 40.0), STEEL.lightened(0.05))
		draw_rect(Rect2(x + inward * 18.0 - (0.0 if inward > 0.0 else 26.0), SHELL_Y - 7.0, 26.0, 14.0), BLACK)
		for lamp in 3:
			var on := int(clock * 2.0 + index + lamp) % 3 == 0
			draw_circle(Vector2(x, SHELL_Y - 60.0 - lamp * 22.0), 5.0, SIGNAL if on else Color("#5b4a44"))
		var charging := shell_coming() and mast == index
		if charging:
			var charge := 1.0 - left / duration
			var muzzle := mast_point(index) + Vector2(inward * 44.0, 0.0)
			draw_circle(muzzle, 8.0 + 12.0 * charge, Color(ICE, 0.3 + 0.35 * charge), true, -1.0, true)
			draw_dashed_line(muzzle, muzzle + Vector2(inward * 1000.0, 0.0), Color(ICE, 0.2 + 0.5 * charge), 2.4, 12.0)
		var warming := sweep_warning > 0.0 and sweep_from == index
		if warming:
			var heat := 1.0 - sweep_warning / 0.8
			draw_dashed_line(Vector2(x + inward * 30.0, FLOOR_Y - 10.0), Vector2(x + inward * 1000.0, FLOOR_Y - 10.0), Color(RED, 0.3 + 0.45 * heat), 2.0, 10.0)
