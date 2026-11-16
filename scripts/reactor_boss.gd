extends Node2D

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal press_impact(point: Vector2, hit_player: bool)

enum State { INTERVAL, PRESS_WARNING, PRESS_FALL, PRESS_RETURN, SWEEP_WARNING, SWEEP_TRANSIT, BOLT_WARNING, BOLT_TRANSIT, OPEN, DOWN }

const Sera = preload("res://scripts/sera.gd")
const CORE_HITS := 3
const OPEN_TIME := 2.65
const CORE_WIDTH := 44.0
const HIGH_Y := -255.0
const LOW_Y := -89.0
const CORE_X := -75.0
const PORT_X := -177.0
const PRESS_HALF := 76.0
const GOLD := Color("#ffc186")
const RED := Color("#ff7251")
const ICE := Color("#84ebff")
const WHITE_HOT := Color("#fff1d7")
const STEEL := Color("#26343b")
const BLACK := Color("#101b21")

var player: Sera
var health := CORE_HITS
var state := State.INTERVAL
var state_left := 0.85
var state_duration := 0.85
var core_y := HIGH_Y
var shield_flash := 0.0
var press_x := 0.0
var clock := 0.0
var dormant := false

@onready var casing: Sprite2D = $Casing


func _ready() -> void:
	casing.position.y = -casing.texture.get_height() * 0.5 + 1.0


func reset_attempt() -> void:
	# Defeated phases are checkpoint progress. An attack in flight never survives a retry.
	shield_flash = 0.0
	press_x = 0.0
	core_y = LOW_Y if health == 2 else HIGH_Y
	if health > 0:
		_enter(State.INTERVAL, 1.4)
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true
		_enter(State.INTERVAL, 0.0)


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	_enter(State.INTERVAL, 1.3)
	return true


func is_open() -> bool:
	return state == State.OPEN


func needs_aim_up() -> bool:
	return health != 2


func core_point() -> Vector2:
	return global_position + Vector2(CORE_X, core_y)


func open_from_catch() -> bool:
	if state != State.BOLT_TRANSIT:
		return false
	_enter(State.OPEN, OPEN_TIME)
	queue_redraw()
	return true


func hit_core() -> bool:
	if not is_open():
		shield_flash = 0.30
		queue_redraw()
		return false
	health -= 1
	if health == 0:
		_enter(State.DOWN, 0.0)
	else:
		_enter(State.INTERVAL, 0.98)
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	shield_flash = maxf(0.0, shield_flash - delta)
	if state == State.DOWN:
		casing.self_modulate = casing.self_modulate.lerp(Color("#6b7779"), minf(1.0, 3.2 * delta))
		queue_redraw()
		return
	core_y = move_toward(core_y, HIGH_Y if needs_aim_up() else LOW_Y, 299.0 * delta)
	if dormant:
		queue_redraw()
		return
	state_left = maxf(0.0, state_left - delta)
	if state_left == 0.0:
		_advance_attack()
	queue_redraw()


func _advance_attack() -> void:
	match state:
		State.INTERVAL:
			if health == 1:
				press_x = player.global_position.x
				_enter(State.PRESS_WARNING, 0.88)
				attack_prepared.emit(true)
			elif health == 2:
				_warn_sweep()
			else:
				_warn_bolt()
		State.PRESS_WARNING:
			_enter(State.PRESS_FALL, 0.23)
		State.PRESS_FALL:
			_land_press()
		State.PRESS_RETURN:
			_warn_sweep()
		State.SWEEP_WARNING:
			_enter(State.SWEEP_TRANSIT, 1.10)
			attack_fired.emit(global_position + Vector2(PORT_X, -10), -1.0, true)
		State.SWEEP_TRANSIT:
			_warn_bolt()
		State.BOLT_WARNING:
			_enter(State.BOLT_TRANSIT, 1.58)
			attack_fired.emit(global_position + Vector2(PORT_X, -85), -1.0, false)
		State.BOLT_TRANSIT, State.OPEN:
			_enter(State.INTERVAL, 0.56)


func _warn_sweep() -> void:
	_enter(State.SWEEP_WARNING, 0.78)
	attack_prepared.emit(true)


func _warn_bolt() -> void:
	_enter(State.BOLT_WARNING, 0.71)
	attack_prepared.emit(false)


func _land_press() -> void:
	_enter(State.PRESS_RETURN, 0.57)
	var distance := player.global_position.x - press_x
	var hit := false
	if absf(distance) < PRESS_HALF + 8.0 and player.global_position.y > global_position.y - 100.0:
		hit = player.take_hit(-1.0 if distance <= 0.0 else 1.0)
	press_impact.emit(Vector2(press_x, global_position.y), hit)


func _enter(next_state: State, duration: float) -> void:
	state = next_state
	state_left = duration
	state_duration = duration


func _draw() -> void:
	_draw_core_rail()
	if state == State.PRESS_WARNING or state == State.PRESS_FALL or state == State.PRESS_RETURN:
		_draw_press()
	if state == State.SWEEP_WARNING or state == State.BOLT_WARNING:
		_draw_shot_warning(state == State.SWEEP_WARNING)


func _draw_core_rail() -> void:
	var point := Vector2(CORE_X, core_y)
	var warning_tint := Color("#ff9870")
	var tint := ICE if is_open() else warning_tint
	if state == State.DOWN:
		tint = Color("#5d686e")
	var rail := Rect2(CORE_X - 12.0, HIGH_Y - 36.0, 25.0, LOW_Y - HIGH_Y + 72.0)
	draw_rect(rail, BLACK)
	draw_rect(rail.grow(-4.0), STEEL)
	draw_line(Vector2(rail.position.x + 4, rail.position.y), Vector2(rail.position.x + 4, rail.end.y), Color("#88969b"), 1.7, true)
	for y in range(int(HIGH_Y) - 26, int(LOW_Y) + 30, 16):
		draw_line(Vector2(CORE_X - 6, y), Vector2(CORE_X + 5, y), Color("#61747c"), 1.5)
	draw_circle(point, 37.0, BLACK, true, -1.0, true)
	draw_circle(point, 32.0, Color("#3e4b4d"), true, -1.0, true)
	draw_arc(point, 32.0, 0.0, TAU, 42, Color("#b2a19a"), 1.8, true)
	draw_circle(point, 23.0, Color(tint, 0.34), true, -1.0, true)
	if is_open():
		var breathe := 0.58 + sin(clock * 16.0) * 0.18
		draw_arc(point, 43.0, -PI * 0.5, -PI * 0.5 + TAU * state_left / OPEN_TIME, 52, Color(ICE, 0.9), 2.8, true)
		draw_circle(point, 17.0 + 5.0 * breathe, Color(ICE, breathe), true, -1.0, true)
		draw_circle(point, 9.0 + breathe * 3.0, Color("#ecffff"), true, -1.0, true)
	else:
		draw_line(point + Vector2(-18, -5), point + Vector2(17, -5), tint, 3.2, true)
		draw_line(point + Vector2(-14, 5), point + Vector2(13, 5), Color(tint, 0.54), 2.1, true)
		if shield_flash > 0.0:
			draw_arc(point, 36.0 + (0.3 - shield_flash) * 86.0, -PI, PI, 48, Color(GOLD, shield_flash * 2.5), 3.0, true)


func _draw_shot_warning(sweep: bool) -> void:
	var charge := 1.0 - state_left / state_duration
	var point := Vector2(PORT_X, -10.0 if sweep else -85.0)
	var tint := RED if sweep else ICE
	draw_dashed_line(point, point - Vector2(812, 0), Color(tint, 0.31 + charge * 0.43), 2.0, 10.0)
	draw_circle(point, 7.0 + charge * 8.0, Color(tint, 0.56), true, -1.0, true)
	draw_arc(point, 21.0 - charge * 7.0, 0.0, TAU, 32, tint, 2.0, true)


func _draw_press() -> void:
	var x := press_x - global_position.x
	var fraction := 1.0 - state_left / state_duration
	var y := -348.0
	if state == State.PRESS_FALL:
		y = lerpf(-348.0, -55.0, fraction * fraction)
	elif state == State.PRESS_RETURN:
		y = lerpf(-55.0, -350.0, smoothstep(0.24, 1.0, fraction))
	var opacity := 0.1 if state == State.PRESS_RETURN else 0.21 + sin(clock * 21.0) * 0.1
	draw_rect(Rect2(x - PRESS_HALF, -345.0, PRESS_HALF * 2.0, 345.0), Color(RED, opacity * 0.35))
	draw_rect(Rect2(x - PRESS_HALF, -16.0, PRESS_HALF * 2.0, 15.0), Color(RED, opacity))
	for slide in range(-68, 66, 17):
		draw_line(Vector2(x + slide, -2), Vector2(x + slide + 8, -14), Color(RED, opacity * 2.7), 3.0, true)
	for rod in [-33.0, 33.0]:
		draw_rect(Rect2(x + rod - 5.0, -489.0, 10.0, y + 489.0), BLACK)
		draw_line(Vector2(x + rod + 2.0, -487), Vector2(x + rod + 2.0, y), Color("#a48170"), 2.0, true)
	draw_rect(Rect2(x - PRESS_HALF, y, PRESS_HALF * 2.0, 52.0), STEEL)
	draw_rect(Rect2(x - PRESS_HALF + 6, y + 6, PRESS_HALF * 2.0 - 12, 7.0), Color("#74818a"))
	draw_rect(Rect2(x - PRESS_HALF + 1, y + 44, PRESS_HALF * 2.0 - 2, 6), Color(RED, 0.84))
	for slide in range(-63, 64, 20):
		draw_line(Vector2(x + slide, y + 35.0), Vector2(x + slide + 8, y + 17.0), BLACK, 5.0, true)
