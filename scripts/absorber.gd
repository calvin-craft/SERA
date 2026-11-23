extends Node2D

## 흡수 경비. A heavy suit with a disc on its chest that drinks force, built on
## the same idea as Echo's prototype. Its own bolts come at chest height, to be
## caught or turned back. Whatever strikes the disc (a shockwave from any side,
## a reflected bolt) is drunk, and a moment later it fires it all back as a
## heavy amber shell. Reflect that shell into it and it goes down; catching it
## instead fills the suit. The node sits on the deck under its feet.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal echo_fired(origin: Vector2, direction: float, guard: Node2D)
signal drank(origin: Vector2)
signal crashed(origin: Vector2)

enum State { WATCH, AIM, CHARGE, RECOVER, STAGGER, DOWN }

const Sera = preload("res://scripts/sera.gd")
const AIM_TIME := 0.8
const CHARGE_TIME := 0.95
const HIT_RADIUS := 62.0
const CHEST := 96.0
const STEEL := Color("#2c3338")
const PLATE := Color("#69757a")
const DARK := Color("#11181c")
const AMBER := Color("#ffae66")
const ICE := Color("#7ce9ff")

## Two reflected shells to bring down instead of one.
@export var reinforced := false
## Sera has to be past this world x before it starts shooting.
@export var arena_start := 0.0
@export var rest := 1.9

var target: Sera
var state := State.WATCH
var left := 1.0
var down := false
var integrity := 1
var facing := -1.0
var home := Vector2.ZERO
var clock := 0.0
var glow := 0.0
var tumble := Vector2.ZERO


func _ready() -> void:
	home = position
	reset_foe()


func reset_foe() -> void:
	state = State.WATCH
	left = 1.0
	integrity = 2 if reinforced else 1
	glow = 0.0
	rotation = 0.0
	position = home
	modulate.a = 1.0
	queue_redraw()


func restore_defeated() -> void:
	down = true
	state = State.DOWN
	visible = false
	set_physics_process(false)


func chest_point() -> Vector2:
	return global_position + Vector2(0.0, -CHEST)


func is_charging() -> bool:
	return state == State.CHARGE


func is_aiming() -> bool:
	return state == State.AIM


## Force struck the disc: it is drunk and comes back as a shell.
func drink(from_x: float) -> void:
	if down:
		return
	if from_x != global_position.x:
		facing = signf(from_x - global_position.x)
	if state != State.CHARGE:
		state = State.CHARGE
		left = CHARGE_TIME
	glow = 1.0
	drank.emit(chest_point())


## A reflected shell: the disc cannot drink its own force twice.
func take_hit(push: float) -> bool:
	if down:
		return false
	integrity -= 1
	if integrity > 0:
		state = State.STAGGER
		left = 0.9
		glow = 0.0
		return true
	down = true
	state = State.DOWN
	left = 1.1
	glow = 0.0
	tumble = Vector2(push * 260.0, -360.0)
	crashed.emit(chest_point())
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	left = maxf(0.0, left - delta)
	glow = move_toward(glow, 1.0 if state == State.CHARGE else 0.0, delta * 2.0)
	match state:
		State.WATCH:
			if _engaged():
				facing = signf(target.global_position.x - global_position.x) if target.global_position.x != global_position.x else facing
				if left == 0.0 and absf(target.global_position.x - global_position.x) < 540.0:
					state = State.AIM
					left = AIM_TIME
					attack_prepared.emit(false)
		State.AIM:
			if left == 0.0:
				attack_fired.emit(chest_point() + Vector2(facing * 42.0, 10.0), facing, false)
				state = State.RECOVER
				left = rest
		State.CHARGE:
			if is_instance_valid(target) and target.global_position.x != global_position.x:
				facing = signf(target.global_position.x - global_position.x)
			if left == 0.0:
				echo_fired.emit(chest_point() + Vector2(facing * 46.0, 10.0), facing, self)
				state = State.RECOVER
				left = 1.3
		State.RECOVER, State.STAGGER:
			if left == 0.0:
				state = State.WATCH
				left = 0.4
		State.DOWN:
			tumble.y += 1300.0 * delta
			position += tumble * delta
			rotation += 3.0 * delta * signf(tumble.x if tumble.x != 0.0 else 1.0)
			modulate.a = clampf(left / 0.4, 0.0, 1.0)
			if left == 0.0:
				visible = false
				set_physics_process(false)
	queue_redraw()


func _engaged() -> bool:
	if not is_instance_valid(target) or target.integrity <= 0 or target.global_position.x < arena_start:
		return false
	var offset := target.global_position - global_position
	return absf(offset.x) < 680.0 and absf(offset.y) < 180.0


func _draw() -> void:
	var f := facing
	var bulk := 1.12 if reinforced else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(bulk, bulk))
	# Legs and boots.
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * 16.0 - 10.0, -58.0, 20.0, 52.0), STEEL)
		draw_rect(Rect2(side * 16.0 - 14.0 + f * 4.0, -10.0, 28.0, 10.0), DARK)
	# Torso, shoulders and the backpack that stores what it drinks.
	draw_rect(Rect2(-34.0 - f * 6.0, -138.0, 68.0, 84.0), STEEL)
	draw_rect(Rect2(-f * 46.0 - 12.0, -134.0, 24.0, 64.0), DARK.lightened(0.05))
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * 30.0 - 14.0, -146.0, 28.0, 20.0), PLATE)
	# Arms forward, hands open: it is always ready to catch.
	draw_line(Vector2(f * 28.0, -124.0), Vector2(f * 50.0, -96.0), PLATE, 10.0)
	draw_circle(Vector2(f * 52.0, -94.0), 7.0, PLATE.darkened(0.2))
	# Head with a slit visor.
	draw_rect(Rect2(-15.0, -172.0, 30.0, 28.0), STEEL.lightened(0.05))
	draw_rect(Rect2(f * 2.0 - 10.0 + f * 4.0, -162.0, 20.0, 5.0), Color(AMBER, 0.85))
	# The chest disc: dull at rest, amber while it holds what it drank.
	var disc := Vector2(f * 8.0, -CHEST)
	var pulse := 0.5 + 0.5 * sin(clock * 16.0)
	draw_circle(disc, 21.0, DARK)
	draw_circle(disc, 16.0, Color("#3b2f28").lerp(AMBER, glow * (0.6 + 0.4 * pulse)))
	draw_arc(disc, 21.0, 0.0, TAU, 32, PLATE, 3.0, true)
	if glow > 0.05:
		draw_circle(disc, 30.0 + 12.0 * glow, Color(AMBER, 0.18 * glow), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	# Plates for the shells it still takes.
	for index in (2 if reinforced else 1):
		var panel := Rect2(index * 22.0 - (21.0 if reinforced else 10.0), -196.0, 19.0, 5.0)
		draw_rect(panel.grow(2.0), Color("#172029"))
		draw_rect(panel, AMBER if index < integrity else Color("#4b4544"))
	if state == State.AIM:
		var charge := 1.0 - left / AIM_TIME
		var muzzle := Vector2(f * 42.0, -CHEST + 10.0)
		draw_dashed_line(muzzle, muzzle + Vector2(f * 520.0, 0.0), Color(ICE, 0.25 + 0.45 * charge), 1.4, 10.0)
		draw_circle(muzzle, 5.0 + 8.0 * charge, Color(ICE, 0.45), true, -1.0, true)
	elif state == State.CHARGE:
		var charge := 1.0 - left / CHARGE_TIME
		var muzzle := Vector2(f * 46.0, -CHEST + 10.0)
		draw_dashed_line(muzzle, muzzle + Vector2(f * 560.0, 0.0), Color(AMBER, 0.3 + 0.5 * charge), 2.4, 12.0)
		draw_arc(muzzle, 30.0 - 16.0 * charge, 0.0, TAU, 30, Color(AMBER, 0.8), 2.5, true)
