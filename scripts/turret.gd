extends Node2D

## 포대. A gun bolted to a deck or a ledge. When Sera comes into its field it
## aims, then fires a short burst of bolts straight ahead at muzzle height: low
## ones she can catch standing, high ones only in the air. One shockwave on the
## housing wrecks it. The node sits on the deck under the gun.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal crashed(origin: Vector2)

enum State { WAIT, AIM, FIRE, DOWN }

const Sera = preload("res://scripts/sera.gd")
const WINDUP := 0.62
const HIT_RADIUS := 44.0
const ICE := Color("#7ce9ff")
const STEEL := Color("#263840")
const TRIM := Color("#7d949a")
const DARK := Color("#101a20")

## Which way it fires: -1 to the left, 1 to the right.
@export var facing := -1.0
## Muzzle height above the deck. 85 meets a standing Sera at the chest; 140
## passes over her head and has to be caught in the air.
@export var muzzle_height := 85.0
@export var burst := 2
@export var spacing := 0.34
@export var rest := 1.7
## How far ahead, and how far above or below, it notices Sera.
@export var reach := 640.0
@export var depth := 220.0
## 거울 포대: a mirror over the gun's face turns a shockwave that meets it head
## on back at Sera. Its own bolts reflected into it break it, and so does a
## shockwave from behind or from above.
@export var mirror := false

var target: Sera
var mirror_flash := 0.0
var state := State.WAIT
var left := 0.9
var shots_left := 0
var down := false
var home := Vector2.ZERO
var clock := 0.0
var tumble := Vector2.ZERO


func _ready() -> void:
	home = position


func reset_foe() -> void:
	state = State.WAIT
	left = 0.9
	shots_left = 0
	rotation = 0.0
	position = home
	queue_redraw()


func restore_defeated() -> void:
	down = true
	state = State.DOWN
	visible = false
	set_physics_process(false)


func head_point() -> Vector2:
	return global_position + Vector2(0.0, -muzzle_height)


## Low on the housing, where a shot from the same deck lands.
func base_point() -> Vector2:
	return global_position + Vector2(0.0, -minf(muzzle_height, 89.0))


func is_aiming() -> bool:
	return state == State.AIM


## True when a shockwave travelling along `wave` meets the mirror face.
func mirror_blocks(wave: Vector2) -> bool:
	return mirror and not down and wave.y < 0.5 and wave.x != 0.0 and signf(wave.x) == -facing


func flash_mirror() -> void:
	mirror_flash = 0.35


func take_wave(push: float) -> bool:
	if down:
		return false
	down = true
	state = State.DOWN
	left = 1.1
	tumble = Vector2(push * 230.0, -330.0)
	crashed.emit(head_point())
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	left = maxf(0.0, left - delta)
	mirror_flash = maxf(0.0, mirror_flash - delta)
	match state:
		State.WAIT:
			if left == 0.0 and _sees_target():
				state = State.AIM
				left = WINDUP
				attack_prepared.emit(false)
		State.AIM:
			if left == 0.0:
				state = State.FIRE
				shots_left = burst
		State.FIRE:
			if left == 0.0:
				attack_fired.emit(head_point() + Vector2(facing * (60.0 if mirror else 34.0), 0.0), facing, false)
				shots_left -= 1
				if shots_left > 0:
					left = spacing
				else:
					state = State.WAIT
					left = rest
		State.DOWN:
			tumble.y += 1300.0 * delta
			position += tumble * delta
			rotation += 6.0 * delta * signf(tumble.x if tumble.x != 0.0 else 1.0)
			if left == 0.0:
				visible = false
				set_physics_process(false)
	queue_redraw()


func _sees_target() -> bool:
	if not is_instance_valid(target) or target.integrity <= 0:
		return false
	var offset := target.global_position - global_position
	return offset.x * facing > 40.0 and absf(offset.x) < reach and absf(offset.y) < depth


func _draw() -> void:
	var top := -muzzle_height
	# Pedestal and the housing that turns on it.
	draw_rect(Rect2(-16.0, top + 14.0, 32.0, -top - 14.0), STEEL)
	draw_rect(Rect2(-24.0, -12.0, 48.0, 12.0), DARK)
	draw_line(Vector2(-12.0, top + 22.0), Vector2(-12.0, -14.0), TRIM.darkened(0.4), 2.0)
	draw_rect(Rect2(-26.0, top - 18.0, 52.0, 34.0), STEEL)
	draw_rect(Rect2(-26.0, top - 18.0, 52.0, 4.0), TRIM)
	draw_rect(Rect2(facing * 20.0 - (0.0 if facing > 0.0 else 22.0), top - 7.0, 22.0, 12.0), DARK)
	var lamp := Color("#5d686e") if down else (ICE if state != State.WAIT else Color("#ffb46e"))
	draw_circle(Vector2(-facing * 12.0, top - 2.0), 4.0, lamp)
	if mirror and not down:
		# A tall mirror plate in front of the housing, the gun peering past its top.
		var face := facing * 44.0
		var plate := Rect2(face - 7.0, top - 34.0, 14.0, -top + 22.0)
		draw_rect(plate.grow(2.0), DARK)
		draw_rect(plate, Color("#b9d3da").lerp(Color.WHITE, mirror_flash * 2.0))
		var sheen := fposmod(clock * 0.6, 1.0)
		draw_line(Vector2(face - 6.0, plate.position.y + plate.size.y * sheen), Vector2(face + 6.0, plate.position.y + plate.size.y * sheen - 16.0),
			Color(Color.WHITE, 0.75), 2.0, true)
		draw_line(Vector2(face - facing * 9.0, top - 30.0), Vector2(face - facing * 9.0, -10.0), TRIM, 2.0)
		if mirror_flash > 0.0:
			draw_arc(Vector2(face, top + 10.0), 30.0 + (0.35 - mirror_flash) * 90.0, 0.0, TAU, 32, Color(Color.WHITE, mirror_flash * 2.0), 2.5, true)
	if state == State.AIM:
		var charge := 1.0 - left / WINDUP
		var muzzle := Vector2(facing * 36.0, top)
		draw_dashed_line(muzzle, muzzle + Vector2(facing * 520.0, 0.0), Color(ICE, 0.22 + 0.45 * charge), 1.4, 10.0)
		draw_circle(muzzle, 5.0 + 8.0 * charge, Color(ICE, 0.5), true, -1.0, true)
		draw_arc(muzzle, 19.0 - 9.0 * charge, 0.0, TAU, 26, Color(ICE, 0.75), 2.0, true)
