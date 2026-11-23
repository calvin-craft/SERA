extends Node2D

signal absorbed(origin: Vector2, charge: int, precise: bool)
signal evaded(origin: Vector2)
## Sera's bracing hands turned the shot back (chapter three's reflect).
signal reflected(origin: Vector2, heavy: bool)

const Sera = preload("res://scripts/sera.gd")
const LowGravity = preload("res://scripts/low_gravity.gd")
const BOLT_SPEED := 675.0
const SWEEP_SPEED := 596.0
## A reflected shot goes back faster than it came.
const RETURN_SPEED := 1.3
const LIFE := 1.45
const BOLT := Color("#64e6ff")
const SWEEP := Color("#ff633b")
const HEAVY := Color("#c9f6ff")
## Shots on their way back, and the shells absorbers fire back at Sera.
const RETURNED := Color("#ffe09a")
const ECHO := Color("#ffae66")

var player: Sera
var direction := 1.0
var sweep := false
## A heavy shell: bigger, slower, and a full charge when caught.
var heavy := false
## An absorber's shell: Sera's own force coming back at her, drawn amber.
var echo := false
var age := 0.0
var evaded_player := false
## True once reflected: it flies along `velocity`, no longer hurts Sera, and
## the stage is asked each frame whether it struck something.
var returned := false
var velocity := Vector2.ZERO
## The stage that fired it. Its returned_hit(from, to, shot) decides hits.
var level: Node
## The machine that fired it, if any.
var source: Node


func _physics_process(delta: float) -> void:
	var slow := LowGravity.time_scale_at(global_position)
	var step := delta * slow
	age += step
	if age >= LIFE:
		queue_free()
		return
	if returned:
		_fly_back(step)
		return

	var from_x := global_position.x
	var pace := _pace()
	var next_x := from_x + pace * direction * step
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
		var at_hands := not sweep and player.facing == -direction and low - 14.0 <= hand_x and high + 14.0 >= hand_x
		if at_hands and player.can_reflect():
			_turn_back(Vector2(hand_x, height), pace)
			return
		if at_hands and player.can_absorb_shot():
			var precise := player.absorb_age <= player.PERFECT_WINDOW
			var gain := Sera.CAPACITY if heavy else (82 if precise else 56)
			var charge := mini(gain, player.CAPACITY - player.energy)
			player.absorb(charge, false, direction)
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


func _pace() -> float:
	return SWEEP_SPEED if sweep else (BOLT_SPEED * 0.82 if heavy else BOLT_SPEED)


## Back the way it came, or up and away when W was held for the reflect.
func _turn_back(at: Vector2, pace: float) -> void:
	var incoming := direction
	returned = true
	age = 0.0
	direction = -direction
	velocity = Vector2(direction, -1.0 if player.reflect_up else 0.0).normalized() * pace * RETURN_SPEED
	global_position = at + Vector2(direction * 8.0, 0.0)
	player.reflect_shot(incoming)
	reflected.emit(at, heavy)
	queue_redraw()


func _fly_back(step: float) -> void:
	var from := global_position
	var to := from + velocity * step
	var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1))
	var reach: Vector2 = wall["position"] if not wall.is_empty() else to
	if is_instance_valid(level) and level.has_method(&"returned_hit") and level.returned_hit(from, reach, self):
		queue_free()
		return
	if not wall.is_empty():
		queue_free()
		return
	global_position = to
	queue_redraw()


func _draw() -> void:
	if sweep:
		_draw_sweep()
		return
	var heading := velocity.normalized() if returned else Vector2(direction, 0.0)
	var tint := RETURNED if returned else (ECHO if echo else BOLT)
	var core := Color("#fff6dc") if returned or echo else Color("#e0fbff")
	if heavy:
		_draw_heavy(heading, tint, core)
		return
	var tail := -heading * 86.0
	draw_line(tail, heading * 9.0, Color(tint, 0.19), 17.0, true)
	draw_line(tail * 0.76, heading * 12.0, Color(tint, 0.76), 6.0, true)
	draw_circle(Vector2.ZERO, 13.0 + sin(age * 24.0) * 1.4, Color(tint, 0.31), true, -1, true)
	draw_line(tail * 0.31, heading * 14.0, core, 3.0, true)
	draw_circle(Vector2.ZERO, 5.0, core, true, -1, true)


func _draw_heavy(heading: Vector2, tint: Color, core: Color) -> void:
	var tail := -heading * 120.0
	draw_line(tail, heading * 12.0, Color(tint, 0.16), 30.0, true)
	draw_line(tail * 0.7, heading * 16.0, Color(tint, 0.7), 10.0, true)
	draw_circle(Vector2.ZERO, 24.0 + sin(age * 18.0) * 2.5, Color(tint, 0.28), true, -1, true)
	draw_arc(Vector2.ZERO, 17.0, age * 9.0, age * 9.0 + 4.4, 24, Color(HEAVY if tint == BOLT else core, 0.9), 3.0, true)
	draw_circle(Vector2.ZERO, 10.0, HEAVY if tint == BOLT else core, true, -1, true)
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE, true, -1, true)


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
