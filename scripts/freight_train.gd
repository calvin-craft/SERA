extends AnimatableBody2D

## 화물 열차. Freight cars run through a trench with their roofs just under the
## deck line, so a passing train is a moving bridge: step on, ride, and jump off
## with its speed. Between trains the trench is a drop. The node sits on the deck
## line at the trench's left edge and `span` is the trench's width. Trains come
## out from under one deck and go in under the other, one after another; the
## signal lamps on both edges turn red a little before a train arrives.

## The roofs ride level with the deck. Only the part of a train over the trench
## is solid, so the hidden part under a deck never carries anyone standing there.
const ROOF_DROP := 0.0
const CAR_HEIGHT := 66.0
const COUPLER := 18.0
const WARN_TIME := 1.2
const BODY := Color("#25343a")
const PANEL := Color("#31444b")
const ROOF := Color("#62777d")
const RUST := Color("#7b5b49")
const DARK := Color("#0f191e")
const LAMP_GO := Color("#7deed9")
const LAMP_STOP := Color("#ff7a55")

## Width of the trench the trains cross.
@export var span := 600.0
## Pixels per second; positive runs to the right.
@export var speed := 340.0
@export var cars := 3
@export var car_length := 190.0
## Seconds of empty trench between one train leaving and the next arriving.
@export var gap_time := 1.6
## Seconds into the cycle when the stage starts.
@export var phase := 0.0

var home := Vector2.ZERO
var clock := 0.0
## Left end of the train relative to `home`.
var lead := 0.0
var shape: CollisionShape2D
var box: RectangleShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	home = position
	shape = CollisionShape2D.new()
	box = RectangleShape2D.new()
	box.size = Vector2(train_length(), CAR_HEIGHT)
	shape.shape = box
	add_child(shape)
	clock = phase
	_place()


func train_length() -> float:
	return cars * car_length + (cars - 1) * COUPLER


func cycle_time() -> float:
	return (span + train_length()) / maxf(absf(speed), 1.0) + gap_time


## Distance the current train has come since its front reached the trench.
func _run() -> float:
	return fposmod(clock, cycle_time()) * absf(speed)


## True while a train is in the trench or about to arrive.
func signal_red() -> bool:
	var run := _run()
	var through := span + train_length()
	return run < through or run > cycle_time() * absf(speed) - WARN_TIME * absf(speed)


## True while some part of a train is over the trench.
func in_trench() -> bool:
	return _run() < span + train_length()


## Back to where it was when the stage began, as on a retry.
func restart() -> void:
	clock = phase
	_place()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	clock += delta
	_place()
	queue_redraw()


func _place() -> void:
	var length := train_length()
	var run := minf(_run(), span + length)
	lead = run - length if speed >= 0.0 else span - run
	position = home + Vector2(lead, 0.0)
	# Solid only where the train is over the trench, in the train's own space.
	var from := clampf(-lead, 0.0, length)
	var to := clampf(span - lead, 0.0, length)
	var width := to - from
	if width < 2.0:
		shape.set_deferred(&"disabled", true)
		return
	shape.set_deferred(&"disabled", false)
	box.size = Vector2(width, CAR_HEIGHT)
	shape.position = Vector2(from + width * 0.5, ROOF_DROP + CAR_HEIGHT * 0.5)


func _draw() -> void:
	# Everything is drawn in the train's own space; `back` is the trench's left edge.
	var back := -lead
	_draw_track(back)
	var heading := 1.0 if speed >= 0.0 else -1.0
	for index in cars:
		var left := index * (car_length + COUPLER)
		var front := index == (cars - 1 if heading > 0.0 else 0)
		_draw_car(left, back, front, heading)
	_draw_signal(back - 18.0)
	_draw_signal(back + span + 18.0)


func _draw_track(back: float) -> void:
	var rail_y := ROOF_DROP + CAR_HEIGHT + 26.0
	draw_rect(Rect2(back, rail_y - 3.0, span, 6.0), Color("#1a262c"))
	draw_line(Vector2(back, rail_y - 3.0), Vector2(back + span, rail_y - 3.0), Color("#5b6d72"), 2.0)
	for x in range(int(back) + 12, int(back + span) - 6, 38):
		draw_rect(Rect2(x, rail_y + 2.0, 22.0, 5.0), Color("#2c2622"))


## One car, clipped to the trench so it seems to come out from under the decks.
func _draw_car(left: float, back: float, front: bool, heading: float) -> void:
	var from := maxf(left, back)
	var to := minf(left + car_length, back + span)
	if to <= from:
		return
	var width := to - from
	draw_rect(Rect2(from, ROOF_DROP, width, CAR_HEIGHT), BODY)
	draw_rect(Rect2(from, ROOF_DROP, width, 6.0), ROOF)
	draw_rect(Rect2(from, ROOF_DROP + 6.0, width, 3.0), DARK)
	draw_rect(Rect2(from, ROOF_DROP + CAR_HEIGHT - 8.0, width, 8.0), DARK)
	# Ribs and a sliding door, only where they fall inside the trench.
	for x in range(int(left) + 14, int(left + car_length) - 10, 30):
		if x > from and x < to:
			draw_line(Vector2(x, ROOF_DROP + 12.0), Vector2(x, ROOF_DROP + CAR_HEIGHT - 10.0), PANEL, 3.0)
	var door := Rect2(left + car_length * 0.5 - 28.0, ROOF_DROP + 14.0, 56.0, CAR_HEIGHT - 26.0)
	var shown := door.intersection(Rect2(from, ROOF_DROP, width, CAR_HEIGHT))
	if shown.size.x > 0.0:
		draw_rect(shown, RUST.darkened(0.35))
		draw_rect(Rect2(shown.position, Vector2(shown.size.x, 3.0)), RUST)
	if front:
		# The locomotive end: a cab window and a headlight facing the way it runs.
		var nose := left + (car_length - 34.0 if heading > 0.0 else 4.0)
		var cab := Rect2(nose, ROOF_DROP + 12.0, 30.0, 18.0).intersection(Rect2(from, ROOF_DROP, width, CAR_HEIGHT))
		if cab.size.x > 0.0:
			draw_rect(cab, Color("#9fe9f2", 0.55))
		var lamp := Vector2(left + (car_length + 2.0 if heading > 0.0 else -2.0), ROOF_DROP + CAR_HEIGHT - 22.0)
		if lamp.x >= back and lamp.x <= back + span:
			draw_circle(lamp, 5.0, Color("#fff1c4"))
			draw_circle(lamp, 16.0, Color("#fff1c4", 0.18))
	for wheel in [left + 32.0, left + 62.0, left + car_length - 62.0, left + car_length - 32.0]:
		if wheel > back + 8.0 and wheel < back + span - 8.0:
			draw_circle(Vector2(wheel, ROOF_DROP + CAR_HEIGHT + 10.0), 11.0, DARK)
			draw_arc(Vector2(wheel, ROOF_DROP + CAR_HEIGHT + 10.0), 11.0, 0.0, TAU, 18, ROOF.darkened(0.3), 2.0, true)


## A signal post on the deck beside the trench.
func _draw_signal(x: float) -> void:
	var red := signal_red()
	var blink := red and int(clock * 6.0) % 2 == 0 and not in_trench()
	var tint := LAMP_STOP if red else LAMP_GO
	draw_line(Vector2(x, 0.0), Vector2(x, -62.0), Color("#26363d"), 5.0)
	draw_rect(Rect2(x - 8.0, -78.0, 16.0, 20.0), DARK)
	draw_circle(Vector2(x, -68.0), 5.0, Color(tint, 0.35 if blink else 1.0))
	draw_circle(Vector2(x, -68.0), 12.0, Color(tint, 0.12))
