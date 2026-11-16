extends StaticBody2D

## A belt that carries whatever stands on it. The node sits at the left end of
## the belt's top surface. Jumping off keeps the belt's speed, so a fast belt
## turns an ordinary jump into a long one; a belt running the other way has to
## be hopped or dashed across.

const THICKNESS := 40.0
const BODY := Color("#131f27")
const BELT := Color("#26323a")
const RIB := Color("#55666e")
const FORWARD := Color("#ffb46e")
const REVERSE := Color("#ff7d62")

@export var length := 400.0
## Pixels per second; positive carries to the right.
@export var speed := 300.0
@export var suspended := false

var clock := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	constant_linear_velocity = Vector2(speed, 0.0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(length, THICKNESS)
	shape.shape = box
	shape.position = Vector2(length * 0.5, THICKNESS * 0.5)
	add_child(shape)


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	var tint := FORWARD if speed >= 0.0 else REVERSE
	if suspended:
		tint = Color("#74ead7")
	else:
		draw_rect(Rect2(0, 0, length, 260), BODY)
	draw_rect(Rect2(0, 0, length, THICKNESS), BELT)
	draw_line(Vector2(0, 1), Vector2(length, 1), RIB, 2.0)
	draw_line(Vector2(0, THICKNESS), Vector2(length, THICKNESS), RIB.darkened(0.5), 2.0)
	# Ribs slide with the belt so its direction and speed can be read at a glance.
	var step := 34.0
	var shift := fposmod(clock * speed, step)
	var x := shift - step
	while x < length:
		var from := clampf(x, 0.0, length)
		var to := clampf(x + 12.0, 0.0, length)
		if to > from:
			draw_rect(Rect2(from, 4, to - from, 7), RIB.darkened(0.25))
		x += step
	# Direction chevrons on the side plate.
	var heading := signf(speed)
	var gap := 96.0
	var slide := fposmod(clock * speed * 0.5, gap)
	var cx := slide
	while cx < length - 14.0:
		if cx > 14.0:
			var tip := Vector2(cx + heading * 7.0, 25.0)
			draw_polyline(PackedVector2Array([tip + Vector2(-heading * 9.0, -7.0), tip, tip + Vector2(-heading * 9.0, 7.0)]),
				Color(tint, 0.85), 2.5, true)
		cx += gap
	# Rollers and legs underneath.
	for roller in range(18, int(length) - 8, 68):
		draw_circle(Vector2(roller, THICKNESS + 12.0), 9.0, Color("#1d2c35"))
		draw_arc(Vector2(roller, THICKNESS + 12.0), 9.0, 0.0, TAU, 18, RIB.darkened(0.35), 1.5, true)
		var spoke := Vector2.from_angle(clock * speed / 9.0) * 6.0
		draw_line(Vector2(roller, THICKNESS + 12.0) - spoke, Vector2(roller, THICKNESS + 12.0) + spoke, RIB.darkened(0.2), 1.5, true)
	if not suspended:
		for leg in range(40, int(length) - 20, 204):
			draw_rect(Rect2(leg, THICKNESS + 22.0, 16, 198), Color("#1a2931"))
	for end in [0.0, length]:
		draw_rect(Rect2(end - 4.0, -3.0, 8.0, THICKNESS + 6.0), Color("#3b4c55"))
		draw_rect(Rect2(end - 2.0, 2.0, 4.0, 8.0), tint)
