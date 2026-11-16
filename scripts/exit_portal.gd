extends Node2D

## Stage exit: a sealed hatch that turns into a glowing field once the room is
## cleared. The stage moves on only when the player steps in and presses
## interact.

const IRON := Color("#16242e")
const STEEL := Color("#2c3d47")
const EDGE := Color("#7f959c")
const AMBER := Color("#ff9f57")
const CYAN := Color("#75e7ff")
const HALF_WIDTH := 52.0
const HEIGHT := 176.0

var open := false
var near := false
var glow := 0.0
var swallow := 0.0
var clock := 0.0


func _process(delta: float) -> void:
	clock += delta
	glow = move_toward(glow, 1.0 if open else 0.0, delta * 1.6)
	queue_redraw()


func _draw() -> void:
	var tint := AMBER.lerp(CYAN, glow)
	# Outer frame and lintel.
	draw_rect(Rect2(-HALF_WIDTH - 18, -HEIGHT - 30, (HALF_WIDTH + 18) * 2, 30), IRON)
	draw_rect(Rect2(-HALF_WIDTH - 14, -HEIGHT - 27, (HALF_WIDTH + 14) * 2, 4), EDGE)
	draw_rect(Rect2(-30, -HEIGHT - 18, 60, 8), Color(tint, 0.3))
	draw_rect(Rect2(-26, -HEIGHT - 16, 52, 4), tint)
	for x in [-HALF_WIDTH - 18.0, HALF_WIDTH]:
		draw_rect(Rect2(x, -HEIGHT, 18, HEIGHT), IRON)
		draw_line(Vector2(x + 3, -HEIGHT), Vector2(x + 3, 0), EDGE.darkened(0.35), 1.0)
		for y in range(-int(HEIGHT) + 14, -10, 34):
			draw_rect(Rect2(x + 5, y, 8, 14), Color(tint, 0.25 + 0.35 * glow))
	var inner := Rect2(-HALF_WIDTH, -HEIGHT, HALF_WIDTH * 2, HEIGHT)
	draw_rect(inner, Color("#071016"))

	# Field: layered light that ripples upward when open.
	if glow > 0.0:
		var core := Color(CYAN, 0.18 * glow)
		draw_rect(inner, core)
		for i in 7:
			var phase := fmod(clock * 0.55 + i / 7.0, 1.0)
			var y := -phase * HEIGHT
			var w := HALF_WIDTH * (0.35 + 0.65 * sin(phase * PI))
			draw_line(Vector2(-w, y), Vector2(w, y), Color(CYAN, 0.55 * glow * sin(phase * PI)), 2.0, true)
		var pulse := 0.5 + 0.5 * sin(clock * 3.2)
		draw_rect(inner.grow(-6.0), Color(CYAN, (0.06 + 0.06 * pulse) * glow), false, 2.0)
		draw_circle(Vector2(0, -HEIGHT * 0.5), 26.0 + 8.0 * pulse, Color(1.0, 1.0, 1.0, 0.08 * glow))
		if near:
			draw_rect(inner.grow(4.0), Color(CYAN, 0.6 * glow), false, 2.0)
		if swallow > 0.0:
			draw_rect(inner, Color(1.0, 1.0, 1.0, 0.55 * swallow))

	# Shutters slide up into the lintel as the field powers on.
	var shutter := HEIGHT * (1.0 - smoothstep(0.0, 0.8, glow))
	if shutter > 1.0:
		draw_rect(Rect2(-HALF_WIDTH, -HEIGHT, HALF_WIDTH * 2, shutter), STEEL)
		for y in range(0, int(shutter) - 6, 22):
			draw_line(Vector2(-HALF_WIDTH, -HEIGHT + y + 18), Vector2(HALF_WIDTH, -HEIGHT + y + 18), IRON, 4.0)
		draw_rect(Rect2(-HALF_WIDTH, -HEIGHT + shutter - 6, HALF_WIDTH * 2, 6), Color(tint, 0.8))
	# Floor plate.
	draw_rect(Rect2(-HALF_WIDTH - 22, -4, (HALF_WIDTH + 22) * 2, 6), Color(tint, 0.35 + 0.4 * glow))
