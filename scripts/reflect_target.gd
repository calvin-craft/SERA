extends Node2D

## 반사 표적. A ringed plate on a post or a bulkhead. A shockwave only rattles
## it: it lights up for a shot, so the way to it is a bolt reflected off
## Sera's hands, usually upward (W) from a floor mark below. A lit target
## counts as "down" for open_when_down(). With `hold_time` it goes dark again.
## The node is the centre of the plate.

signal lit_up(origin: Vector2)

const HIT_RADIUS := 40.0
const WAITING := Color("#ffc07c")
const LIVE := Color("#ffe09a")
const FRAME := Color("#26363c")

## Seconds it stays lit; 0 keeps it lit for good.
@export var hold_time := 0.0
## Height of the post under the plate; 0 for a plate on a wall.
@export var post := 0.0

var lit := false
var left := 0.0
var age := 0.0
var pulse := 0.0
var rattle := 0.0
## Shared with foes so the stage's locks can wait on it.
var down: bool:
	get:
		return lit


func strike(quiet: bool = false) -> void:
	if lit and hold_time <= 0.0:
		return
	lit = true
	left = hold_time
	if not quiet:
		pulse = 1.0
		lit_up.emit(global_position)
	queue_redraw()


func restart() -> void:
	if hold_time > 0.0:
		lit = false
		left = 0.0


## A shockwave: it only shakes the plate.
func shake_plate() -> void:
	rattle = 0.3


func _process(delta: float) -> void:
	age += delta
	pulse = maxf(0.0, pulse - delta * 1.6)
	rattle = maxf(0.0, rattle - delta)
	if lit and hold_time > 0.0:
		left = maxf(0.0, left - delta)
		if left == 0.0:
			lit = false
	queue_redraw()


func _draw() -> void:
	var tint := LIVE if lit else WAITING
	var jitter := Vector2(sin(age * 90.0) * 3.0 * rattle * 3.0, 0.0)
	if post > 0.0:
		draw_rect(Rect2(-6.0, 30.0, 12.0, post - 30.0), FRAME)
		draw_rect(Rect2(-18.0, post - 8.0, 36.0, 8.0), FRAME.darkened(0.3))
	draw_circle(jitter, 34.0, FRAME)
	draw_arc(jitter, 34.0, 0.0, TAU, 40, Color("#8aa0a6"), 2.0, true)
	for ring in 3:
		draw_arc(jitter, 26.0 - ring * 8.0, 0.0, TAU, 36, Color(tint, 0.5 + 0.2 * ring), 3.0, true)
	draw_circle(jitter, 5.0, tint)
	if lit and hold_time > 0.0:
		draw_arc(jitter, 40.0, -PI * 0.5, -PI * 0.5 + TAU * left / hold_time, 40, Color(LIVE, 0.9), 2.5, true)
	elif not lit:
		var spin := age * 1.4
		draw_arc(jitter, 44.0, spin, spin + 1.2, 16, Color(WAITING, 0.45), 2.0, true)
		draw_arc(jitter, 44.0, spin + PI, spin + PI + 1.2, 16, Color(WAITING, 0.45), 2.0, true)
	if pulse > 0.0:
		draw_arc(Vector2.ZERO, 38.0 + (1.0 - pulse) * 90.0, 0.0, TAU, 52, Color(LIVE, pulse * 0.7), 2.6, true)
