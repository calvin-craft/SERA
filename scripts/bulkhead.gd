extends StaticBody2D

const IRON := Color("#202e39")
const EDGE := Color("#80939a")
const AMBER := Color("#ff9f57")
const CYAN := Color("#75e7ff")

var unlocked := false
var open_ratio := 0.0

@onready var gate_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	set_physics_process(false)


func unlock(immediately: bool = false) -> void:
	if unlocked:
		return
	unlocked = true
	if immediately:
		open_ratio = 1.0
		gate_shape.set_deferred(&"disabled", true)
		queue_redraw()
		return
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	open_ratio = minf(1.0, open_ratio + delta / 0.46)
	if open_ratio >= 0.83 and not gate_shape.disabled:
		gate_shape.set_deferred(&"disabled", true)
	if open_ratio == 1.0:
		set_physics_process(false)
	queue_redraw()


func _draw() -> void:
	var tint := CYAN if unlocked else AMBER
	var panel_top := -298.0
	var panel_bottom := -smoothstep(0.0, 1.0, open_ratio) * 298.0
	draw_rect(Rect2(-40, panel_top - 34.0, 80, 40), Color("#11212c"))
	draw_rect(Rect2(-34, panel_top - 33.0, 68, 5), EDGE)
	draw_rect(Rect2(-27, panel_top - 20.0, 54, 9), Color(tint, 0.25))
	draw_rect(Rect2(-24, panel_top - 18.0, 48, 5), tint)
	for x in [-35.0, 23.0]:
		draw_rect(Rect2(x, panel_top, 12, -panel_top), IRON)
		draw_line(Vector2(x + 2, panel_top), Vector2(x + 2, 0), EDGE.darkened(0.38), 1.0, true)
	if panel_bottom >= panel_top + 1.0:
		draw_rect(Rect2(-15, panel_top, 30, panel_bottom - panel_top), Color("#3a454b"))
		draw_line(Vector2(-10, panel_top), Vector2(-10, panel_bottom), EDGE.darkened(0.10), 2.0)
		draw_line(Vector2(10, panel_top), Vector2(10, panel_bottom), Color(tint, 0.71), 2.0, true)
		for y in range(ceili(panel_top), floori(panel_bottom) - 11, 28):
			draw_line(Vector2(-13, y + 12), Vector2(13, y + 5), Color("#171e27"), 4.0, true)
