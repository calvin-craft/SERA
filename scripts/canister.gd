extends Node2D

## A canister a bomber drops. Blue ones can be caught overhead like the
## foundry's beams; red ones burst where they land and hurt anyone close. The
## owner calls advance() every physics frame. It moves in world space.

signal caught(origin: Vector2, charge: int)
signal burst(point: Vector2, hit_player: bool)

const Sera = preload("res://scripts/sera.gd")
const HALF := 30.0
const CHARGE := 72
const BLAST := 104.0
const ICE := Color("#7ce9ff")
const RED := Color("#ff6a4a")

var floor_y := 520.0
var red := false
var falling := false
var speed := 0.0
var flash := 0.0
var clock := 0.0


func _ready() -> void:
	top_level = true
	hide()


func drop(from: Vector2, floor_level: float, hot: bool) -> void:
	global_position = from
	floor_y = floor_level
	red = hot
	speed = 60.0
	falling = true
	flash = 0.0
	show()
	queue_redraw()


func clear() -> void:
	falling = false
	flash = 0.0
	hide()


func advance(delta: float, sera: Sera) -> void:
	clock += delta
	if not falling:
		if flash > 0.0:
			flash = maxf(0.0, flash - delta * 2.4)
			queue_redraw()
			if flash == 0.0:
				hide()
		return
	speed = minf(speed + 1300.0 * delta, 1100.0)
	global_position.y += speed * delta
	var body := sera.global_position
	var gap := absf(body.x - global_position.x)
	# Overhead catch, at the same hand height as a beam.
	var catch_y := floor_y - 160.0
	if not red and global_position.y >= catch_y and global_position.y <= catch_y + 60.0 and gap < HALF + 8.0 \
			and absf(body.y - floor_y) < 6.0 and sera.can_absorb() and sera.integrity > 0:
		falling = false
		hide()
		sera.absorb(CHARGE)
		caught.emit(body + Vector2(sera.facing * 10.0, -146.0), CHARGE)
		return
	if gap < HALF + 6.0 and global_position.y + 18.0 >= body.y - 109.0 and global_position.y - 18.0 < body.y:
		var hit := sera.take_hit(signf(body.x - global_position.x) if body.x != global_position.x else -sera.facing)
		_land(hit)
		return
	if global_position.y >= floor_y - 18.0:
		var near := absf(body.x - global_position.x) < BLAST and body.y > floor_y - 120.0 and body.y < floor_y + 30.0
		_land(red and near and sera.take_hit(signf(body.x - global_position.x) if body.x != global_position.x else 1.0))
		return
	queue_redraw()


func _land(hit_player: bool) -> void:
	falling = false
	flash = 1.0
	global_position.y = minf(global_position.y, floor_y - 18.0)
	burst.emit(Vector2(global_position.x, floor_y), hit_player)
	queue_redraw()


func _draw() -> void:
	if falling:
		draw_canister(self, Vector2.ZERO, red, clock)
	elif flash > 0.0 and red:
		draw_circle(Vector2(0.0, 18.0), BLAST * (1.0 - flash * 0.5), Color(RED, 0.22 * flash))
		draw_arc(Vector2(0.0, 18.0), BLAST * (1.0 - flash * 0.4), PI, TAU, 40, Color("#ffc58a", flash), 3.0, true)


## Shared with the bomber so it can show the canister before letting go.
static func draw_canister(canvas: CanvasItem, at: Vector2, hot: bool, time: float) -> void:
	var tint := RED if hot else ICE
	canvas.draw_rect(Rect2(at.x - HALF + 6.0, at.y - 22.0, (HALF - 6.0) * 2.0, 44.0), Color("#1a2a32"))
	canvas.draw_rect(Rect2(at.x - HALF + 2.0, at.y - 24.0, (HALF - 2.0) * 2.0, 7.0), Color("#3e5059"))
	canvas.draw_rect(Rect2(at.x - HALF + 2.0, at.y + 17.0, (HALF - 2.0) * 2.0, 7.0), Color("#3e5059"))
	var glow := 0.7 + 0.25 * sin(time * 10.0)
	if hot:
		glow = 1.0 if int(time * 10.0) % 2 == 0 else 0.35
	canvas.draw_rect(Rect2(at.x - 10.0, at.y - 12.0, 20.0, 24.0), Color(tint, glow * 0.85))
	canvas.draw_circle(at, 24.0, Color(tint, glow * 0.12))
