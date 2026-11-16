extends Node2D

## 호버 드론. It hangs out of reach overhead, keeping its distance, then drops
## to chest height to fire one absorbable bolt before climbing away. A shockwave
## brings it down: straight ahead while it is low, or diagonally up (W + release)
## while it hovers. Place the node on the floor under its patrol; it lifts off
## by itself.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal crashed(origin: Vector2)

enum State { HOVER, DIVE, AIM, LINGER, RISE, DOWN }

const Sera = preload("res://scripts/sera.gd")
const ART := "res://assets/characters/drone.png"
const HOVER_HEIGHT := 235.0
const FIRE_HEIGHT := 85.0
const STANDOFF := 250.0
const DRIFT := 110.0
const HIT_RADIUS := 46.0
const LINGER_TIME := 1.0
const ICE := Color("#7ce9ff")
const AMBER := Color("#ffb46e")
const SHELL := Color("#2a3942")
const TRIM := Color("#8fa3a9")

## The stretch of air it patrols, in world x.
@export var patrol_left := 0.0
@export var patrol_right := 0.0

var target: Sera
var state := State.HOVER
var left := 1.2
var floor_y := 0.0
var home_x := 0.0
var altitude := HOVER_HEIGHT
var direction := -1.0
var down := false
var clock := 0.0
var fall := Vector2.ZERO
var art: Texture2D


func _ready() -> void:
	floor_y = position.y
	home_x = position.x
	position.y = floor_y - altitude
	clock = fposmod(position.x * 0.013, TAU)
	if ResourceLoader.exists(ART):
		art = load(ART)


func reset_foe() -> void:
	state = State.HOVER
	left = 1.2
	altitude = HOVER_HEIGHT
	rotation = 0.0
	position = Vector2(home_x, floor_y - altitude)
	queue_redraw()


func restore_defeated() -> void:
	down = true
	state = State.DOWN
	visible = false
	set_physics_process(false)


func is_low() -> bool:
	return state == State.AIM or state == State.LINGER


func hit_point() -> Vector2:
	return global_position


func take_wave(push: float) -> bool:
	down = true
	state = State.DOWN
	fall = Vector2(push * 300.0, -230.0)
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	left = maxf(0.0, left - delta)
	match state:
		State.HOVER:
			_drift(delta)
			if left == 0.0 and _in_reach():
				state = State.DIVE
				left = 0.5
		State.DIVE:
			altitude = lerpf(FIRE_HEIGHT, HOVER_HEIGHT, smoothstep(0.0, 0.5, left))
			if left == 0.0:
				direction = signf(target.global_position.x - global_position.x) if is_instance_valid(target) else -1.0
				if direction == 0.0:
					direction = -1.0
				state = State.AIM
				left = 0.62
				attack_prepared.emit(false)
		State.AIM:
			if left == 0.0:
				attack_fired.emit(global_position + Vector2(direction * 24.0, 0.0), direction, false)
				# Long enough to catch the bolt and answer with a shockwave before it climbs.
				state = State.LINGER
				left = LINGER_TIME
		State.LINGER:
			if left == 0.0:
				state = State.RISE
				left = 0.55
		State.RISE:
			altitude = lerpf(HOVER_HEIGHT, FIRE_HEIGHT, smoothstep(0.0, 0.55, left))
			if left == 0.0:
				state = State.HOVER
				left = 1.7
		State.DOWN:
			fall.y += 1300.0 * delta
			position += fall * delta
			rotation += 9.0 * delta * signf(fall.x if fall.x != 0.0 else 1.0)
			if position.y >= floor_y - 12.0:
				crashed.emit(Vector2(position.x, floor_y))
				visible = false
				set_physics_process(false)
			queue_redraw()
			return
	position.y = floor_y - altitude + (sin(clock * 3.1) * 5.0 if state == State.HOVER else 0.0)
	queue_redraw()


func _in_reach() -> bool:
	if not is_instance_valid(target) or target.integrity <= 0:
		return false
	var gap := absf(target.global_position.x - global_position.x)
	return absf(target.global_position.y - floor_y) < 130.0 and gap > 120.0 and gap < 540.0


func _drift(delta: float) -> void:
	if not is_instance_valid(target) or absf(target.global_position.y - floor_y) > 130.0 \
			or absf(target.global_position.x - global_position.x) > 640.0:
		position.x = move_toward(position.x, home_x, DRIFT * 0.5 * delta)
		return
	var side := signf(global_position.x - target.global_position.x)
	if side == 0.0:
		side = 1.0
	var wanted := clampf(target.global_position.x + side * STANDOFF, patrol_left, patrol_right)
	position.x = move_toward(position.x, wanted, DRIFT * delta)
	direction = -side


func _draw() -> void:
	if art:
		var size := Vector2(120.0, 120.0 * art.get_height() / art.get_width())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-direction, 1.0))
		draw_texture_rect(art, Rect2(-size * 0.5, size), false)
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_body()
	if state == State.AIM:
		var charge := 1.0 - left / 0.62
		var muzzle := Vector2(direction * 26.0, 0.0)
		draw_dashed_line(muzzle, muzzle + Vector2(direction * 480.0, 0.0), Color(ICE, 0.25 + 0.4 * charge), 1.4, 10.0)
		draw_circle(muzzle, 6.0 + 8.0 * charge, Color(ICE, 0.5), true, -1.0, true)
		draw_arc(muzzle, 20.0 - 9.0 * charge, 0.0, TAU, 26, Color(ICE, 0.75), 2.0, true)


func _draw_body() -> void:
	var lamp := AMBER if state == State.HOVER or state == State.RISE else ICE
	if state == State.DOWN:
		lamp = Color("#5d686e")
	# Rotor arms and blurred discs.
	for arm in [-1.0, 1.0]:
		draw_line(Vector2(arm * 12.0, -8.0), Vector2(arm * 42.0, -17.0), SHELL, 5.0, true)
		draw_set_transform(Vector2(arm * 44.0, -21.0), 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 24.0, Color(TRIM, 0.16))
		draw_arc(Vector2.ZERO, 24.0, clock * 31.0, clock * 31.0 + 2.2, 14, Color(TRIM, 0.55), 5.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(arm * 44.0 - 3.0, -22.0, 6.0, 7.0), Color("#172229"))
	# Pod.
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -10), Vector2(22, -10), Vector2(27, 2), Vector2(14, 16), Vector2(-14, 16), Vector2(-27, 2)]), SHELL)
	draw_polyline(PackedVector2Array([Vector2(-22, -10), Vector2(22, -10), Vector2(27, 2)]), TRIM, 1.6, true)
	draw_rect(Rect2(-12, -4, 24, 9), Color("#131d23"))
	draw_circle(Vector2(direction * 13.0, 1.0), 6.0, Color(lamp, 0.35))
	draw_circle(Vector2(direction * 13.0, 1.0), 3.5, lamp)
	draw_rect(Rect2(direction * 20.0 - 5.0, -3.0, 10.0, 7.0), Color("#172229"))
	draw_line(Vector2(-8, 16), Vector2(-11, 23), TRIM.darkened(0.3), 2.0)
	draw_line(Vector2(8, 16), Vector2(11, 23), TRIM.darkened(0.3), 2.0)
