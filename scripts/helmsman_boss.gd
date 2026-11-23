extends Node2D

## 키잡이. The cargo ship's steering intelligence, behind the mirrored glass of
## the bridge at the right of the foredeck. Mirrors turn every shockwave back,
## so the only way in is its own bolts, reflected into the helm core while the
## port is open for a volley.
##  · 1페이즈: the core sits in the low gun port; a plain reflect sends a bolt
##    straight back into it.
##  · 2페이즈: the core climbs to the high window while the low port keeps
##    firing; a reflect with W from the floor mark sends the bolt up into it.
##  · 3페이즈: the core moves between the two every volley, a floor sweep
##    comes first, and the bursts are longer.
## The node sits at the world origin; everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)

enum State { IDLE, AIM, FIRE, OPEN, RECOVER, DOWN }

const Texts = preload("res://texts.gd")
const HITS := 3
const FLOOR_Y := 520.0
const FACE_X := 872.0
const LOW_CORE := Vector2(884.0, 435.0)
const HIGH_CORE := Vector2(905.0, 300.0)
## Standing here, a reflect with W carries a bolt from the low port into the high core.
const AIM_X := 734.0
const CORE_RADIUS := 46.0
const AIM_TIME := 0.9
const OPEN_TIME := 1.3
const STEEL := Color("#27333a")
const PLATE := Color("#56666c")
const DARK := Color("#0e161b")
const GLASS := Color("#b9d3da")
const AMBER := Color("#ffc186")
const ICE := Color("#84ebff")
const RED := Color("#ff7251")

var health := HITS
var state := State.IDLE
var left := 1.2
var duration := 1.2
var dormant := false
var high := false
var shots_left := 0
var volley := 0
var clock := 0.0
var flash := 0.0
var sweep_warning := 0.0
## How far the mirror pane over the core has slid aside, 0 to 1.
var opening := 0.0


func reset_attempt() -> void:
	high = health == 2
	volley = 0
	shots_left = 0
	sweep_warning = 0.0
	flash = 0.0
	opening = 0.0
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
	_enter(State.IDLE, 1.0)
	return true


func core_point() -> Vector2:
	return HIGH_CORE if high else LOW_CORE


## The port is open from the aim to the end of the volley: reflected bolts get in.
func is_open() -> bool:
	return state == State.AIM or state == State.FIRE or state == State.OPEN


func open_ratio() -> float:
	if state == State.OPEN and duration > 0.0:
		return left / duration
	return 1.0 if is_open() else 0.0


func status_text() -> String:
	if state == State.DOWN:
		return Texts.HELM_STATUS_STOPPED
	return Texts.HELM_STATUS_OPEN if is_open() else Texts.HELM_STATUS_SHUT


func aim_marks() -> Array:
	return [Vector2(AIM_X, FLOOR_Y)] if high else []


func shot_coming() -> bool:
	return state == State.AIM


func flash_mirror() -> void:
	flash = 0.35


## A reflected shot reached the core. True when it counted.
func hit_core() -> bool:
	if not is_open() or state == State.DOWN:
		flash = 0.3
		return false
	health -= 1
	sweep_warning = 0.0
	if health == 0:
		_enter(State.DOWN, 0.0)
		return true
	high = health == 2
	_enter(State.RECOVER, 1.8)
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta)
	opening = move_toward(opening, 1.0 if is_open() else 0.0, delta * 4.0)
	if state == State.DOWN or dormant:
		queue_redraw()
		return
	if sweep_warning > 0.0:
		sweep_warning -= delta
		if sweep_warning <= 0.0:
			attack_fired.emit(Vector2(FACE_X - 20.0, FLOOR_Y - 10.0), -1.0, true)
	left = maxf(0.0, left - delta)
	if left == 0.0:
		_advance()
	queue_redraw()


func _advance() -> void:
	match state:
		State.IDLE:
			volley += 1
			if health == 1:
				# The last phase moves the core every volley and sweeps the deck first.
				high = volley % 2 == 0
				sweep_warning = 0.7
				attack_prepared.emit(true)
			shots_left = 2 if health > 1 else 3
			_enter(State.AIM, AIM_TIME if health > 1 else 0.75)
			attack_prepared.emit(false)
		State.AIM:
			_enter(State.FIRE, 0.0)
			_fire()
		State.FIRE:
			_fire()
		State.OPEN:
			_enter(State.IDLE, 1.1 if health == 3 else 0.9)
		State.RECOVER:
			_enter(State.IDLE, 0.6)


func _fire() -> void:
	if shots_left <= 0:
		_enter(State.OPEN, OPEN_TIME)
		return
	shots_left -= 1
	attack_fired.emit(LOW_CORE + Vector2(-34.0, 0.0), -1.0, false)
	_enter(State.FIRE, 0.55 if health > 1 else 0.45)


func _enter(next_state: State, time: float) -> void:
	state = next_state
	left = time
	duration = time


func _draw() -> void:
	var dead := state == State.DOWN
	# The superstructure: decks of steel up from the foredeck, windows in rows.
	draw_rect(Rect2(FACE_X, 120.0, 330.0, FLOOR_Y - 120.0), STEEL.darkened(0.2) if dead else STEEL)
	draw_rect(Rect2(FACE_X - 20.0, 230.0, 30.0, FLOOR_Y - 230.0), PLATE.darkened(0.35))
	draw_rect(Rect2(FACE_X - 30.0, 110.0, 340.0, 18.0), PLATE)
	for row in 3:
		for column in 4:
			var lit := not dead and int(clock * 0.7 + row * 3 + column) % 5 != 0
			draw_rect(Rect2(FACE_X + 60.0 + column * 52.0, 150.0 + row * 46.0, 34.0, 20.0), Color("#ffcf8a", 0.45 if lit else 0.12))
	# Mast and radar.
	draw_line(Vector2(FACE_X + 200.0, 110.0), Vector2(FACE_X + 200.0, 30.0), PLATE, 4.0)
	var sweep := clock * (0.0 if dead else 2.4)
	draw_line(Vector2(FACE_X + 200.0, 34.0), Vector2(FACE_X + 200.0, 34.0) + Vector2(cos(sweep) * 40.0, sin(sweep) * 6.0), PLATE.lightened(0.2), 5.0)
	_draw_port(LOW_CORE, not high, dead)
	_draw_port(HIGH_CORE, high, dead)
	if sweep_warning > 0.0:
		var heat := 1.0 - sweep_warning / 0.7
		draw_dashed_line(Vector2(FACE_X - 30.0, FLOOR_Y - 10.0), Vector2(0.0, FLOOR_Y - 10.0), Color(RED, 0.3 + 0.45 * heat), 2.0, 10.0)


## A port in the bridge face: mirrored glass that slides aside over the core.
func _draw_port(point: Vector2, holds_core: bool, dead: bool) -> void:
	var box := Rect2(point.x - 34.0, point.y - 32.0, 68.0, 64.0)
	draw_rect(box.grow(4.0), DARK)
	var open: float = opening if holds_core else 0.0
	if holds_core:
		var tint := Color("#5d686e") if dead else (ICE if is_open() else AMBER)
		draw_circle(point, 22.0, DARK)
		draw_circle(point, 16.0, Color(tint, 0.35 + 0.25 * sin(clock * 9.0)))
		draw_arc(point, 22.0, 0.0, TAU, 32, Color(tint, 0.9), 3.0, true)
		if is_open() and state == State.OPEN:
			draw_arc(point, 30.0, -PI * 0.5, -PI * 0.5 + TAU * open_ratio(), 40, Color(ICE, 0.9), 2.6, true)
	else:
		draw_rect(Rect2(point.x - 24.0, point.y - 8.0, 48.0, 16.0), PLATE.darkened(0.3))
	if point == LOW_CORE:
		# The gun in the low port.
		draw_rect(Rect2(point.x - 46.0, point.y - 6.0, 26.0, 12.0), PLATE)
		if state == State.AIM:
			var charge := 1.0 - left / duration if duration > 0.0 else 1.0
			draw_circle(point + Vector2(-48.0, 0.0), 5.0 + 9.0 * charge, Color(ICE, 0.5), true, -1.0, true)
			draw_dashed_line(point + Vector2(-50.0, 0.0), Vector2(0.0, point.y), Color(ICE, 0.2 + 0.5 * charge), 1.6, 12.0)
	# The mirror pane, slid up by `open`.
	var pane := Rect2(box.position.x, box.position.y - box.size.y * open, box.size.x, box.size.y * (1.0 - open))
	if pane.size.y > 1.0 and pane.position.y + pane.size.y > box.position.y:
		var clipped := pane.intersection(box)
		draw_rect(clipped, GLASS.lerp(Color.WHITE, flash * 2.0) if not dead else GLASS.darkened(0.5))
		var sheen := fposmod(clock * 0.5 + point.y * 0.01, 1.0)
		var y := clipped.position.y + clipped.size.y * sheen
		draw_line(Vector2(clipped.position.x + 6.0, y), Vector2(clipped.end.x - 6.0, y - 18.0), Color(Color.WHITE, 0.7), 2.0, true)
