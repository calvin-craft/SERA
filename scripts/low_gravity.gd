extends Node2D

## 저중력 실험실. A test room on Kelder where the gravity rig still runs. Inside
## the field Sera falls slowly, so a jump climbs about twice as high and a
## downward release throws her up a whole storey; shots crossing it slow down.
## The node sits at the bottom-left corner of the field.

const Sera = preload("res://scripts/sera.gd")
const FIELD := Color("#b49cff")
const MOTE := Color("#e2d8ff")

## Every field in the running scene, so shots can ask where they are.
static var zones: Array = []

@export var width := 800.0
@export var height := 600.0
## Gravity on Sera inside the field.
@export var gravity := 0.5
## How fast shots move inside the field.
@export var shot_scale := 0.6
## Seconds on and off; a zero off time keeps it on.
@export var on_time := 0.0
@export var off_time := 0.0
@export var phase := 0.0
## A switched-off field does nothing and shows only its frame.
@export var enabled := true

var target: Sera
var clock := 0.0
var strength := 1.0
var was_inside := false


## The slow-down for a shot at `point`: 1 outside every field.
static func time_scale_at(point: Vector2) -> float:
	for zone in zones:
		if is_instance_valid(zone) and zone.active() and zone.contains(point):
			return zone.shot_scale
	return 1.0


func _enter_tree() -> void:
	if not zones.has(self):
		zones.append(self)


func _exit_tree() -> void:
	zones.erase(self)


func _ready() -> void:
	clock = phase
	strength = 1.0 if active() else 0.0


func restart() -> void:
	clock = phase
	strength = 1.0 if active() else 0.0


func active() -> bool:
	return enabled and (off_time <= 0.0 or fposmod(clock, on_time + off_time) < on_time)


func warning() -> bool:
	return enabled and off_time > 0.0 and fposmod(clock, on_time + off_time) >= on_time + off_time - 0.8


func contains(point: Vector2) -> bool:
	var local := point - global_position
	return local.x >= 0.0 and local.x <= width and local.y <= 0.0 and local.y >= -height


## True while Sera is inside a working field.
func holds_target() -> bool:
	return is_instance_valid(target) and active() and contains(target.global_position + Vector2(0.0, -60.0))


func _physics_process(delta: float) -> void:
	clock += delta
	strength = move_toward(strength, 1.0 if active() else 0.0, delta * 2.5)
	if not is_instance_valid(target):
		return
	var inside := holds_target()
	if inside:
		target.gravity_scale = gravity
	elif was_inside:
		target.gravity_scale = 1.0
	was_inside = inside
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var level := strength
	if warning():
		level = maxf(level, 0.3 + 0.2 * sin(clock * 28.0))
	if level <= 0.02:
		draw_rect(Rect2(0.0, -height, width, height), Color(FIELD, 0.03), false, 1.0)
		return
	draw_rect(Rect2(0.0, -height, width, height), Color(FIELD, 0.05 * level))
	# Field emitters along the floor and the ceiling.
	for x in range(20, int(width), 120):
		draw_rect(Rect2(x - 10.0, -8.0, 20.0, 8.0), Color("#3a3352"))
		draw_rect(Rect2(x - 6.0, -6.0, 12.0, 3.0), Color(FIELD, 0.7 * level))
	draw_line(Vector2(0.0, -height), Vector2(width, -height), Color(FIELD, 0.35 * level), 2.0)
	# Motes drifting slowly upward.
	for index in 26:
		var lane := fposmod(index * 0.618034, 1.0)
		var x := width * lane
		var rise := fposmod(index * 97.0 + clock * (18.0 + 9.0 * fposmod(index * 0.37, 1.0)), height)
		var y := -rise
		var sway := sin(clock * 1.3 + index) * 6.0
		draw_circle(Vector2(x + sway, y), 2.0 + fposmod(index * 0.53, 1.0) * 2.0, Color(MOTE, 0.35 * level))
	for side in [0.0, width]:
		draw_line(Vector2(side, 0.0), Vector2(side, -height), Color(FIELD, 0.25 * level), 2.0)
