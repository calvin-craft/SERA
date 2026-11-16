extends Node2D

## Floor art for a one-screen boss arena, plus the aiming help both late bosses
## share: floor marks where a diagonal shot lines up, and a guide line while W
## is held. The stage supplies aim_marks(), aim_target() and aim_width().

@export var iron := Color("#28363b")
@export var shade := Color("#102029")
@export var edge := Color("#778d95")
@export var accent := Color("#f7b47b")
@export var live := Color("#83e8fd")

@onready var level = $"../.."


func _draw() -> void:
	draw_rect(Rect2(-120, 520, 1350, 270), shade)
	draw_rect(Rect2(-120, 520, 1350, 53), iron)
	draw_line(Vector2(-120, 520), Vector2(1230, 520), edge, 2.0)
	draw_line(Vector2(-120, 570), Vector2(1230, 570), edge.darkened(0.39), 2.0)
	for x in range(-60, 1220, 97):
		draw_line(Vector2(x, 525), Vector2(x, 570), shade, 2.0)
		draw_circle(Vector2(x + 8, 532), 1.9, edge)
		draw_circle(Vector2(x + 8, 563), 1.9, edge)
	for x in range(-29, 1120, 154):
		draw_rect(Rect2(x, 575, 13, 134), iron)
		draw_line(Vector2(x + 15, 581), Vector2(x + 148, 699), iron, 7.0)
	if level.complete:
		return
	var target: Vector2 = level.aim_target()
	var lit: bool = target.is_finite()
	for mark: Vector2 in level.aim_marks():
		var tint := live if lit else accent
		draw_rect(Rect2(mark.x - 38.0, mark.y + 2.0, 76.0, 9.0), shade)
		draw_line(Vector2(mark.x - 38.0, mark.y + 5.0), Vector2(mark.x + 38.0, mark.y + 5.0), tint, 3.0, true)
		for x in [mark.x - 38.0, mark.x + 38.0]:
			draw_line(Vector2(x, mark.y - 15.0), Vector2(x, mark.y + 1.0), Color(tint, 0.75), 2.0, true)
	if not lit or not Input.is_action_pressed(&"aim_up"):
		return
	var from: Vector2 = level.sera.release_origin(true)
	var direction := Vector2(level.sera.facing, -1.0).normalized()
	var offset := target - from
	var along := offset.dot(direction)
	var aligned: bool = along > 0.0 and along < level.WAVE_RANGE and absf(offset.cross(direction)) < level.aim_width()
	var length: float = along if aligned else level.WAVE_RANGE * 0.65
	draw_dashed_line(from, from + direction * length, Color(live, 0.78) if aligned else Color("#a1b1bb"), 1.8, 9.0)
	if aligned:
		draw_arc(target, 40.0, 0.0, TAU, 44, Color(live, 0.85), 1.8, true)
