extends Node2D

## 돌격 기체. A low armoured sled that lines up on Sera and charges along its
## run. Its front plate shrugs off shockwaves; the answer is to face it, brace
## and take the charge. That stops it dead, hands over a lot of momentum, and
## leaves it stunned and open to a shockwave. It can also be jumped.

signal attack_prepared(sweep: bool)
signal precision_ready
signal caught(origin: Vector2, charge: int, precise: bool)
signal braked(origin: Vector2)
signal crashed(origin: Vector2)

enum State { SLEEP, AIM, CHARGE, BRAKE, WAIT, STUN, DOWN }

const Sera = preload("res://scripts/sera.gd")
const ART := "res://assets/characters/ram.png"
const SPEED := 720.0
const AIM_TIME := 0.78
const STUN_TIME := 2.5
const HALF := 50.0
const CONTACT_RANGE := HALF + 20.0
const TOP := 46.0
const SIGHT := 560.0
const GAIN := 64
const PRECISE_GAIN := 90
const HEAT := Color("#ff7647")
const ICE := Color("#7ce9ff")
const STEEL := Color("#2b3a43")
const PLATE := Color("#8a9aa0")

## The stretch of floor it charges along, in world x.
@export var run_left := 0.0
@export var run_right := 0.0

var target: Sera
var state := State.SLEEP
var left := 0.0
var direction := -1.0
var home := Vector2.ZERO
var down := false
var clock := 0.0
var flash := 0.0
var tumble := Vector2.ZERO
var spin := 0.0
var cue_played := false
var art: Texture2D


func _ready() -> void:
	home = position
	if ResourceLoader.exists(ART):
		art = load(ART)


func reset_foe() -> void:
	position = home
	rotation = 0.0
	state = State.SLEEP
	left = 0.0
	direction = -1.0
	flash = 0.0
	queue_redraw()


func restore_defeated() -> void:
	down = true
	state = State.DOWN
	visible = false
	set_physics_process(false)


func is_stunned() -> bool:
	return state == State.STUN


func is_threat() -> bool:
	return state == State.AIM or state == State.CHARGE


func precise_cue_visible() -> bool:
	if state != State.CHARGE or not is_instance_valid(target) or not target.is_on_floor():
		return false
	var offset := target.global_position - global_position
	var distance := offset.x * direction
	return absf(offset.y) < TOP and distance > 0.0 and distance <= CONTACT_RANGE + SPEED * Sera.PERFECT_WINDOW


func hit_point() -> Vector2:
	return global_position + Vector2(0.0, -30.0)


## A shockwave only counts while the sled is stunned. Returns true when it was destroyed.
func take_wave(push: float) -> bool:
	if state != State.STUN:
		flash = 0.3
		return false
	down = true
	state = State.DOWN
	left = 1.3
	tumble = Vector2(push * 560.0, -400.0)
	spin = push * 7.0
	return true


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta)
	left = maxf(0.0, left - delta)
	match state:
		State.SLEEP, State.WAIT:
			if left == 0.0 and _sees_target():
				direction = signf(target.global_position.x - global_position.x)
				if direction == 0.0:
					direction = -1.0
				state = State.AIM
				left = AIM_TIME
				attack_prepared.emit(true)
		State.AIM:
			if left > AIM_TIME * 0.45 and is_instance_valid(target):
				var side := signf(target.global_position.x - global_position.x)
				if side != 0.0:
					direction = side
			if left == 0.0:
				cue_played = false
				state = State.CHARGE
		State.CHARGE:
			if not cue_played and precise_cue_visible():
				cue_played = true
				precision_ready.emit()
			_charge(delta)
		State.BRAKE:
			if left == 0.0:
				state = State.WAIT
				left = 0.75
		State.STUN:
			if left == 0.0:
				state = State.WAIT
				left = 0.4
		State.DOWN:
			tumble.y += 1400.0 * delta
			position += tumble * delta
			rotation += spin * delta
			if left == 0.0:
				visible = false
				set_physics_process(false)
	queue_redraw()


func _sees_target() -> bool:
	if not is_instance_valid(target) or target.integrity <= 0:
		return false
	var gap := target.global_position - global_position
	return absf(gap.y) < 100.0 and absf(gap.x) < SIGHT \
		and target.global_position.x > run_left - 90.0 and target.global_position.x < run_right + 90.0


func _charge(delta: float) -> void:
	position.x += direction * SPEED * delta
	if is_instance_valid(target) and target.integrity > 0:
		var body := target.global_position
		var gap := body.x - global_position.x
		# Sera is hit only while her feet are below the top of the sled, so a jump clears it.
		var level := body.y > global_position.y - TOP + 6.0 and body.y < global_position.y + 30.0
		if level and absf(gap) < CONTACT_RANGE:
			if gap * direction > 0.0 and target.can_absorb() and target.facing == -direction:
				_stopped_by(target)
				return
			target.take_hit(direction)
	var limit := run_right if direction > 0.0 else run_left
	if (position.x - limit) * direction >= 0.0:
		position.x = limit
		state = State.BRAKE
		left = 0.5
		braked.emit(global_position + Vector2(direction * HALF, -20.0))


func _stopped_by(sera: Sera) -> void:
	var precise := sera.absorb_age <= sera.PERFECT_WINDOW
	var charge := mini(PRECISE_GAIN if precise else GAIN, sera.CAPACITY - sera.energy)
	sera.absorb(charge, false)
	state = State.STUN
	left = STUN_TIME
	position.x = clampf(position.x - direction * 22.0, run_left, run_right)
	caught.emit(Vector2(sera.global_position.x + sera.facing * 36.0, global_position.y - 62.0), charge, precise)


func _draw() -> void:
	var shake := Vector2.ZERO
	if state == State.AIM:
		var rev := 1.0 - left / AIM_TIME
		shake = Vector2(sin(clock * 70.0) * 2.5 * rev, 0.0)
	draw_set_transform(shake, 0.0, Vector2(direction, 1.0))
	if art:
		var size := Vector2(150.0, 150.0 * art.get_height() / art.get_width())
		draw_texture_rect(art, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false)
	else:
		_draw_body()
	draw_set_transform(Vector2.ZERO)
	if state == State.AIM:
		var rev := 1.0 - left / AIM_TIME
		var from := Vector2(direction * (HALF + 8.0), -22.0)
		draw_dashed_line(from, from + Vector2(direction * 520.0, 0.0), Color(HEAT, 0.3 + 0.45 * rev), 2.0, 12.0)
		draw_arc(from, 20.0 - 9.0 * rev, 0.0, TAU, 28, Color(HEAT, 0.8), 2.0, true)
	elif precise_cue_visible():
		var bumper := Vector2(direction * (HALF + 10.0), -23.0)
		draw_circle(bumper, 15.0, Color(ICE, 0.27), true, -1.0, true)
		draw_polyline(PackedVector2Array([bumper + Vector2(-direction * 14.0, -12.0), bumper,
			bumper + Vector2(-direction * 14.0, 12.0)]), ICE, 3.5, true)
	elif state == State.STUN:
		var ratio := left / STUN_TIME
		draw_arc(Vector2(0.0, -TOP - 22.0), 15.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 28, ICE, 3.0, true)
		for i in 3:
			var angle := clock * 6.0 + TAU * i / 3.0
			draw_circle(Vector2(0.0, -TOP - 22.0) + Vector2(cos(angle) * 22.0, sin(angle) * 7.0), 3.0, Color("#fff3cc"))
	if flash > 0.0:
		draw_arc(Vector2(direction * HALF, -24.0), 30.0 + (0.3 - flash) * 80.0, -1.2, 1.2, 24, Color("#ffe1aa", flash * 2.6), 3.0, true)


## Drawn facing right; the transform mirrors it.
func _draw_body() -> void:
	var lamp := HEAT
	if state == State.STUN:
		lamp = ICE
	elif state == State.DOWN:
		lamp = Color("#5d686e")
	elif state == State.AIM and int(clock * 14.0) % 2 == 0:
		lamp = Color("#fff0d0")
	# Wheels.
	for wheel in [-30.0, 22.0]:
		draw_circle(Vector2(wheel, -11.0), 12.0, Color("#101a20"))
		draw_arc(Vector2(wheel, -11.0), 12.0, 0.0, TAU, 20, PLATE.darkened(0.45), 2.0, true)
		var spoke := Vector2.from_angle(position.x * 0.09) * 8.0
		draw_line(Vector2(wheel, -11.0) - spoke, Vector2(wheel, -11.0) + spoke, PLATE.darkened(0.3), 2.0, true)
	# Hull: low wedge with the heavy plate at the front.
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF, -14.0), Vector2(-HALF + 6.0, -TOP + 6.0), Vector2(8.0, -TOP),
		Vector2(HALF - 12.0, -TOP + 12.0), Vector2(HALF - 4.0, -12.0)]), STEEL)
	draw_polyline(PackedVector2Array([Vector2(-HALF + 6.0, -TOP + 6.0), Vector2(8.0, -TOP), Vector2(HALF - 12.0, -TOP + 12.0)]), PLATE, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(HALF - 14.0, -TOP + 8.0), Vector2(HALF + 4.0, -TOP + 16.0),
		Vector2(HALF + 4.0, -6.0), Vector2(HALF - 10.0, -4.0)]), PLATE if state != State.STUN else PLATE.darkened(0.35))
	for rib in 3:
		draw_line(Vector2(HALF - 10.0, -TOP + 16.0 + rib * 9.0), Vector2(HALF + 3.0, -TOP + 19.0 + rib * 9.0), STEEL, 2.0)
	draw_rect(Rect2(-HALF + 10.0, -TOP + 14.0, 30.0, 8.0), Color("#172229"))
	draw_rect(Rect2(-HALF + 12.0, -TOP + 16.0, 26.0, 4.0), Color(lamp, 0.9))
	draw_circle(Vector2(HALF - 22.0, -TOP + 20.0), 4.0, lamp)
	# Exhaust stack at the back.
	draw_rect(Rect2(-HALF + 2.0, -TOP - 4.0, 9.0, 14.0), Color("#1d2a31"))
	if state == State.CHARGE:
		for i in 3:
			draw_line(Vector2(-HALF - 6.0 - i * 16.0, -30.0 + i * 7.0), Vector2(-HALF - 40.0 - i * 22.0, -30.0 + i * 7.0), Color(HEAT, 0.5 - i * 0.12), 3.0, true)
