extends Node2D

## A column that hurts while it is active. The node sits on the floor at the
## column's centre. "steam" is a leaking pipe that blows on a timer (or all the
## time, until whatever feeds it is shut down); "press" is a stamping head that
## slams down on a rhythm. A dash passes through either one unharmed.

signal burst(origin: Vector2, press: bool)
signal warned(origin: Vector2, press: bool)

const Sera = preload("res://scripts/sera.gd")
const WARNING := 0.7
## How far above the housing its ceiling mount is drawn.
const CEILING := 420.0
const HEAT := Color("#ff8a5c")
const VAPOR := Color("#d6eef2")
const IRON := Color("#1c2a33")
const EDGE := Color("#7b9299")

@export_enum("steam", "press") var kind := "steam"
## Seconds the column is harmless, then harmful, each cycle.
@export var off_time := 1.6
@export var on_time := 1.3
## Shifts this column's rhythm against its neighbours.
@export var phase := 0.0
## Never switches off by itself; something else has to shut it down.
@export var always_on := false
@export var half_width := 28.0
@export var height := 330.0

var target: Sera
var clock := 0.0
var shut := false
var was_active := false
var was_warning := false
var fade := 0.0


func restart() -> void:
	clock = 0.0
	was_active = false
	was_warning = false


func shut_down() -> void:
	shut = true


func is_shut() -> bool:
	return shut


func cycle_time() -> float:
	return fposmod(clock + phase, off_time + on_time)


func active() -> bool:
	if shut:
		return false
	return always_on or cycle_time() >= off_time


## True in the last moments before the column switches on.
func warning() -> bool:
	return not shut and not always_on and not active() and cycle_time() >= off_time - WARNING


func _physics_process(delta: float) -> void:
	clock += delta
	var live := active()
	var about_to_fire := warning()
	fade = move_toward(fade, 1.0 if live else 0.0, delta * (9.0 if kind == "press" else 5.0))
	if about_to_fire and not was_warning:
		warned.emit(global_position, kind == "press")
	was_warning = about_to_fire
	if live and not was_active and not always_on:
		burst.emit(global_position, kind == "press")
	was_active = live
	if live and is_instance_valid(target) and target.integrity > 0:
		var gap := target.global_position - global_position
		if absf(gap.x) < half_width + 15.0 and gap.y > -height and gap.y - 104.0 < 0.0:
			target.take_hit(signf(gap.x) if gap.x != 0.0 else -target.facing)
	queue_redraw()


func _draw() -> void:
	if kind == "press":
		_draw_press()
	else:
		_draw_steam()


func _draw_steam() -> void:
	# Cracked pipe stubs at the floor and overhead.
	draw_rect(Rect2(-half_width - 8.0, -14.0, half_width * 2.0 + 16.0, 14.0), IRON)
	draw_rect(Rect2(-half_width - 4.0, -18.0, half_width * 2.0 + 8.0, 5.0), EDGE.darkened(0.3))
	# The feed pipe comes down from the ceiling to the nozzle housing.
	draw_rect(Rect2(-13.0, -height - 30.0 - CEILING, 26.0, CEILING), IRON)
	draw_line(Vector2(-8.0, -height - 30.0 - CEILING), Vector2(-8.0, -height - 30.0), EDGE.darkened(0.45), 2.0)
	for collar in range(int(-height) - 150, int(-height - CEILING), -150):
		draw_rect(Rect2(-17.0, collar, 34.0, 9.0), IRON.lightened(0.07))
	draw_rect(Rect2(-half_width - 10.0, -height - 30.0, half_width * 2.0 + 20.0, 30.0), IRON)
	draw_line(Vector2(-half_width - 10.0, -height), Vector2(half_width + 10.0, -height), EDGE.darkened(0.2), 2.0)
	var lamp := Color("#4b5a60") if shut else (HEAT if always_on or active() or warning() else Color("#9c7859"))
	if warning() and int(clock * 9.0) % 2 == 0:
		lamp = Color("#fff0d0")
	draw_circle(Vector2(0.0, -height - 15.0), 5.0, lamp)
	for x in [-half_width - 2.0, half_width + 2.0]:
		draw_line(Vector2(x, -18.0), Vector2(x, -34.0), Color(lamp, 0.8), 2.0)
	if shut:
		return
	if warning():
		var ratio := (cycle_time() - (off_time - WARNING)) / WARNING
		draw_rect(Rect2(-half_width, -height, half_width * 2.0, height - 16.0), Color(HEAT, 0.05 + 0.08 * ratio))
		for i in 3:
			var puff := fposmod(clock * 2.3 + i * 0.33, 1.0)
			draw_circle(Vector2((i - 1) * half_width * 0.5, -18.0 - puff * 70.0), 5.0 + puff * 9.0, Color(VAPOR, 0.3 * (1.0 - puff)))
	if fade <= 0.0:
		return
	# The jet: a hot core with pale vapour rolling up it.
	draw_rect(Rect2(-half_width, -height, half_width * 2.0, height - 14.0), Color(HEAT, 0.12 * fade))
	draw_rect(Rect2(-half_width * 0.45, -height, half_width * 0.9, height - 14.0), Color(VAPOR, 0.2 * fade))
	for i in 9:
		var rise := fposmod(clock * 1.9 + i / 9.0, 1.0)
		var sway := sin(clock * 5.0 + i * 1.7) * half_width * 0.45
		var radius := 12.0 + 20.0 * sin(rise * PI)
		draw_circle(Vector2(sway, -16.0 - rise * (height - 30.0)), radius, Color(VAPOR, 0.3 * fade * sin(rise * PI)))
	for x in [-half_width, half_width]:
		draw_line(Vector2(x, -height), Vector2(x, -16.0), Color(HEAT, 0.5 * fade), 2.0)


func _draw_press() -> void:
	# Head travel: parked high, drops through the active window, climbs back afterwards.
	var top := -height
	var parked := top + 18.0
	var down := -52.0
	var head := parked
	var cycle := cycle_time()
	if not shut:
		if cycle >= off_time:
			var drop := clampf((cycle - off_time) / minf(0.09, on_time), 0.0, 1.0)
			head = lerpf(parked, down, drop * drop)
		elif cycle < 0.45:
			head = lerpf(down, parked, smoothstep(0.0, 0.45, cycle))
	var lit := not shut and (active() or warning())
	var zone := Color(HEAT, 0.0)
	if warning():
		zone = Color(HEAT, 0.10 + 0.10 * sin(clock * 20.0))
	elif active():
		zone = Color(HEAT, 0.28)
	if zone.a > 0.0:
		draw_rect(Rect2(-half_width, top, half_width * 2.0, height), Color(zone, zone.a * 0.4))
		draw_rect(Rect2(-half_width, -14.0, half_width * 2.0, 13.0), zone)
	# Floor anvil with hazard stripes.
	draw_rect(Rect2(-half_width - 6.0, -6.0, half_width * 2.0 + 12.0, 6.0), Color("#39322f"))
	for stripe in range(int(-half_width), int(half_width) - 8, 17):
		draw_line(Vector2(stripe, -1.0), Vector2(stripe + 8.0, -6.0), Color(HEAT if lit else Color("#9c7859"), 0.9), 2.5, true)
	# Housing, rods and head. Two columns carry the housing from the ceiling.
	for column in [-half_width * 0.62, half_width * 0.62]:
		draw_rect(Rect2(column - 8.0, top - 34.0 - CEILING, 16.0, CEILING), IRON)
		draw_line(Vector2(column - 4.0, top - 34.0 - CEILING), Vector2(column - 4.0, top - 34.0), EDGE.darkened(0.45), 2.0)
	draw_rect(Rect2(-half_width - 12.0, top - 34.0, half_width * 2.0 + 24.0, 34.0), IRON)
	draw_line(Vector2(-half_width - 12.0, top), Vector2(half_width + 12.0, top), EDGE.darkened(0.2), 2.0)
	for rod in [-half_width * 0.5, half_width * 0.5]:
		draw_rect(Rect2(rod - 5.0, top, 10.0, head - top), Color("#101b21"))
		draw_line(Vector2(rod + 2.0, top), Vector2(rod + 2.0, head), Color("#a48170"), 2.0, true)
	draw_rect(Rect2(-half_width, head, half_width * 2.0, 52.0), Color("#26343b"))
	draw_rect(Rect2(-half_width + 6.0, head + 6.0, half_width * 2.0 - 12.0, 7.0), Color("#74818a"))
	draw_rect(Rect2(-half_width + 1.0, head + 44.0, half_width * 2.0 - 2.0, 6.0), Color(HEAT, 0.84) if lit else Color("#5b5550"))
	for slide in range(int(-half_width) + 12, int(half_width) - 10, 20):
		draw_line(Vector2(slide, head + 35.0), Vector2(slide + 8.0, head + 17.0), Color("#101b21"), 5.0, true)
