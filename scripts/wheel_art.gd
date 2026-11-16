extends Node2D

## The great wheel turning behind the last arena. It spins faster as the
## Foreman loses its grip on it, races during the finale, and coasts to a stop
## once its momentum has been released.

const CENTER := Vector2(700.0, 236.0)
const RADIUS := 452.0
const RIM := Color(0.16, 0.18, 0.27, 0.9)
const EDGE := Color(0.5, 0.55, 0.75, 0.7)
const GLOW := Color("#9fb4ff")

var angle := 0.0
var speed := 1.4

@onready var level = $"../.."


func _process(delta: float) -> void:
	var goal := 0.0
	if not level.complete:
		goal = 1.0 + (level.boss.HITS - level.boss.health) * 0.55 + (2.4 if level.finale else 0.0)
	speed = move_toward(speed, goal, delta * (0.9 if level.complete else 1.6))
	angle = fposmod(angle + speed * delta, TAU)
	queue_redraw()


func _draw() -> void:
	var hot := clampf(speed / 3.0, 0.0, 1.0)
	draw_circle(CENTER, RADIUS + 26.0, Color(0.05, 0.06, 0.1, 0.55))
	draw_arc(CENTER, RADIUS, 0.0, TAU, 96, RIM, 46.0, true)
	draw_arc(CENTER, RADIUS + 23.0, 0.0, TAU, 96, EDGE, 2.0, true)
	draw_arc(CENTER, RADIUS - 23.0, 0.0, TAU, 96, Color(EDGE, 0.4), 2.0, true)
	# Rim blocks show the turn.
	for i in 24:
		var a := angle + TAU * i / 24.0
		var dir := Vector2.from_angle(a)
		draw_line(CENTER + dir * (RADIUS - 20.0), CENTER + dir * (RADIUS + 20.0), Color(0.07, 0.08, 0.13, 0.9), 5.0, true)
	for i in 8:
		var a := angle + TAU * i / 8.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([CENTER + dir * 70.0 - side * 24.0, CENTER + dir * 70.0 + side * 24.0,
			CENTER + dir * (RADIUS - 24.0) + side * 12.0, CENTER + dir * (RADIUS - 24.0) - side * 12.0]), Color(0.12, 0.14, 0.21, 0.85))
		draw_line(CENTER + dir * 70.0, CENTER + dir * (RADIUS - 24.0), Color(EDGE, 0.35), 1.5, true)
	draw_arc(CENTER, RADIUS * 0.56, 0.0, TAU, 72, Color(0.13, 0.15, 0.23, 0.85), 16.0, true)
	draw_circle(CENTER, 82.0, Color(0.1, 0.11, 0.17, 0.95))
	draw_arc(CENTER, 82.0, 0.0, TAU, 48, EDGE, 2.0, true)
	draw_circle(CENTER, 34.0, Color(GLOW, 0.12 + 0.3 * hot))
	draw_circle(CENTER, 14.0, Color(GLOW, 0.3 + 0.5 * hot))
	# Streaks of stored momentum racing round the rim.
	for i in 3:
		var a := angle * 1.7 + TAU * i / 3.0
		draw_arc(CENTER, RADIUS, a, a + 0.5 + hot * 0.5, 20, Color(GLOW, 0.12 + 0.35 * hot), 6.0, true)
