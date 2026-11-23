extends Node2D

## 추적탄 발사기. An armoured box of missile tubes on a deck or a ledge. When
## Sera comes into its field it opens a tube and fires a homing missile, one
## at a time. Shockwaves glance off the armour; a missile reflected home, or
## any other reflected shot, wrecks it. The node sits on the deck under it.

signal attack_prepared(sweep: bool)
signal missile_launched(origin: Vector2, launcher: Node2D)
signal crashed(origin: Vector2)

enum State { WAIT, AIM, DOWN }

const Sera = preload("res://scripts/sera.gd")
const WINDUP := 0.85
const HIT_RADIUS := 52.0
const STEEL := Color("#2a363c")
const PLATE := Color("#56666c")
const DARK := Color("#0f181d")
const LAMP := Color("#ff7350")
const ICE := Color("#7ce9ff")

## Which way the tubes lean: -1 to the left, 1 to the right.
@export var facing := -1.0
@export var rest := 2.6
@export var reach := 820.0
@export var depth := 360.0

var target: Sera
var state := State.WAIT
var left := 1.0
var down := false
var home := Vector2.ZERO
var clock := 0.0
var tumble := Vector2.ZERO
var flash := 0.0
## The missile in the air, if any: it fires again only once that one is gone.
var missile: Node2D


func _ready() -> void:
	home = position


func reset_foe() -> void:
	state = State.WAIT
	left = 1.0
	rotation = 0.0
	position = home
	missile = null
	queue_redraw()


func restore_defeated() -> void:
	down = true
	state = State.DOWN
	visible = false
	set_physics_process(false)


func hit_point() -> Vector2:
	return global_position + Vector2(0.0, -48.0)


func muzzle() -> Vector2:
	return global_position + Vector2(facing * 26.0, -92.0)


func is_aiming() -> bool:
	return state == State.AIM


## Armour turns a shockwave: it only shows a spark.
func glance() -> void:
	flash = 0.3


func take_hit(push: float) -> bool:
	if down:
		return false
	down = true
	state = State.DOWN
	left = 1.2
	tumble = Vector2(push * 220.0, -360.0)
	crashed.emit(hit_point())
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta)
	left = maxf(0.0, left - delta)
	match state:
		State.WAIT:
			if left == 0.0 and not is_instance_valid(missile) and _sees_target():
				state = State.AIM
				left = WINDUP
				attack_prepared.emit(false)
		State.AIM:
			if left == 0.0:
				state = State.WAIT
				left = rest
				missile_launched.emit(muzzle(), self)
		State.DOWN:
			tumble.y += 1300.0 * delta
			position += tumble * delta
			rotation += 5.0 * delta * signf(tumble.x if tumble.x != 0.0 else 1.0)
			if left == 0.0:
				visible = false
				set_physics_process(false)
	queue_redraw()


func _sees_target() -> bool:
	if not is_instance_valid(target) or target.integrity <= 0:
		return false
	var offset := target.global_position - global_position
	return offset.x * facing > -60.0 and absf(offset.x) < reach and absf(offset.y) < depth


func _draw() -> void:
	# A squat armoured box, four tubes leaning toward its field, a little dish.
	draw_rect(Rect2(-38.0, -64.0, 76.0, 64.0), STEEL)
	draw_rect(Rect2(-38.0, -64.0, 76.0, 6.0), PLATE)
	draw_rect(Rect2(-44.0, -10.0, 88.0, 10.0), DARK)
	for row in 2:
		for column in 2:
			var tube := Vector2(-14.0 + column * 26.0 + facing * 6.0, -86.0 + row * 20.0)
			draw_set_transform(tube, facing * 0.35, Vector2.ONE)
			draw_rect(Rect2(-10.0, -9.0, 20.0, 18.0), PLATE.darkened(0.2))
			draw_circle(Vector2.ZERO, 6.0, DARK)
			var open := state == State.AIM and row == 0 and column == (1 if facing > 0.0 else 0)
			if open:
				var charge := 1.0 - left / WINDUP
				draw_circle(Vector2.ZERO, 4.0 + 4.0 * charge, Color(LAMP, 0.5 + 0.5 * charge), true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-facing * 26.0, -64.0), Vector2(-facing * 30.0, -104.0), PLATE, 3.0)
	draw_arc(Vector2(-facing * 30.0, -108.0), 12.0, PI * 0.15, PI * 0.85, 12, PLATE, 3.0)
	var lamp := Color("#5d686e") if down else (LAMP if state == State.AIM or is_instance_valid(missile) else Color("#ffb46e"))
	draw_circle(Vector2(-facing * 22.0, -40.0), 4.5, lamp)
	if flash > 0.0:
		draw_rect(Rect2(-40.0, -66.0, 80.0, 68.0), Color(ICE, flash * 1.6), false, 3.0)
	if state == State.AIM:
		var charge := 1.0 - left / WINDUP
		draw_arc(Vector2(0.0, -60.0), 70.0 - 30.0 * charge, 0.0, TAU, 40, Color(LAMP, 0.25 + 0.4 * charge), 2.0, true)
