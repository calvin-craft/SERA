extends Node2D

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)

const Sera = preload("res://scripts/sera.gd")
const WINDUP := 0.64
const ICE := Color("#79e8ff")

var target: Sera
var cooldown := 0.42
var windup_left := 0.0


func reset_valve() -> void:
	cooldown = 0.42
	windup_left = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if windup_left > 0.0:
		windup_left = maxf(0.0, windup_left - delta)
		if windup_left == 0.0:
			attack_fired.emit(global_position + Vector2(-26, -85), -1.0, false)
			cooldown = 1.30
	else:
		cooldown = maxf(0.0, cooldown - delta)
		var offset := target.global_position - global_position
		if cooldown == 0.0 and target.integrity > 0 and offset.x >= -450.0 and offset.x < -52.0 and absf(offset.y) < 75.0:
			windup_left = WINDUP
			attack_prepared.emit(false)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-14, -94, 32, 94), Color("#203940"))
	draw_rect(Rect2(-24, -13, 53, 13), Color("#1a3038"))
	draw_rect(Rect2(-22, -112, 59, 47), Color("#213d47"))
	draw_rect(Rect2(-21, -112, 56, 4), Color("#6a9398"))
	draw_rect(Rect2(-33, -95, 27, 20), Color("#12252e"))
	draw_rect(Rect2(-28, -91, 23, 11), Color("#42626c"))
	draw_line(Vector2(8, -56), Vector2(8, -23), Color("#5c777a"), 3.0, true)
	draw_circle(Vector2(20, -90), 6.0, Color("#e0ae76"), true, -1.0, true)
	var strength := 1.0 - windup_left / WINDUP if windup_left > 0.0 else 0.0
	var mouth := Vector2(-33, -85)
	draw_circle(mouth, 5.0 + 8.0 * strength, Color(ICE, 0.72), true, -1.0, true)
	if windup_left > 0.0:
		draw_dashed_line(mouth - Vector2(9, 0), mouth - Vector2(408, 0), Color(ICE, strength * 0.58), 1.4, 10.0)
		draw_arc(mouth, 12.0 + 11.0 * (1.0 - strength), 0.0, TAU, 26, Color(ICE, 0.65), 2.0, true)
