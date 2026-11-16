extends Node2D

## A load a boss lets go from above. Steel marked in blue can be caught
## overhead like the foundry's beams and fills the suit; a slab marked in red
## is too heavy and can only be stepped away from. The owner calls advance()
## every physics frame.

signal caught(origin: Vector2, charge: int)
signal crashed(point: Vector2, hit_player: bool)

const Sera = preload("res://scripts/sera.gd")
const HALF := 96.0
const MASS := 1.7
const CHARGE_PER_MOMENTUM := 0.087
const ICE := Color("#7ce9ff")
const RED := Color("#ff6a4a")

var floor_y := 520.0
var heavy := false
var falling := false
var speed := 0.0
var struck := false
var rest_left := 0.0
var clock := 0.0


func _ready() -> void:
	hide()


func drop(from: Vector2, floor_level: float, too_heavy: bool) -> void:
	global_position = from
	floor_y = floor_level
	heavy = too_heavy
	speed = 0.0
	struck = false
	falling = true
	rotation = 0.0
	show()
	queue_redraw()


func clear() -> void:
	falling = false
	rest_left = 0.0
	hide()


func advance(delta: float, sera: Sera) -> void:
	clock += delta
	if not falling:
		if rest_left > 0.0:
			rest_left -= delta
			if rest_left <= 0.0:
				hide()
		return
	speed += 1440.0 * delta
	position.y += speed * delta
	rotation = -0.02 - speed * 0.00002
	var body := sera.global_position
	var gap := absf(body.x - global_position.x)
	var catch_y := floor_y - 174.0
	if not heavy and position.y >= catch_y and position.y <= catch_y + 67.0 and gap < HALF - 5.0 \
			and sera.can_absorb() and sera.integrity > 0:
		position.y = catch_y
		rotation = -0.01
		var charge := clampi(roundi(MASS * speed * CHARGE_PER_MOMENTUM), 84, 100)
		falling = false
		rest_left = 0.32
		sera.absorb(charge)
		caught.emit(body + Vector2(sera.facing * 10.0, -146.0), charge)
		queue_redraw()
		return
	if not struck and gap < HALF + 10.0 and position.y + 24.0 >= body.y - 109.0 and position.y - 24.0 < body.y:
		struck = sera.take_hit(signf(body.x - global_position.x) if body.x != global_position.x else -sera.facing)
	if position.y >= floor_y - 25.0:
		position.y = floor_y - 25.0
		rotation = 0.0
		falling = false
		rest_left = 0.5
		crashed.emit(global_position + Vector2(0.0, 25.0), struck)
	queue_redraw()


func _draw() -> void:
	draw_load(self, Vector2.ZERO, heavy, clock, falling, speed)


## Shared with the owner so it can show the load hanging before the drop.
static func draw_load(canvas: CanvasItem, at: Vector2, too_heavy: bool, time: float, in_flight: bool = false, fall_speed: float = 0.0) -> void:
	var tint := RED if too_heavy else ICE
	var rail := Color("#4a3c3a") if too_heavy else Color("#354955")
	var bevel := Color("#9a8078") if too_heavy else Color("#789095")
	var half := HALF + (10.0 if too_heavy else 0.0)
	var tall := 34.0 if too_heavy else 24.0
	if in_flight:
		for x in [-half + 20.0, -half * 0.4, half * 0.45, half - 14.0]:
			canvas.draw_line(at + Vector2(x, -tall - 10.0), at + Vector2(x, -tall - 14.0 - fall_speed * 0.05), Color(0.71, 0.85, 0.90, 0.31), 1.5, true)
	canvas.draw_rect(Rect2(at.x - half, at.y - tall, half * 2.0, tall * 2.0), Color("#12222b"))
	canvas.draw_rect(Rect2(at.x - half + 8.0, at.y - tall + 7.0, half * 2.0 - 16.0, tall * 2.0 - 14.0), Color("#1b2c35"))
	for x in range(int(-half) + 13, int(half) - 30, 40):
		canvas.draw_line(at + Vector2(x, tall - 8.0), at + Vector2(x + 36, -tall + 9.0), rail, 10.0, true)
	canvas.draw_rect(Rect2(at.x - half, at.y - tall + 1.0, half * 2.0, 9.0), rail)
	canvas.draw_line(at + Vector2(-half, -tall + 1.0), at + Vector2(half, -tall + 1.0), bevel, 2.0)
	canvas.draw_rect(Rect2(at.x - half, at.y + tall - 8.0, half * 2.0, 8.0), rail)
	for x in [-half, half - 21.0]:
		canvas.draw_rect(Rect2(at.x + x, at.y - tall + 2.0, 21.0, tall * 2.0 - 2.0), Color("#536574"))
		canvas.draw_rect(Rect2(at.x + x + 3.0, at.y - tall + 7.0, 15.0, tall * 2.0 - 12.0), Color("#24323c"))
	# The lights say what to do: steady blue to catch, flashing red to get clear.
	var glow := 0.75 + 0.2 * sin(time * 9.0)
	if too_heavy:
		glow = 1.0 if int(time * 10.0) % 2 == 0 else 0.35
		for stripe in range(int(-half) + 30, int(half) - 34, 26):
			canvas.draw_line(at + Vector2(stripe, tall - 2.0), at + Vector2(stripe + 12, tall - 12.0), Color(RED, 0.8), 3.0, true)
	for x in [-half + 30.0, half - 30.0]:
		canvas.draw_rect(Rect2(at.x + x - 8.0, at.y + tall - 14.0, 16.0, 4.0), Color(tint, glow))
		canvas.draw_circle(at + Vector2(x, tall - 12.0), 11.0, Color(tint, glow * 0.14))
