extends Node2D

const Reactor = preload("res://scripts/reactor.gd")
const IRON := Color("#28363b")
const SHADE := Color("#102029")
const EDGE := Color("#778d95")
const AMBER := Color("#f7b47b")
const ICE := Color("#83e8fd")

@onready var level: Reactor = $"../.."


func _draw() -> void:
	_draw_platform()
	_draw_aim_overlay()


func _draw_platform() -> void:
	draw_rect(Rect2(-120, 520, 1350, 270), SHADE)
	draw_rect(Rect2(-120, 520, 1350, 53), IRON)
	draw_line(Vector2(-120, 520), Vector2(1230, 520), EDGE, 2.0)
	draw_line(Vector2(-120, 570), Vector2(1230, 570), EDGE.darkened(0.39), 2.0)
	for x in range(-60, 1220, 97):
		draw_line(Vector2(x, 525), Vector2(x, 570), SHADE, 2.0)
		draw_circle(Vector2(x + 8, 532), 1.9, EDGE)
		draw_circle(Vector2(x + 8, 563), 1.9, EDGE)
	for x in range(-29, 1120, 154):
		draw_rect(Rect2(x, 575, 13, 134), IRON)
		draw_line(Vector2(x + 15, 581), Vector2(x + 148, 699), IRON, 7.0)
	draw_rect(Rect2(801, 522, 320, 13), Color("#3b3431"))
	for x in range(809, 1112, 13):
		draw_line(Vector2(x, 531), Vector2(x + 7, 523), AMBER.darkened(0.33), 2.7, true)
	draw_line(Vector2(790, 520), Vector2(790, 497), AMBER.darkened(0.22), 2.0, true)


func _draw_aim_overlay() -> void:
	if level.complete or not level.boss.needs_aim_up():
		return
	var marker := Reactor.AIM_X
	var tint := ICE if level.boss.is_open() else AMBER
	draw_rect(Rect2(marker - 38.0, 522, 76.0, 9.0), SHADE)
	draw_line(Vector2(marker - 38, 525), Vector2(marker + 38, 525), tint, 3.0, true)
	if not Input.is_action_pressed(&"aim_up"):
		return
	var from := level.sera.release_origin(true)
	var direction := Vector2(level.sera.facing, -1.0).normalized()
	var offset := level.boss.core_point() - from
	var along := offset.dot(direction)
	var aligned := along > 0.0 and along < level.WAVE_RANGE and absf(offset.cross(direction)) < level.boss.CORE_WIDTH
	var length := along if aligned else level.WAVE_RANGE * 0.65
	draw_dashed_line(from, from + direction * length, Color(ICE, 0.78) if aligned else Color("#a1b1bb"), 1.8, 9.0)
