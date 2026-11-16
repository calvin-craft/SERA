extends StaticBody2D

## A door that is open only while it has power, so it closes again when a timed
## relay runs out. The node sits on the floor under the door.

const IRON := Color("#202e39")
const EDGE := Color("#80939a")
const AMBER := Color("#ff9f57")
const LIVE := Color("#74ead7")
const HEIGHT := 298.0
const CLEARANCE := 46.0

var powered := false
var open_ratio := 0.0
## While someone stands in the doorway the door will not come down on them.
var blocker: Node2D
var shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30.0, 412.0)
	shape.shape = box
	shape.position = Vector2(0.0, -206.0)
	add_child(shape)


func set_powered(value: bool) -> void:
	powered = value


func is_open() -> bool:
	return shape.disabled


func _physics_process(delta: float) -> void:
	var held := shape.disabled and is_instance_valid(blocker) and absf(blocker.global_position.x - global_position.x) < CLEARANCE
	var goal := 1.0 if powered or held else 0.0
	var before := open_ratio
	open_ratio = move_toward(open_ratio, goal, delta / (0.3 if goal > 0.5 else 0.36))
	var passable := open_ratio >= 0.8
	if passable != shape.disabled:
		shape.set_deferred(&"disabled", passable)
	if before != open_ratio:
		queue_redraw()


func _draw() -> void:
	var tint := LIVE if powered else AMBER
	var panel_top := -HEIGHT
	var panel_bottom := -smoothstep(0.0, 1.0, open_ratio) * HEIGHT
	draw_rect(Rect2(-40, panel_top - 34.0, 80, 40), Color("#11212c"))
	draw_rect(Rect2(-34, panel_top - 33.0, 68, 5), EDGE)
	draw_rect(Rect2(-27, panel_top - 20.0, 54, 9), Color(tint, 0.25))
	draw_rect(Rect2(-24, panel_top - 18.0, 48, 5), tint)
	for x in [-35.0, 23.0]:
		draw_rect(Rect2(x, panel_top, 12, -panel_top), IRON)
		draw_line(Vector2(x + 2, panel_top), Vector2(x + 2, 0), EDGE.darkened(0.38), 1.0, true)
	if panel_bottom >= panel_top + 1.0:
		draw_rect(Rect2(-15, panel_top, 30, panel_bottom - panel_top), Color("#33424a"))
		draw_line(Vector2(-10, panel_top), Vector2(-10, panel_bottom), EDGE.darkened(0.10), 2.0)
		draw_line(Vector2(10, panel_top), Vector2(10, panel_bottom), Color(tint, 0.71), 2.0, true)
		# Clock-face rivets mark this as the door that closes again.
		for y in range(ceili(panel_top) + 16, floori(panel_bottom) - 8, 34):
			draw_circle(Vector2(0, y), 5.0, Color("#171e27"))
			draw_arc(Vector2(0, y), 5.0, -PI * 0.5, PI, 12, Color(tint, 0.8), 1.5, true)
