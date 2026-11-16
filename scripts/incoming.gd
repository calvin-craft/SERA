extends Node2D

signal absorbed(origin: Vector2, charge: int, precise: bool)
signal evaded(origin: Vector2)

const Sera = preload("res://scripts/sera.gd")
const BOLT_SPEED := 675.0
const SWEEP_SPEED := 596.0
const BOLT := Color("#64e6ff")
const SWEEP := Color("#ff633b")

var player: Sera
var direction := 1.0
var sweep := false
var age := 0.0
var evaded_player := false


func _physics_process(delta: float) -> void:
	age += delta
	if age >= 1.45:
		queue_free()
		return

	var from_x := global_position.x
	var next_x := from_x + (SWEEP_SPEED if sweep else BOLT_SPEED) * direction * delta
	var height := global_position.y
	var ray := PhysicsRayQueryParameters2D.create(global_position, Vector2(next_x, height), 1)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		queue_free()
		return
	if sweep:
		var floor_ray := PhysicsRayQueryParameters2D.create(Vector2(next_x, height), Vector2(next_x, height + 22.0), 1)
		if get_world_2d().direct_space_state.intersect_ray(floor_ray).is_empty():
			queue_free()
			return
	var player_pos := player.global_position
	var low := minf(from_x, next_x)
	var high := maxf(from_x, next_x)
	var within_height := height >= player_pos.y - 102.0 and height <= player_pos.y + 3.0
	if within_height and absf(player_pos.x - from_x) < 100.0:
		var hand_x := player_pos.x + player.facing * 36.0
		if not sweep and player.facing == -direction and player.can_absorb() and low - 14.0 <= hand_x and high + 14.0 >= hand_x:
			var precise := player.absorb_age <= player.PERFECT_WINDOW
			var charge := mini(82 if precise else 56, player.CAPACITY - player.energy)
			player.absorb(charge, false)
			absorbed.emit(Vector2(hand_x, height), charge, precise)
			queue_free()
			return
		if low - 23.0 <= player_pos.x and high + 23.0 >= player_pos.x and player.take_hit(direction):
			queue_free()
			return
	elif sweep and not evaded_player and low <= player_pos.x and high >= player_pos.x and height - player_pos.y > 19.0 and height - player_pos.y < 115.0:
		evaded_player = true
		evaded.emit(player.global_position)

	global_position.x = next_x
	queue_redraw()


func _draw() -> void:
	if sweep:
		_draw_sweep()
		return
	var tail := Vector2(-direction * 86.0, 0.0)
	draw_line(tail, Vector2(direction * 9.0, 0), Color(BOLT, 0.19), 17.0, true)
	draw_line(tail * 0.76, Vector2(direction * 12.0, 0), Color(BOLT, 0.76), 6.0, true)
	draw_circle(Vector2.ZERO, 13.0 + sin(age * 24.0) * 1.4, Color(BOLT, 0.31), true, -1, true)
	draw_line(tail * 0.31, Vector2(direction * 14.0, 0), Color("#e0fbff"), 3.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color("#e0fbff"), true, -1, true)


func _draw_sweep() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1.0))
	draw_polygon(PackedVector2Array([Vector2(-88, 8), Vector2(-17, -26), Vector2(5, -33),
		Vector2(31, 8)]), PackedColorArray([Color(SWEEP, 0.0), Color(SWEEP, 0.14), Color(SWEEP, 0.26), Color(SWEEP, 0.56)]))
	draw_line(Vector2(-79, 7), Vector2(31, 7), Color(SWEEP, 0.32), 9.0, true)
	draw_line(Vector2(-46, 7), Vector2(27, 7), Color("#ffb17a"), 2.0, true)
	for index in 3:
		var center := Vector2(-9.0 - index * 15.0, 5.0 + index)
		var radius := 32.0 - index * 6.0
		draw_arc(center, radius, -1.27, 0.08, 26, Color(SWEEP, 0.29 - index * 0.07), 8.0, true)
		draw_arc(center, radius, -1.22, 0.04, 26, Color("#ffc88a", 0.95 - index * 0.25), 2.0, true)
	draw_set_transform(Vector2.ZERO)
