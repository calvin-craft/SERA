extends AnimatableBody2D

## A platform that runs back and forth between its start and start + travel,
## resting at each end. With needs_power it stays parked until something powers
## it. The node sits at the centre of the platform's top surface.

const DECK := Color("#1c333c")
const EDGE := Color("#99b8b9")
const LIVE := Color("#69e6d2")
const IDLE := Color("#bc9b74")

@export var travel := Vector2(400.0, 0.0)
@export var speed := 120.0
@export var half_width := 85.0
## Seconds parked at each end.
@export var wait := 0.9
## Initial boarding time before the first trip. A negative value uses wait.
@export var start_delay := -1.0
@export var needs_power := false

var home := Vector2.ZERO
var powered := true
var progress := 0.0
var heading := 1.0
var rest_left := 0.0
var moving := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	home = position
	powered = not needs_power
	rest_left = start_delay if start_delay >= 0.0 else wait
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(half_width * 2.0, 23.0)
	shape.shape = box
	shape.position = Vector2(0.0, 11.5)
	add_child(shape)


func set_powered(value: bool) -> void:
	if value != powered:
		powered = value
		queue_redraw()


## Back to the start end, as on a retry.
func park() -> void:
	progress = 0.0
	heading = 1.0
	rest_left = wait
	moving = false
	position = home
	reset_physics_interpolation()
	queue_redraw()


func _physics_process(delta: float) -> void:
	moving = false
	if not powered:
		return
	if rest_left > 0.0:
		rest_left -= delta
		return
	var span := travel.length()
	if span <= 0.0:
		return
	moving = true
	progress = clampf(progress + heading * speed * delta / span, 0.0, 1.0)
	position = home + travel * progress
	if progress == 0.0 or progress == 1.0:
		heading = -heading
		rest_left = wait
	queue_redraw()


func _draw() -> void:
	var tint := LIVE if powered else IDLE
	# Guide rail along the whole run, drawn in the platform's own space.
	var from := home - position
	var to := home + travel - position
	if absf(travel.y) > absf(travel.x):
		for x in [-half_width + 6.0, half_width - 6.0]:
			draw_line(Vector2(x, minf(from.y, to.y) - 40.0), Vector2(x, maxf(from.y, to.y) + 30.0), Color("#1d333e"), 6.0)
			draw_line(Vector2(x + 1.0, minf(from.y, to.y) - 40.0), Vector2(x + 1.0, maxf(from.y, to.y) + 30.0), Color("#3b5560"), 1.5)
	else:
		var rail_y := 34.0
		draw_line(Vector2(minf(from.x, to.x) - half_width, rail_y), Vector2(maxf(from.x, to.x) + half_width, rail_y), Color("#1d333e"), 7.0)
		draw_line(Vector2(minf(from.x, to.x) - half_width, rail_y - 2.0), Vector2(maxf(from.x, to.x) + half_width, rail_y - 2.0), Color("#3b5560"), 1.5)
		for hanger in [-half_width + 14.0, half_width - 14.0]:
			draw_rect(Rect2(hanger - 4.0, 22.0, 8.0, 14.0), Color("#34535b"))
	draw_rect(Rect2(-half_width, 0, half_width * 2.0, 24.0), DECK)
	draw_rect(Rect2(-half_width, 0, half_width * 2.0, 4.0), EDGE)
	draw_rect(Rect2(-half_width, 20.0, half_width * 2.0, 4.0), Color("#0e1f27"))
	for x in range(int(-half_width) + 8, int(half_width) - 4, 19):
		draw_line(Vector2(x, 7), Vector2(x - 8, 16), Color("#648080"), 3.0, true)
	draw_rect(Rect2(-26, 8, 52, 7), Color("#12252b"))
	draw_rect(Rect2(-21, 10, 42, 3), tint)
	for x in [-half_width, half_width - 8.0]:
		draw_rect(Rect2(x, -10.0, 8, 30), Color("#34535b"))
		draw_rect(Rect2(x + 2.0, -7.0, 4, 6), tint)
	if moving:
		draw_line(Vector2(-half_width + 18.0, 25), Vector2(half_width - 18.0, 25), Color(tint, 0.61), 2.0, true)
