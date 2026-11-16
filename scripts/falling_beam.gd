extends Node2D

signal warned
signal captured(origin: Vector2, charge: int)
signal crashed(origin: Vector2)

enum Phase { WAIT, WARNING, FALL, HELD, RETURN }

const HANG_Y := 169.0
const CATCH_Y := 346.0
const IMPACT_Y := 495.0
const HALF_WIDTH := 114.0
const BEAM_MASS := 1.7
const CHARGE_PER_MOMENTUM := 0.087

var phase := Phase.WAIT
var time_left := 0.58
var speed := 0.0
var clock := 0.0
var struck_player := false

@onready var sera = $"../Sera"

func reset_beam() -> void:
	position.y = HANG_Y
	rotation = 0.0
	phase = Phase.WAIT
	time_left = 0.58
	speed = 0.0
	struck_player = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	clock += delta
	time_left -= delta
	var dx := absf(sera.global_position.x - global_position.x)
	match phase:
		Phase.WAIT:
			if time_left <= 0.0 and dx < 114.0 and sera.is_on_floor() and sera.energy < 84:
				phase = Phase.WARNING
				struck_player = false
				time_left = 1.25
				warned.emit()
		Phase.WARNING:
			rotation = 0.014 * sin(clock * 22.0)
			if time_left <= 0.0:
				speed = 0.0
				phase = Phase.FALL
		Phase.FALL:
			_fall(delta, dx)
		Phase.HELD:
			if time_left <= 0.0:
				phase = Phase.RETURN
		Phase.RETURN:
			position.y = move_toward(position.y, HANG_Y, 480.0 * delta)
			rotation = move_toward(rotation, 0.0, delta * 0.8)
			if is_equal_approx(position.y, HANG_Y):
				phase = Phase.WAIT
				time_left = 0.68
	queue_redraw()


func _fall(delta: float, dx: float) -> void:
	speed += 1440.0 * delta
	position.y += speed * delta
	rotation = -0.035 - (position.y - HANG_Y) * 0.0002
	if position.y >= CATCH_Y and position.y <= CATCH_Y + 67.0 and dx < 109.0 and sera.can_absorb() and sera.integrity > 0:
		position.y = CATCH_Y
		rotation = -0.01
		var charge := clampi(roundi(BEAM_MASS * speed * CHARGE_PER_MOMENTUM), 84, 100)
		speed = 0.0
		phase = Phase.HELD
		time_left = 0.30
		sera.absorb(charge)
		captured.emit(sera.global_position + Vector2(sera.facing * 10.0, -146.0), charge)
		return
	if not struck_player and dx < HALF_WIDTH + 10.0 and position.y + 24.0 >= sera.global_position.y - 109.0 \
			and position.y - 24.0 < sera.global_position.y:
		struck_player = true
		var away := signf(sera.global_position.x - global_position.x)
		sera.take_hit(away if away != 0.0 else -sera.facing)
	if position.y >= IMPACT_Y:
		position.y = IMPACT_Y
		rotation = 0.0
		speed = 0.0
		phase = Phase.HELD
		time_left = 0.54
		crashed.emit(global_position + Vector2(0, 25))


func _draw() -> void:
	var alert := phase == Phase.WARNING or phase == Phase.FALL
	var amber := Color("#ffc174") if alert else Color("#9c7859")
	var rail := Color("#354955")
	var bevel := Color("#789095")
	if phase == Phase.WAIT or phase == Phase.WARNING or phase == Phase.RETURN:
		draw_line(to_local(Vector2(global_position.x - 12, 122)), Vector2(-12, -20), Color("#243a45"), 3.0, true)
		draw_line(to_local(Vector2(global_position.x + 12, 122)), Vector2(12, -20), Color("#364d56"), 3.0, true)
	if phase == Phase.FALL:
		for x in [-89.0, -56.0, 60.0, 100.0]:
			draw_line(Vector2(x, -34), Vector2(x, -38.0 - speed * 0.05),
				Color(0.71, 0.85, 0.90, 0.31), 1.5, true)
	draw_rect(Rect2(-114, -24, 228, 48), Color("#12222b"))
	draw_rect(Rect2(-106, -17, 212, 34), Color("#1b2c35"))
	for x in range(-101, 71, 40):
		draw_line(Vector2(x, 16), Vector2(x + 36, -15), rail, 10.0, true)
		draw_line(Vector2(x + 1, 11), Vector2(x + 30, -16), bevel.darkened(0.28), 1.3, true)
	draw_rect(Rect2(-114, -23, 228, 9), rail)
	draw_line(Vector2(-114, -23), Vector2(114, -23), bevel, 2.0)
	draw_rect(Rect2(-114, 16, 228, 8), rail)
	draw_line(Vector2(-114, 24), Vector2(114, 24), bevel.darkened(0.17), 2.0)
	for x in [-114.0, 93.0]:
		draw_rect(Rect2(x, -22, 21, 46), Color("#536574"))
		draw_rect(Rect2(x + 3, -17, 15, 34), Color("#24323c"))
		draw_circle(Vector2(x + 10, -10), 2.5, bevel)
		draw_circle(Vector2(x + 10, 11), 2.5, bevel)
	var glow := (0.58 + 0.36 * sin(clock * 17.0)) if alert else 0.63
	for x in [-84.0, 83.0]:
		draw_rect(Rect2(x - 6.0, 11, 12, 3), Color(amber, glow))
		if alert:
			draw_circle(Vector2(x, 12), 10.0, Color(amber, glow * 0.13))
