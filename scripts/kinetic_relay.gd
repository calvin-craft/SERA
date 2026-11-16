extends Node2D

signal activated

const HIT_RADIUS := 34.0
const WAITING := Color("#ffc07c")
const LIVE := Color("#74ead7")

## Optional routes restore their power only when the save contains this relay.
@export var restore_behind_checkpoint := true

var powered := false
var age := 0.0
var pulse := 0.0


func energize(quiet: bool = false) -> void:
	if powered:
		return
	powered = true
	if not quiet:
		pulse = 1.0
		activated.emit()
	else:
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	pulse = maxf(0.0, pulse - delta * 1.9)
	queue_redraw()
	if powered and pulse == 0.0:
		set_process(false)


func _draw() -> void:
	var tint := LIVE if powered else WAITING
	var frame := PackedVector2Array([Vector2(-29, -30), Vector2(28, -30), Vector2(40, -17),
		Vector2(40, 17), Vector2(27, 30), Vector2(-28, 30), Vector2(-40, 18), Vector2(-40, -17)])
	draw_colored_polygon(frame, Color("#233b41"))
	var edge := frame.duplicate()
	edge.append(edge[0])
	draw_polyline(edge, Color("#72989c"), 1.5, true)
	draw_rect(Rect2(-30, -20, 60, 40), Color("#11232c"))
	draw_circle(Vector2.ZERO, 27.0, Color(tint, 0.13), true, -1.0, true)
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 38, Color(tint, 0.73), 2.0, true)
	var a := age * 1.8 if not powered else 0.65
	draw_arc(Vector2.ZERO, 13.5, a, a + 2.1, 22, tint, 3.0, true)
	draw_arc(Vector2.ZERO, 13.5, a + PI, a + PI + 2.1, 22, tint, 3.0, true)
	draw_circle(Vector2.ZERO, 5.5, tint, true, -1.0, true)
	for x in [-34.0, 34.0]:
		for y in [-11.0, 11.0]:
			draw_circle(Vector2(x, y), 2.0, Color("#aab7b7"))
	if pulse > 0.0:
		draw_arc(Vector2.ZERO, 26.0 + (1.0 - pulse) * 81.0, 0.0, TAU, 52, Color(LIVE, pulse * 0.64), 2.6, true)
