extends AnimatableBody2D

enum Motion { BOTTOM, UP, TOP, DOWN }
const Sera = preload("res://scripts/sera.gd")
const HALF_WIDTH := 88.0
const TOP_Y := 687.0
const BOTTOM_Y := 1010.0

var rider: Sera
var powered := false
var motion := Motion.BOTTOM
var height := BOTTOM_Y
var boarding_time := 0.0


func power_on() -> void:
	powered = true
	queue_redraw()


func park(at_top: bool) -> void:
	motion = Motion.TOP if at_top else Motion.BOTTOM
	height = TOP_Y if at_top else BOTTOM_Y
	position.y = height
	boarding_time = 0.0
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not powered or not is_instance_valid(rider):
		return

	match motion:
		Motion.BOTTOM:
			var aboard := rider.is_on_floor() and absf(rider.position.x - position.x) < HALF_WIDTH - 14.0 \
				and absf(rider.position.y - BOTTOM_Y) < 5.0
			boarding_time = boarding_time + delta if aboard else 0.0
			if boarding_time >= 0.32:
				motion = Motion.UP
		Motion.UP, Motion.DOWN:
			var destination := TOP_Y if motion == Motion.UP else BOTTOM_Y
			height = move_toward(height, destination, 154.0 * delta)
			position.y = height
			if is_equal_approx(height, destination):
				motion = Motion.TOP if motion == Motion.UP else Motion.BOTTOM
				boarding_time = 0.0
		Motion.TOP:
			if rider.position.y > TOP_Y + 230.0 and absf(rider.position.x - position.x) < 198.0:
				motion = Motion.DOWN
	queue_redraw()


func _draw() -> void:
	var tint := Color("#69e6d2") if powered else Color("#bc9b74")
	draw_rect(Rect2(-HALF_WIDTH, 0, HALF_WIDTH * 2.0, 24.0), Color("#1c333c"))
	draw_rect(Rect2(-HALF_WIDTH, 0, HALF_WIDTH * 2.0, 4.0), Color("#99b8b9"))
	draw_rect(Rect2(-HALF_WIDTH, 20.0, HALF_WIDTH * 2.0, 4.0), Color("#0e1f27"))
	for x in range(-80, 80, 19):
		draw_line(Vector2(x, 7), Vector2(x - 8, 16), Color("#648080"), 3.0, true)
	draw_rect(Rect2(-26, 8, 52, 7), Color("#12252b"))
	draw_rect(Rect2(-21, 10, 42, 3), tint)
	for x in [-80.0, 70.0]:
		draw_rect(Rect2(x, -28.0, 10, 46), Color("#34535b"))
		draw_rect(Rect2(x + 2.0, -24.0, 6, 8), tint)
		draw_line(Vector2(x + 5.0, -29), Vector2(x + 5.0, to_local(Vector2(global_position.x, 458.0)).y),
			Color("#161f26"), 3.0, true)
	if motion == Motion.UP or motion == Motion.DOWN:
		draw_line(Vector2(-67, 25), Vector2(67, 25), Color(tint, 0.61), 2.0, true)
