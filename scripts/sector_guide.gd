extends Node2D

## Aiming help for diagonal shots in sector stages. While W is held it draws
## the line the upward shockwave will take, and lights up when that line meets
## a relay or a hovering drone. The stage adds this node itself.

const VALID := Color("#7deed9")
const GUIDE := Color("#b3c9ca")
const NEAR := 520.0

var level: Node


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if level == null or level.complete or not Input.is_action_pressed(&"aim_up"):
		return
	var sera = level.sera
	var origin: Vector2 = sera.release_origin(true)
	var direction := Vector2(sera.facing, -1.0).normalized()
	var reach: float = level.WAVE_RANGE
	var relevant := false
	var hit := Vector2.INF
	var hit_distance := reach
	for candidate: Array in level.aim_candidates():
		var point: Vector2 = candidate[0]
		if point.distance_to(sera.global_position) > NEAR:
			continue
		relevant = true
		var offset := point - origin
		var ahead := offset.dot(direction)
		if ahead > 0.0 and ahead <= hit_distance and absf(offset.cross(direction)) < candidate[1]:
			hit = point
			hit_distance = ahead
	if not relevant:
		return
	var tint := VALID if hit.is_finite() else GUIDE
	var length := hit_distance if hit.is_finite() else reach * 0.84
	draw_dashed_line(to_local(origin), to_local(origin + direction * length), Color(tint, 0.8), 1.8, 9.0)
	if hit.is_finite():
		draw_arc(to_local(hit), 45.0, 0.0, TAU, 48, Color(tint, 0.86), 1.8, true)
