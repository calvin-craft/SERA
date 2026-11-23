extends Node2D

## 돌풍. Wind off the sea across part of a stage. While it blows it pushes Sera
## sideways, a little on her feet and a lot in the air, so a jump with the wind
## goes far and a jump against it falls short. A dash goes straight through.
## Gusts that come and go flicker their streaks just before they start.
## The node sits at the bottom-left corner of the zone.

const Sera = preload("res://scripts/sera.gd")
const WARNING := 0.7
const GROUND_SHARE := 0.4
const STREAK := Color("#d9f2f4")
const FLAG := Color("#ff9f6a")

@export var width := 600.0
@export var height := 420.0
## Push in the air, in pixels per second; positive blows to the right.
@export var push := 240.0
## Seconds blowing and resting. A zero rest blows all the time.
@export var on_time := 1.8
@export var off_time := 1.6
@export var phase := 0.0

var target: Sera
var clock := 0.0
## How hard it is blowing right now, eased between 0 and 1.
var strength := 0.0


func _ready() -> void:
	clock = phase
	strength = 1.0 if active() else 0.0


func restart() -> void:
	clock = phase
	strength = 1.0 if active() else 0.0


func cycle_time() -> float:
	return on_time + off_time


func active() -> bool:
	return off_time <= 0.0 or fposmod(clock, cycle_time()) < on_time


func warning() -> bool:
	return off_time > 0.0 and fposmod(clock, cycle_time()) >= cycle_time() - WARNING


func contains(point: Vector2) -> bool:
	var local := point - global_position
	return local.x >= 0.0 and local.x <= width and local.y <= 0.0 and local.y >= -height


func _physics_process(delta: float) -> void:
	clock += delta
	strength = move_toward(strength, 1.0 if active() else 0.0, delta * 3.2)
	if strength > 0.0 and is_instance_valid(target) and target.integrity > 0 \
			and target.state != Sera.State.BOOST and contains(target.global_position):
		var force := push * strength * (GROUND_SHARE if target.is_on_floor() else 1.0)
		target.move_and_collide(Vector2(force * delta, 0.0))
	queue_redraw()


func _draw() -> void:
	var heading := signf(push) if push != 0.0 else 1.0
	var level := strength
	if warning():
		level = maxf(level, 0.25 + 0.2 * sin(clock * 30.0))
	if level > 0.02:
		# Streaks race across the zone in the wind's direction.
		for index in 22:
			var lane := fposmod(index * 0.618034, 1.0)
			var y := -height * (0.08 + lane * 0.9)
			var length := 46.0 + fposmod(index * 37.0, 70.0)
			var travel := fposmod(index * 173.0 + clock * absf(push) * 2.2, width + length)
			var x := travel - length if heading > 0.0 else width - travel + length
			var tail := x - heading * length
			var from := clampf(minf(x, tail), 0.0, width)
			var to := clampf(maxf(x, tail), 0.0, width)
			if to - from > 4.0:
				draw_line(Vector2(from, y), Vector2(to, y), Color(STREAK, 0.16 * level), 3.0, true)
				draw_line(Vector2(from, y), Vector2(to, y), Color(STREAK, 0.42 * level), 1.0, true)
	# A wind flag on the windward edge shows where it comes from and how hard.
	var pole_x := 18.0 if heading > 0.0 else width - 18.0
	draw_line(Vector2(pole_x, 0.0), Vector2(pole_x, -96.0), Color("#3b4b52"), 4.0)
	var lift := lerpf(0.9, 0.08, strength)
	var flutter := sin(clock * (18.0 if strength > 0.5 else 4.0)) * 5.0 * maxf(strength, 0.2)
	var tip := Vector2(pole_x + heading * lerpf(18.0, 46.0, strength), -96.0 + 40.0 * lift + flutter)
	draw_colored_polygon(PackedVector2Array([Vector2(pole_x, -96.0), tip, Vector2(pole_x, -76.0)]), Color(FLAG, 0.9))
