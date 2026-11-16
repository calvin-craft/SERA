extends CharacterBody2D

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal crashed(origin: Vector2)

enum Phase { WATCH, WINDUP, RECOVERY, STAGGER }
const Sera = preload("res://scripts/sera.gd")
const ICE := Color("#7ce9ff")
const HEAT := Color("#ff7647")

@export var reinforced := false
@export var arena_start := 1236.0
@export var shielded := false

var target: Sera
var knocked_out := false
var phase := Phase.WATCH
var integrity := 1
var attack_sweep := false
var next_sweep := false
var attack_direction := -1.0
var attack_left := 0.0
var windup_time := 0.0
var turn_direction := 1.0
var knocked_airborne := false
var idle_time := 0.0
var home := Vector2.ZERO
var sprite_size := 0.435
var armor_tint := Color.WHITE
var shield_flash := 0.0
## Seconds until a defeated guard disappears; negative while it is still fighting
## or flying from the knockback.
var vanish_left := -1.0
const VANISH_DELAY := 2.2
const VANISH_FADE := 0.7

@onready var pivot: Node2D = $Pivot
@onready var armor: Sprite2D = $Pivot/Armor


func _ready() -> void:
	home = position
	if reinforced:
		sprite_size = 0.514
		armor_tint = Color("#f0cdb5")
	reset_guard()


func reset_guard() -> void:
	position = home
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	phase = Phase.WATCH
	integrity = 2 if reinforced else 1
	knocked_out = false
	knocked_airborne = false
	next_sweep = false
	attack_direction = -1.0
	attack_sweep = false
	attack_left = 0.62
	windup_time = 0.0
	shield_flash = 0.0
	pivot.position = Vector2(0.0, -58.0)
	pivot.rotation = 0.0
	armor.scale = Vector2.ONE * sprite_size
	armor.position.y = 59.0 - armor.texture.get_height() * sprite_size * 0.5
	armor.self_modulate = armor_tint
	armor.flip_h = false
	set_collision_layer_value(3, true)
	vanish_left = -1.0
	visible = true
	modulate.a = 1.0
	set_physics_process(true)
	queue_redraw()


func knockback(direction: float) -> void:
	integrity -= 1
	turn_direction = direction
	if integrity > 0:
		phase = Phase.STAGGER
		attack_left = 0.68
		next_sweep = true
		velocity = Vector2(direction * 355.0, -200.0)
		armor.self_modulate = Color("#fff3cc")
		return

	knocked_out = true
	knocked_airborne = true
	set_collision_layer_value(3, false)
	velocity = Vector2(direction * 900.0, -420.0)


func is_winding_up() -> bool:
	return not knocked_out and phase == Phase.WINDUP


func restore_defeated() -> void:
	integrity = 1
	knockback(1.0)
	velocity = Vector2.ZERO
	knocked_airborne = false
	# Guards beaten before a checkpoint are already gone when the room loads.
	_vanish()


func _vanish() -> void:
	vanish_left = 0.0
	visible = false
	set_physics_process(false)


func flash_shield() -> void:
	shield_flash = 0.28


func _physics_process(delta: float) -> void:
	idle_time += delta
	shield_flash = maxf(0.0, shield_flash - delta)
	velocity.y = minf(velocity.y + 1490.0 * delta, 980.0)
	if knocked_out:
		velocity.x = move_toward(velocity.x, 0.0, (1980.0 if is_on_floor() else 385.0) * delta)
	else:
		_update_attack(delta)

	move_and_slide()
	if knocked_out:
		_update_knockback(delta)
	else:
		_update_pose(delta)
	queue_redraw()


func _update_attack(delta: float) -> void:
	attack_left = maxf(0.0, attack_left - delta)
	if phase == Phase.STAGGER:
		velocity.x = move_toward(velocity.x, 0.0, (1650.0 if is_on_floor() else 300.0) * delta)
		if attack_left <= 0.0:
			phase = Phase.WATCH
			attack_left = 0.34
		return

	var desired_speed := 0.0
	if phase == Phase.WATCH and is_instance_valid(target):
		var offset := target.global_position - global_position
		if target.integrity > 0 and target.global_position.x >= arena_start and absf(offset.y) < 170.0 and absf(offset.x) < 620.0:
			var direction := signf(offset.x)
			if direction != 0.0:
				attack_direction = direction
			if attack_left <= 0.0 and absf(offset.x) <= 460.0:
				_start_windup()
			elif absf(offset.x) > 295.0:
				var roam_point := clampf(target.position.x, home.x - 88.0, home.x + 96.0)
				desired_speed = clampf((roam_point - position.x) * 3.0, -91.0, 91.0)
	elif phase == Phase.WINDUP and attack_left <= 0.0:
		_fire()
	elif phase == Phase.RECOVERY and attack_left <= 0.0:
		phase = Phase.WATCH
	velocity.x = move_toward(velocity.x, desired_speed, 690.0 * delta)


func _start_windup() -> void:
	phase = Phase.WINDUP
	attack_sweep = reinforced and next_sweep
	windup_time = 0.88 if attack_sweep else (0.66 if reinforced else 0.83)
	attack_left = windup_time
	attack_prepared.emit(attack_sweep)


func _fire() -> void:
	phase = Phase.RECOVERY
	attack_left = 0.69 if reinforced else 1.05
	next_sweep = not attack_sweep
	var height := -10.0 if attack_sweep else -85.0
	attack_fired.emit(global_position + Vector2(attack_direction * 38.0, height), attack_direction, attack_sweep)


func _update_pose(delta: float) -> void:
	armor.flip_h = attack_direction > 0.0
	var lean := sin(idle_time * 4.0) * 0.022
	var vertical_scale := 1.0 + sin(idle_time * 4.0) * 0.016
	var tint := armor_tint
	match phase:
		Phase.WINDUP:
			var charge := 1.0 - attack_left / windup_time
			lean = attack_direction * (0.17 if attack_sweep else -0.13) * charge
			vertical_scale = 1.0 - charge * 0.075
			tint = armor_tint.lerp(HEAT if attack_sweep else ICE, charge * 0.42)
		Phase.RECOVERY:
			lean = attack_direction * 0.17 * clampf(attack_left / 0.37, 0.0, 1.0)
		Phase.STAGGER:
			lean = turn_direction * attack_left * 0.57
			tint = Color("#fff0d0")
	pivot.rotation = lerpf(pivot.rotation, lean, minf(1.0, delta * 13.0))
	armor.scale.y = sprite_size * vertical_scale
	armor.position.y = 59.0 - armor.texture.get_height() * armor.scale.y * 0.5
	armor.self_modulate = armor.self_modulate.lerp(tint, minf(1.0, delta * 12.0))


func _update_knockback(delta: float) -> void:
	if is_on_floor() and knocked_airborne:
		knocked_airborne = false
		crashed.emit(global_position)
		vanish_left = VANISH_DELAY
	if vanish_left > 0.0:
		vanish_left = maxf(0.0, vanish_left - delta)
		if vanish_left < VANISH_FADE:
			# Flicker out like a powered-down machine.
			var fade := vanish_left / VANISH_FADE
			modulate.a = fade * (0.45 if int(vanish_left * 24.0) % 2 == 0 else 1.0)
		if vanish_left == 0.0:
			_vanish()
			return
	var target_angle := 1.44 if is_on_floor() else 0.82
	pivot.rotation = move_toward(pivot.rotation, target_angle * turn_direction, 5.8 * delta)
	# Keep the lowest boot above the ground as the upright sprite turns sideways.
	var boot := Vector2(126.0 * turn_direction, 162.0) * armor.scale + armor.position
	pivot.position.y = -maxf(57.0, boot.rotated(pivot.rotation).y)
	armor.self_modulate = armor.self_modulate.lerp(Color(0.71, 0.82, 0.86), delta * 5.0)


func _draw() -> void:
	if knocked_out:
		return
	if shielded:
		_draw_shield()
	var height := -191.0 if reinforced else -162.0
	var plate_color := Color("#ffad82") if reinforced else ICE
	for index in (2 if reinforced else 1):
		var panel := Rect2(index * 22.0 - (21.0 if reinforced else 10.0), height, 19.0, 5.0)
		draw_rect(panel.grow(2.0), Color("#172029"))
		draw_rect(panel, plate_color if index < integrity else Color("#4b4544"))

	if not is_winding_up():
		return
	var progress := 1.0 - attack_left / windup_time
	var tint := HEAT if attack_sweep else ICE
	var point := Vector2(attack_direction * 40.0, -10.0 if attack_sweep else -85.0)
	var end := point + Vector2(attack_direction * 545.0, 0)
	var visible_tint := Color(tint, 0.29 + progress * 0.45)
	draw_dashed_line(point, end, visible_tint, 2.0 if attack_sweep else 1.0, 12.0)
	draw_circle(point, 9.0 + 9.0 * progress, Color(tint, 0.21), true, -1, true)
	draw_arc(point, 19.0 - 9.0 * progress, 0.0, TAU, 30, visible_tint, 2.0, true)
	draw_circle(point, 3.0 + progress * 3.0, Color("#fff9e5"), true, -1, true)


func _draw_shield() -> void:
	var glow := 0.13 + shield_flash * 1.8 + sin(idle_time * 5.0) * 0.025
	draw_set_transform(Vector2(attack_direction * 11.0, -77.0), 0.0, Vector2(0.83, 1.0))
	draw_circle(Vector2.ZERO, 95.0, Color(HEAT, glow * 0.42), true, -1.0, true)
	draw_arc(Vector2.ZERO, 95.0, 0.16, TAU - 0.16, 54, Color(HEAT, glow * 2.0), 3.2, true)
	draw_arc(Vector2.ZERO, 89.0, -2.8, -0.8, 26, Color("#ffe1aa", glow), 5.0, true)
	draw_set_transform(Vector2.ZERO)
