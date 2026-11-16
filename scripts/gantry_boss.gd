extends Node2D

## 갠트리. The loading yard's overhead crane. Its trolley follows Sera and lets
## go of what it carries. Catching blue-lit steel fills the suit and leaves the
## clamp empty, which bares the core under the trolley for a few seconds: step
## out to the side and hit it with a diagonal shockwave. Red-lit slabs cannot
## be caught. Later phases add floor sweeps from the yard walls.
## The node sits at the world origin; everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal load_caught(origin: Vector2, charge: int)
signal load_crashed(point: Vector2, hit_player: bool)

enum State { TRACK, LOCK, DROP, EXPOSED, RECOVER, DOWN }

const Sera = preload("res://scripts/sera.gd")
const DropLoad = preload("res://scripts/drop_load.gd")
const Texts = preload("res://texts.gd")
const ART := "res://assets/characters/gantry.png"
const HITS := 3
const OPEN_TIME := 3.4
const CORE_WIDTH := 46.0
const FLOOR_Y := 520.0
## The crane hangs below the HUD plates so the trolley and its load stay in view.
const RAIL_Y := 160.0
const HOLD_Y := 218.0
const CORE_Y := 264.0
const MIN_X := 330.0
const MAX_X := 822.0
## Standing this far to either side of the trolley lines the diagonal shot up with the core.
const AIM_OFFSET := 184.0
const EMITTERS := [Vector2(86.0, 510.0), Vector2(1066.0, 510.0)]
## What each phase does in a loop, by remaining health.
const PLANS := {3: ["beam"], 2: ["slab", "sweep", "beam"], 1: ["slab", "beam"]}
const ICE := Color("#84ebff")
const RED := Color("#ff7251")
const AMBER := Color("#ffc186")
const STEEL := Color("#26343b")
const BLACK := Color("#101b21")

var player: Sera
var health := HITS
var state := State.TRACK
var state_left := 1.2
var state_duration := 1.2
var trolley_x := 576.0
var step := 0
var heavy := false
var dormant := false
var sweep_from := 1
var sweep_due := -1.0
var sweep_warning := 0.0
var flash := 0.0
var clock := 0.0
var art: Texture2D

@onready var cargo: DropLoad = $Load


func _ready() -> void:
	cargo.caught.connect(_on_cargo_caught)
	cargo.crashed.connect(_on_cargo_crashed)
	if ResourceLoader.exists(ART):
		art = load(ART)


func reset_attempt() -> void:
	cargo.clear()
	trolley_x = 576.0
	step = 0
	sweep_due = -1.0
	sweep_warning = 0.0
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
	_begin_step(1.2)
	return true


func is_open() -> bool:
	return state == State.EXPOSED


func open_ratio() -> float:
	return state_left / OPEN_TIME if is_open() else 0.0


func status_text() -> String:
	return Texts.YARD_STATUS_OPEN if is_open() else Texts.YARD_STATUS_SHUT


func core_point() -> Vector2:
	return Vector2(trolley_x, CORE_Y)


## True while a load is about to come down or is falling.
func threatens_from_above() -> bool:
	return state == State.LOCK or state == State.DROP


func aim_marks() -> Array:
	return [Vector2(trolley_x - AIM_OFFSET, FLOOR_Y), Vector2(trolley_x + AIM_OFFSET, FLOOR_Y)]


func hit_core() -> bool:
	if not is_open():
		flash = 0.3
		return false
	health -= 1
	sweep_due = -1.0
	sweep_warning = 0.0
	step = 0
	if health == 0:
		_enter(State.DOWN, 0.0)
	else:
		_enter(State.RECOVER, 1.2)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	cargo.advance(delta, player)
	if state == State.DOWN or dormant:
		queue_redraw()
		return
	if state == State.TRACK:
		var pace := 340.0 if health == 1 else (300.0 if health == 2 else 260.0)
		trolley_x = move_toward(trolley_x, clampf(player.global_position.x, MIN_X, MAX_X), pace * delta)
	_run_side_sweep(delta)
	state_left = maxf(0.0, state_left - delta)
	if state_left == 0.0:
		_advance()
	queue_redraw()


## In the last phase a sweep crosses the yard while the core is bared.
func _run_side_sweep(delta: float) -> void:
	if sweep_warning > 0.0:
		sweep_warning -= delta
		if sweep_warning <= 0.0:
			_fire_sweep()
	elif sweep_due > 0.0:
		sweep_due -= delta
		if sweep_due <= 0.0:
			_warn_sweep()


func _advance() -> void:
	match state:
		State.TRACK:
			_enter(State.LOCK, 0.75 if health == 1 else (0.85 if health == 2 else 0.95))
			attack_prepared.emit(heavy)
		State.LOCK:
			_enter(State.DROP, 3.0)
			cargo.drop(Vector2(trolley_x, HOLD_Y), FLOOR_Y, heavy)
		State.DROP, State.EXPOSED, State.RECOVER:
			_begin_step(0.0)


## Starts the next entry of this phase's plan after `pause` seconds of plain tracking.
func _begin_step(pause: float) -> void:
	var plan: Array = PLANS[health]
	var kind: String = plan[step % plan.size()]
	step += 1
	if kind == "sweep":
		_warn_sweep()
		_enter(State.RECOVER, 1.7)
		return
	heavy = kind == "slab"
	_enter(State.TRACK, pause + (0.8 if health == 1 else (1.0 if health == 2 else 1.3)))


func _warn_sweep() -> void:
	# From the wall farther from Sera, so the wave crosses the yard to her.
	sweep_from = 0 if player.global_position.x > 576.0 else 1
	sweep_warning = 0.8
	attack_prepared.emit(true)


func _fire_sweep() -> void:
	sweep_warning = 0.0
	var origin: Vector2 = EMITTERS[sweep_from]
	attack_fired.emit(origin, 1.0 if sweep_from == 0 else -1.0, true)


func _on_cargo_caught(origin: Vector2, charge: int) -> void:
	_enter(State.EXPOSED, OPEN_TIME)
	if health == 1:
		sweep_due = 0.45
	load_caught.emit(origin, charge)


func _on_cargo_crashed(point: Vector2, hit_player: bool) -> void:
	if state == State.DROP:
		_enter(State.RECOVER, 0.7)
	load_crashed.emit(point, hit_player)


func _enter(next_state: State, duration: float) -> void:
	state = next_state
	state_left = duration
	state_duration = duration


func _draw() -> void:
	_draw_rail()
	_draw_emitters()
	if threatens_from_above():
		_draw_drop_zone()
	_draw_trolley()


func _draw_rail() -> void:
	for x in [40.0, 1112.0]:
		draw_rect(Rect2(x - 13.0, RAIL_Y - 20.0, 26.0, FLOOR_Y - RAIL_Y + 20.0), Color(0.07, 0.11, 0.14, 0.75))
		draw_line(Vector2(x - 9.0, RAIL_Y), Vector2(x - 9.0, FLOOR_Y), Color("#3a4d57"), 2.0)
	draw_rect(Rect2(20.0, RAIL_Y - 20.0, 1112.0, 22.0), BLACK)
	draw_line(Vector2(20.0, RAIL_Y - 19.0), Vector2(1132.0, RAIL_Y - 19.0), Color("#6f858c"), 2.0)
	draw_line(Vector2(20.0, RAIL_Y + 2.0), Vector2(1132.0, RAIL_Y + 2.0), Color("#33444d"), 3.0)
	for x in range(48, 1120, 67):
		draw_line(Vector2(x, RAIL_Y - 17.0), Vector2(x + 30, RAIL_Y - 1.0), Color("#1c2a32"), 4.0, true)


func _draw_emitters() -> void:
	for index in EMITTERS.size():
		var point: Vector2 = EMITTERS[index]
		var out := 1.0 if index == 0 else -1.0
		var warming := sweep_warning > 0.0 and sweep_from == index
		draw_rect(Rect2(point.x - 16.0, point.y - 34.0, 32.0, 44.0), STEEL)
		draw_rect(Rect2(point.x - 12.0, point.y - 30.0, 24.0, 5.0), Color("#6f858c"))
		draw_circle(point + Vector2(out * 10.0, -6.0), 6.0, RED if warming else Color("#5b4a44"))
		if health <= 2 and warming:
			var charge := 1.0 - sweep_warning / 0.8
			draw_dashed_line(point + Vector2(out * 18.0, 0.0), point + Vector2(out * 880.0, 0.0), Color(RED, 0.3 + 0.45 * charge), 2.0, 10.0)
			draw_arc(point + Vector2(out * 10.0, -6.0), 20.0 - 8.0 * charge, 0.0, TAU, 28, RED, 2.0, true)


func _draw_drop_zone() -> void:
	var tint := RED if heavy else ICE
	var pulse := 0.14 + 0.07 * sin(clock * 20.0)
	var half := DropLoad.HALF + (10.0 if heavy else 0.0)
	draw_rect(Rect2(trolley_x - half, HOLD_Y + 30.0, half * 2.0, FLOOR_Y - HOLD_Y - 30.0), Color(tint, pulse * 0.45))
	draw_rect(Rect2(trolley_x - half, FLOOR_Y - 15.0, half * 2.0, 14.0), Color(tint, pulse * 1.6))
	for edge in [-half, half]:
		draw_dashed_line(Vector2(trolley_x + edge, HOLD_Y + 30.0), Vector2(trolley_x + edge, FLOOR_Y), Color(tint, 0.55), 1.5, 9.0)


func _draw_trolley() -> void:
	var x := trolley_x
	var dead := state == State.DOWN
	if art:
		var size := Vector2(280.0, 280.0 * art.get_height() / art.get_width())
		draw_texture_rect(art, Rect2(x - size.x * 0.5, RAIL_Y - 30.0, size.x, size.y), false, Color("#7d8a8d") if dead else Color.WHITE)
	else:
		# Carriage on the rail, winch housing and the two clamp arms.
		draw_rect(Rect2(x - 92.0, RAIL_Y - 30.0, 184.0, 40.0), STEEL)
		draw_rect(Rect2(x - 86.0, RAIL_Y - 26.0, 172.0, 6.0), Color("#75858c"))
		for wheel in [-68.0, 68.0]:
			draw_circle(Vector2(x + wheel, RAIL_Y - 4.0), 10.0, BLACK)
			draw_arc(Vector2(x + wheel, RAIL_Y - 4.0), 10.0, 0.0, TAU, 18, Color("#8a989d"), 1.5, true)
		draw_rect(Rect2(x - 44.0, RAIL_Y + 10.0, 88.0, 22.0), BLACK)
		draw_rect(Rect2(x - 38.0, RAIL_Y + 14.0, 76.0, 5.0), Color("#5d6e76"))
		var holding := dormant or state == State.TRACK or state == State.LOCK
		var spread := 0.0 if holding else 26.0
		for side in [-1.0, 1.0]:
			var shoulder := Vector2(x + side * 78.0, RAIL_Y + 10.0)
			var elbow := Vector2(x + side * (104.0 + spread), HOLD_Y - 6.0)
			var claw := Vector2(x + side * (96.0 + spread), HOLD_Y + 30.0)
			draw_line(shoulder, elbow, STEEL, 9.0, true)
			draw_line(elbow, claw, STEEL, 8.0, true)
			draw_line(claw, claw + Vector2(-side * 16.0, 4.0), Color("#8a989d"), 5.0, true)
			draw_circle(elbow, 6.0, Color("#55666e"))
	# What it is carrying, until it lets go.
	if (state == State.TRACK or state == State.LOCK or dormant) and not dead:
		var sway := sin(clock * 22.0) * 2.0 if state == State.LOCK else 0.0
		DropLoad.draw_load(self, Vector2(x + sway, HOLD_Y), heavy and not dormant, clock)
	# The core hangs under the winch.
	var point := core_point()
	var open := is_open()
	var tint := ICE if open else AMBER
	if dead:
		tint = Color("#5d686e")
	draw_line(Vector2(x, RAIL_Y + 30.0), point, BLACK, 7.0)
	draw_circle(point, 26.0, BLACK, true, -1.0, true)
	draw_circle(point, 22.0, Color("#3e4b4d"), true, -1.0, true)
	draw_arc(point, 22.0, 0.0, TAU, 36, Color("#b2a19a"), 1.6, true)
	draw_circle(point, 15.0, Color(tint, 0.34), true, -1.0, true)
	if open:
		var breathe := 0.58 + sin(clock * 16.0) * 0.18
		draw_arc(point, 32.0, -PI * 0.5, -PI * 0.5 + TAU * state_left / OPEN_TIME, 44, Color(ICE, 0.9), 2.8, true)
		draw_circle(point, 11.0 + 4.0 * breathe, Color(ICE, breathe), true, -1.0, true)
		draw_circle(point, 6.0 + breathe * 2.0, Color("#ecffff"), true, -1.0, true)
	else:
		draw_line(point + Vector2(-12, -3), point + Vector2(12, -3), tint, 3.0, true)
		draw_line(point + Vector2(-9, 4), point + Vector2(9, 4), Color(tint, 0.54), 2.0, true)
		if flash > 0.0:
			draw_arc(point, 26.0 + (0.3 - flash) * 80.0, -PI, PI, 40, Color(AMBER, flash * 2.5), 3.0, true)
