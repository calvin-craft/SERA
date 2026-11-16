extends Node2D

const Tower = preload("res://scripts/cooling_tower.gd")
const VALID := Color("#7deed9")
const GUIDE := Color("#b3c9ca")

@onready var level: Tower = $"../.."


func _draw() -> void:
	if not Input.is_action_pressed(&"aim_up"):
		return
	var relay := level.aim_target()
	if relay == null:
		return

	var sera := level.sera
	var origin := sera.release_origin(true)
	var direction := Vector2(sera.facing, -1.0).normalized()
	var offset := relay.global_position - origin
	var ahead := offset.dot(direction)
	var aligned := ahead > 0.0 and ahead <= level.WAVE_RANGE and absf(offset.cross(direction)) < relay.HIT_RADIUS
	var tint := VALID if aligned else GUIDE
	var distance := ahead if aligned else level.WAVE_RANGE * 0.84
	draw_dashed_line(to_local(origin), to_local(origin + direction * distance), Color(tint, 0.8), 1.8, 9.0)
	if aligned:
		draw_arc(to_local(relay.global_position), 45.0, 0.0, TAU, 48, Color(tint, 0.86), 1.8, true)
