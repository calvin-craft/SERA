extends Node2D

## 추적탄. A slow missile from a launcher that keeps turning after Sera; on foot
## she cannot outrun it. Braced hands take it as a heavy charge, or a reflect
## sends it home to the launcher that fired it, which is the only thing that
## breaks a launcher. It lives in the stage's Projectiles like any shot.

signal absorbed(origin: Vector2, charge: int, precise: bool)
signal reflected(origin: Vector2, heavy: bool)
signal burst(origin: Vector2, hit_player: bool)

const Sera = preload("res://scripts/sera.gd")
const LowGravity = preload("res://scripts/low_gravity.gd")
const SPEED := 300.0
const TURN := 2.0
const RETURN_SPEED := 560.0
const RETURN_TURN := 7.5
const LIFE := 5.0
const GAIN := 72
const PRECISE_GAIN := 90
const REACH := 42.0
const BODY := Color("#46545a")
const LAMP := Color("#ff6a4a")
const SMOKE := Color("#d8dde0")
const GOLD := Color("#ffe09a")

var player: Sera
## The stage: returned_hit(from, to, shot) decides what a returned missile hits.
var level: Node
## The launcher it flies home to once reflected.
var source: Node2D
var velocity := Vector2.ZERO
var age := 0.0
var returned := false
## Shared with bolts so the stage's scans and the tests can read any shot.
var sweep := false
var direction := 1.0
var heavy := true
var trail: Array[Vector2] = []


func _physics_process(delta: float) -> void:
	var step := delta * LowGravity.time_scale_at(global_position)
	age += step
	if age >= (3.0 if returned else LIFE):
		_explode(false)
		return
	var from := global_position
	if returned:
		if is_instance_valid(source) and source.visible:
			_steer(source.global_position + Vector2(0.0, -40.0), RETURN_TURN * step)
	else:
		_steer(player.global_position + Vector2(0.0, -86.0), TURN * step)
	var to := from + velocity * step
	var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1))
	var reach: Vector2 = wall["position"] if not wall.is_empty() else to
	if returned:
		if is_instance_valid(level) and level.has_method(&"returned_hit") and level.returned_hit(from, reach, self):
			queue_free()
			return
	elif _meet_player(from, reach):
		return
	if not wall.is_empty():
		global_position = reach
		_explode(false)
		return
	global_position = to
	direction = signf(velocity.x) if velocity.x != 0.0 else direction
	trail.push_front(global_position)
	if trail.size() > 16:
		trail.pop_back()
	queue_redraw()


func _steer(goal: Vector2, turn: float) -> void:
	var speed := RETURN_SPEED if returned else SPEED
	var want := (goal - global_position).angle()
	var now := velocity.angle() if velocity != Vector2.ZERO else want
	var change := clampf(angle_difference(now, want), -turn, turn)
	velocity = Vector2.from_angle(now + change) * speed


## Hands first, then the body. Returns true once the missile is spent.
func _meet_player(from: Vector2, to: Vector2) -> bool:
	var feet := player.global_position
	var hand := feet + Vector2(player.facing * 36.0, -86.0)
	var toward_hands := signf(from.x - feet.x) == player.facing
	var near := Geometry2D.get_closest_point_to_segment(hand, from, to).distance_to(hand) < REACH
	if near and toward_hands and player.can_reflect():
		var heading := signf(velocity.x) if velocity.x != 0.0 else -player.facing
		returned = true
		age = 0.0
		velocity = Vector2(player.facing, -1.0 if player.reflect_up else -0.25).normalized() * RETURN_SPEED
		global_position = hand + Vector2(player.facing * 10.0, 0.0)
		player.reflect_shot(heading)
		reflected.emit(hand, true)
		trail.clear()
		return true
	if near and toward_hands and player.can_absorb_shot():
		var precise := player.absorb_age <= player.PERFECT_WINDOW
		var charge := mini(PRECISE_GAIN if precise else GAIN, player.CAPACITY - player.energy)
		player.absorb(charge, false, signf(velocity.x))
		absorbed.emit(hand, charge, precise)
		queue_free()
		return true
	var body := Rect2(feet.x - 26.0, feet.y - 150.0, 52.0, 150.0)
	var probe := Geometry2D.get_closest_point_to_segment(body.get_center(), from, to)
	if body.has_point(probe) and player.take_hit(signf(velocity.x) if velocity.x != 0.0 else 1.0):
		global_position = probe
		_explode(true)
		return true
	return false


func _explode(hit_player: bool) -> void:
	burst.emit(global_position, hit_player)
	queue_free()


func _draw() -> void:
	var heading := velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
	# Smoke behind it, thinning out.
	for index in range(1, trail.size()):
		var a := to_local(trail[index - 1])
		var b := to_local(trail[index])
		var fade := 1.0 - float(index) / trail.size()
		draw_line(a, b, Color(GOLD if returned else SMOKE, 0.32 * fade), 2.0 + 7.0 * fade, true)
	var side := heading.orthogonal()
	var nose := heading * 17.0
	var tail := -heading * 15.0
	draw_colored_polygon(PackedVector2Array([nose, nose * 0.4 + side * 6.0, tail + side * 6.0, tail - side * 6.0, nose * 0.4 - side * 6.0]),
		GOLD.darkened(0.35) if returned else BODY)
	for fin in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([tail + side * 6.0 * fin, tail + side * 13.0 * fin - heading * 6.0, tail + heading * 6.0 + side * 6.0 * fin]),
			BODY.darkened(0.3))
	var blink := 0.5 + 0.5 * sin(age * (26.0 if returned else 14.0))
	draw_circle(nose * 0.55, 3.5, Color(GOLD if returned else LAMP, 0.6 + 0.4 * blink), true, -1.0, true)
	draw_circle(tail - heading * 3.0, 5.0 + blink * 3.0, Color("#ffd9a0", 0.5), true, -1.0, true)
	draw_circle(Vector2.ZERO, 22.0, Color(GOLD if returned else LAMP, 0.08 + 0.06 * blink), true, -1.0, true)
