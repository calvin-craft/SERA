extends Node2D

## 투하기. A heavy drone that cruises above Sera, out of a jump's reach, and
## drops canisters on her: blue ones can be caught overhead, red ones burst where
## they land. After each drop it drifts off to one side, where a diagonal
## shockwave (W + release) reaches it; a shot fired down on it from above works
## too. Place the node on the floor under its patrol; it lifts off by itself.

signal attack_prepared(sweep: bool)
signal crashed(origin: Vector2)
signal canister_caught(origin: Vector2, charge: int)
signal canister_burst(point: Vector2, hit_player: bool)

enum State { CRUISE, LOCK, DRIFT, DOWN }

const Sera = preload("res://scripts/sera.gd")
const Canister = preload("res://scripts/canister.gd")
const ALTITUDE := 250.0
const LOCK_TIME := 0.75
const SPEED := 150.0
const SIDE_STEP := 230.0
const HIT_RADIUS := 50.0
const SHELL := Color("#28353d")
const TRIM := Color("#8fa3a9")
const AMBER := Color("#ffb46e")

## The stretch of air it patrols, in world x.
@export var patrol_left := 0.0
@export var patrol_right := 0.0
## What it drops, in order: B is blue (catchable), R is red (bursts).
@export var pattern := "BR"

var target: Sera
var state := State.CRUISE
var left := 1.3
var floor_y := 0.0
var home_x := 0.0
var down := false
var drops := 0
var aim_x := 0.0
var clock := 0.0
var fall := Vector2.ZERO
var cargo: Canister


func _ready() -> void:
	floor_y = position.y
	home_x = position.x
	position.y = floor_y - ALTITUDE
	clock = fposmod(position.x * 0.017, TAU)
	cargo = Canister.new()
	add_child(cargo)
	cargo.caught.connect(func(origin: Vector2, charge: int) -> void: canister_caught.emit(origin, charge))
	cargo.burst.connect(func(point: Vector2, hit: bool) -> void: canister_burst.emit(point, hit))


func reset_foe() -> void:
	state = State.CRUISE
	left = 1.3
	drops = 0
	rotation = 0.0
	position = Vector2(home_x, floor_y - ALTITUDE)
	cargo.clear()
	queue_redraw()


func restore_defeated() -> void:
	down = true
	state = State.DOWN
	visible = false
	cargo.clear()
	set_physics_process(false)


func next_is_red() -> bool:
	return pattern.length() > 0 and pattern[drops % pattern.length()] == "R"


func hit_point() -> Vector2:
	return global_position


func is_locking() -> bool:
	return state == State.LOCK


func take_wave(push: float) -> bool:
	if down:
		return false
	down = true
	state = State.DOWN
	fall = Vector2(push * 260.0, -160.0)
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	left = maxf(0.0, left - delta)
	if is_instance_valid(target):
		cargo.advance(delta, target)
	match state:
		State.CRUISE:
			if _target_near():
				position.x = move_toward(position.x, clampf(target.global_position.x, patrol_left, patrol_right), SPEED * delta)
				if left == 0.0 and absf(position.x - target.global_position.x) < 26.0 and not cargo.falling:
					state = State.LOCK
					left = LOCK_TIME
					attack_prepared.emit(next_is_red())
			else:
				position.x = move_toward(position.x, home_x, SPEED * 0.5 * delta)
		State.LOCK:
			if left == 0.0:
				cargo.drop(global_position + Vector2(0.0, 34.0), floor_y, next_is_red())
				drops += 1
				# Off to one side, where a diagonal shot can reach it.
				var side := -1.0 if position.x > (patrol_left + patrol_right) * 0.5 else 1.0
				aim_x = clampf(position.x + side * SIDE_STEP, patrol_left, patrol_right)
				state = State.DRIFT
				left = 1.9
		State.DRIFT:
			position.x = move_toward(position.x, aim_x, SPEED * 1.2 * delta)
			if left == 0.0:
				state = State.CRUISE
				left = 0.6
		State.DOWN:
			fall.y += 1300.0 * delta
			position += fall * delta
			rotation += 8.0 * delta * signf(fall.x if fall.x != 0.0 else 1.0)
			if position.y >= floor_y - 14.0:
				crashed.emit(Vector2(position.x, floor_y))
				visible = false
				set_physics_process(false)
			queue_redraw()
			return
	position.y = floor_y - ALTITUDE + sin(clock * 2.6) * 6.0
	queue_redraw()


func _target_near() -> bool:
	if not is_instance_valid(target) or target.integrity <= 0:
		return false
	return absf(target.global_position.y - floor_y) < 140.0 \
		and target.global_position.x > patrol_left - 260.0 and target.global_position.x < patrol_right + 260.0


func _draw() -> void:
	var lamp := AMBER
	if state == State.LOCK:
		lamp = Canister.RED if next_is_red() else Canister.ICE
	elif state == State.DOWN:
		lamp = Color("#5d686e")
	# Four rotors on two booms.
	for arm in [-1.0, 1.0]:
		draw_line(Vector2(arm * 18.0, -14.0), Vector2(arm * 58.0, -22.0), SHELL, 6.0, true)
		draw_set_transform(Vector2(arm * 60.0, -27.0), 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 28.0, Color(TRIM, 0.15))
		draw_arc(Vector2.ZERO, 28.0, clock * 29.0, clock * 29.0 + 2.2, 14, Color(TRIM, 0.55), 5.0, true)
		draw_set_transform(Vector2.ZERO)
	# Belly with the clamp that holds the canister.
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -18), Vector2(34, -18), Vector2(40, 0), Vector2(24, 16),
		Vector2(-24, 16), Vector2(-40, 0)]), SHELL)
	draw_polyline(PackedVector2Array([Vector2(-34, -18), Vector2(34, -18), Vector2(40, 0)]), TRIM, 1.6, true)
	draw_rect(Rect2(-14.0, -8.0, 28.0, 10.0), Color("#131d23"))
	draw_circle(Vector2(0.0, -3.0), 4.0, lamp)
	if state == State.CRUISE and not cargo.falling and left < 0.4 or state == State.LOCK:
		Canister.draw_canister(self, Vector2(0.0, 40.0), next_is_red(), clock)
	if state == State.LOCK:
		var charge := 1.0 - left / LOCK_TIME
		var tint := Canister.RED if next_is_red() else Canister.ICE
		var ground := floor_y - position.y
		draw_dashed_line(Vector2(0.0, 64.0), Vector2(0.0, ground), Color(tint, 0.25 + 0.4 * charge), 1.6, 9.0)
		draw_arc(Vector2(0.0, ground - 6.0), 34.0 - 14.0 * charge, PI, TAU, 24, Color(tint, 0.7), 2.0, true)
