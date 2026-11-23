extends Node2D

## 시추 리그. The drilling rig that guards the bridge to the lab: a derrick at
## the right of the platform with a missile pod high on it, an absorber dish at
## chest height under the pod, and a drill that runs along an overhead rail and
## slams the deck.
##  · 1페이즈 추적: the pod fires homing missiles. Reflect one and it flies
##    home into the pod.
##  · 2페이즈 흡수: the pod is shut and its missiles only feed the suit. The
##    dish opens: a shockwave into it comes back as a heavy shell, and that
##    shell reflected into the dish is the hit.
##  · 3페이즈 굴착: both are open, two missiles at a time, the drill faster.
## The drill slams wherever Sera stands and sends a sweep both ways.
## The node sits at the world origin; everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal missile_launched(origin: Vector2, pod: Node2D)
signal echo_fired(origin: Vector2, direction: float)
signal drank(origin: Vector2)
signal drill_struck(x: float, hit_player: bool)

enum State { IDLE, AIM, RECOVER, DOWN }
enum Drill { WAIT, TRACK, DROP, RISE }

const Sera = preload("res://scripts/sera.gd")
const Texts = preload("res://texts.gd")
const HITS := 3
const FLOOR_Y := 520.0
const FACE_X := 860.0
const POD := Vector2(944.0, 236.0)
const DISH := Vector2(884.0, 432.0)
const POD_RADIUS := 50.0
const DISH_RADIUS := 58.0
const RAIL_Y := 108.0
const DRILL_TOP := 170.0
const DRILL_MIN := 140.0
const DRILL_MAX := 800.0
const STEEL := Color("#283439")
const PLATE := Color("#5a6a70")
const DARK := Color("#0e171c")
const AMBER := Color("#ffae66")
const ICE := Color("#84ebff")
const RED := Color("#ff7251")

var player: Sera
var health := HITS
var state := State.IDLE
var left := 1.2
var dormant := false
var clock := 0.0
var flash := 0.0
var charge_left := -1.0
var drill := Drill.WAIT
var drill_left := 4.0
var drill_x := 500.0
var drill_y := DRILL_TOP
## The point a reflected missile flies home to.
var pod_mark: Node2D
var missiles_out := 0


func _ready() -> void:
	pod_mark = Node2D.new()
	pod_mark.position = POD + Vector2(0.0, 40.0)
	add_child(pod_mark)


func reset_attempt() -> void:
	flash = 0.0
	charge_left = -1.0
	drill = Drill.WAIT
	drill_left = _drill_rest()
	drill_y = DRILL_TOP
	missiles_out = 0
	if health > 0:
		state = State.IDLE
		left = 1.3
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	state = State.IDLE
	left = 1.0
	drill_left = 3.0
	return true


func pod_open() -> bool:
	return health == 3 or health == 1


func dish_open() -> bool:
	return health <= 2 and health > 0


func is_charging() -> bool:
	return charge_left >= 0.0


func is_open() -> bool:
	return state != State.DOWN and (pod_open() or is_charging())


func open_ratio() -> float:
	return 1.0


func status_text() -> String:
	if state == State.DOWN:
		return Texts.RIG_STATUS_STOPPED
	return Texts.RIG_STATUS_POD if pod_open() else Texts.RIG_STATUS_DISH


func drill_threat() -> bool:
	return drill == Drill.TRACK or drill == Drill.DROP


func max_missiles() -> int:
	return 2 if health == 1 else 1


## A shockwave reached the open dish: it drinks and fires it back shortly.
func drink() -> bool:
	if not dish_open() or is_charging() or state == State.DOWN:
		flash = 0.3
		return false
	charge_left = 0.9
	drank.emit(DISH)
	return true


## A reflected shot reached `part` ("pod" or "dish"). True when it counted.
func hit(part: String) -> bool:
	var open := pod_open() if part == "pod" else dish_open()
	if not open or state == State.DOWN:
		flash = 0.3
		return false
	health -= 1
	charge_left = -1.0
	if health == 0:
		state = State.DOWN
		drill = Drill.RISE
		return true
	state = State.RECOVER
	left = 1.8
	return true


func _drill_rest() -> float:
	return 6.5 if health == 3 else (5.5 if health == 2 else 3.6)


func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta)
	_run_drill(delta)
	if state == State.DOWN or dormant:
		queue_redraw()
		return
	if charge_left >= 0.0:
		charge_left -= delta
		if charge_left < 0.0:
			echo_fired.emit(DISH + Vector2(-52.0, 3.0), -1.0)
	left = maxf(0.0, left - delta)
	if left == 0.0:
		match state:
			State.IDLE:
				if missiles_out < max_missiles():
					state = State.AIM
					left = 0.8
					attack_prepared.emit(false)
				else:
					left = 0.4
			State.AIM:
				missile_launched.emit(POD + Vector2(-40.0, -10.0), pod_mark)
				state = State.IDLE
				left = 2.6 if health == 3 else (3.0 if health == 2 else 2.0)
			State.RECOVER:
				state = State.IDLE
				left = 0.8
	queue_redraw()


func _run_drill(delta: float) -> void:
	match drill:
		Drill.WAIT:
			drill_y = move_toward(drill_y, DRILL_TOP, 260.0 * delta)
			if dormant or state == State.DOWN:
				return
			drill_left -= delta
			if drill_left <= 0.0:
				drill = Drill.TRACK
				drill_left = 1.1 if health > 1 else 0.85
				attack_prepared.emit(true)
		Drill.TRACK:
			if is_instance_valid(player):
				drill_x = move_toward(drill_x, clampf(player.global_position.x, DRILL_MIN, DRILL_MAX), 520.0 * delta)
			drill_left -= delta
			if drill_left <= 0.0:
				drill = Drill.DROP
		Drill.DROP:
			drill_y = move_toward(drill_y, FLOOR_Y - 34.0, 1500.0 * delta)
			if drill_y >= FLOOR_Y - 34.0:
				var hit_player := false
				if is_instance_valid(player) and absf(player.global_position.x - drill_x) < 70.0 and player.global_position.y > FLOOR_Y - 90.0:
					hit_player = player.take_hit(signf(player.global_position.x - drill_x) if player.global_position.x != drill_x else 1.0)
				for side in [-1.0, 1.0]:
					attack_fired.emit(Vector2(drill_x + side * 48.0, FLOOR_Y - 10.0), side, true)
				drill_struck.emit(drill_x, hit_player)
				drill = Drill.RISE
				drill_left = 0.7
		Drill.RISE:
			drill_left -= delta
			if drill_left <= 0.0:
				drill = Drill.WAIT
				drill_left = _drill_rest()


func _draw() -> void:
	var dead := state == State.DOWN
	# The derrick: two legs, braces, a crown block.
	var top := Vector2(990.0, 40.0)
	draw_line(Vector2(FACE_X + 10.0, FLOOR_Y), top + Vector2(-26.0, 0.0), STEEL, 10.0)
	draw_line(Vector2(1150.0, FLOOR_Y), top + Vector2(26.0, 0.0), STEEL, 10.0)
	var y := FLOOR_Y - 60.0
	while y > 80.0:
		var t := (FLOOR_Y - y) / (FLOOR_Y - 40.0)
		var lx := lerpf(FACE_X + 10.0, top.x - 26.0, t)
		var rx := lerpf(1150.0, top.x + 26.0, t)
		draw_line(Vector2(lx, y), Vector2(rx, y - 60.0), PLATE.darkened(0.35), 3.0)
		draw_line(Vector2(rx, y), Vector2(lx, y - 60.0), PLATE.darkened(0.35), 3.0)
		y -= 60.0
	draw_rect(Rect2(top.x - 40.0, top.y - 20.0, 80.0, 24.0), PLATE)
	# The overhead rail the drill runs on.
	draw_rect(Rect2(60.0, RAIL_Y - 10.0, FACE_X - 40.0, 14.0), DARK)
	draw_line(Vector2(60.0, RAIL_Y - 9.0), Vector2(FACE_X + 20.0, RAIL_Y - 9.0), PLATE, 2.0)
	_draw_drill(dead)
	_draw_pod(dead)
	_draw_dish(dead)


func _draw_drill(dead: bool) -> void:
	var carriage := Vector2(drill_x, RAIL_Y)
	draw_rect(Rect2(carriage.x - 34.0, carriage.y - 18.0, 68.0, 26.0), STEEL)
	draw_line(carriage + Vector2(0.0, 8.0), Vector2(drill_x, drill_y - 40.0), DARK, 6.0)
	# The head: a motor block and a fluted bit.
	draw_rect(Rect2(drill_x - 30.0, drill_y - 46.0, 60.0, 30.0), PLATE.darkened(0.1))
	var spin := clock * (14.0 if drill_threat() else 3.0)
	var bit := PackedVector2Array([Vector2(drill_x - 22.0, drill_y - 16.0), Vector2(drill_x + 22.0, drill_y - 16.0), Vector2(drill_x, drill_y + 34.0)])
	draw_colored_polygon(bit, STEEL.lightened(0.1) if not dead else STEEL)
	for flute in 3:
		var offset := sin(spin + flute * 2.1) * 12.0
		draw_line(Vector2(drill_x + offset, drill_y - 14.0), Vector2(drill_x + offset * 0.3, drill_y + 22.0), PLATE.lightened(0.2), 2.0)
	if drill == Drill.TRACK:
		var pulse := 0.5 + 0.5 * sin(clock * 22.0)
		draw_set_transform(Vector2(drill_x, FLOOR_Y + 4.0), 0.0, Vector2(1.0, 0.25))
		draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 40, Color(RED, 0.5 + 0.4 * pulse), 4.0, true)
		draw_circle(Vector2.ZERO, 70.0, Color(RED, 0.12 + 0.1 * pulse))
		draw_set_transform(Vector2.ZERO)
		draw_dashed_line(Vector2(drill_x, drill_y + 36.0), Vector2(drill_x, FLOOR_Y), Color(RED, 0.4), 2.0, 10.0)


func _draw_pod(dead: bool) -> void:
	var open := pod_open() and not dead
	draw_rect(Rect2(POD.x - 46.0, POD.y - 40.0, 92.0, 80.0), STEEL)
	draw_rect(Rect2(POD.x - 46.0, POD.y - 40.0, 92.0, 6.0), PLATE)
	for row in 2:
		for column in 2:
			var tube := POD + Vector2(-18.0 + column * 36.0, -14.0 + row * 28.0)
			draw_circle(tube, 11.0, DARK)
			if open:
				var lit := state == State.AIM and row == 0 and column == 0
				draw_circle(tube, 6.0, Color(RED if lit else AMBER, 0.85 if lit else 0.35))
	if not open:
		# Armour shutters over the tubes.
		draw_rect(Rect2(POD.x - 44.0, POD.y - 32.0, 88.0, 70.0), PLATE.darkened(0.15))
		for x in [-30.0, -10.0, 10.0, 30.0]:
			draw_line(Vector2(POD.x + x, POD.y - 30.0), Vector2(POD.x + x, POD.y + 36.0), DARK, 2.0)
	if flash > 0.0:
		draw_rect(Rect2(POD.x - 48.0, POD.y - 42.0, 96.0, 84.0), Color(ICE, flash * 1.6), false, 3.0)


func _draw_dish(dead: bool) -> void:
	var open := dish_open() and not dead
	draw_line(DISH + Vector2(10.0, 0.0), DISH + Vector2(70.0, 0.0), DARK, 14.0)
	var glow := 0.0
	if is_charging():
		glow = 1.0 - charge_left / 0.9
	draw_set_transform(DISH, 0.0, Vector2(0.45, 1.0))
	draw_circle(Vector2.ZERO, DISH_RADIUS, DARK)
	draw_circle(Vector2.ZERO, DISH_RADIUS - 6.0, Color("#3b2f28").lerp(AMBER, 0.25 + 0.75 * glow) if open else PLATE.darkened(0.2))
	draw_arc(Vector2.ZERO, DISH_RADIUS, 0.0, TAU, 40, PLATE, 4.0, true)
	if open:
		for ring in 3:
			draw_arc(Vector2.ZERO, 16.0 + ring * 12.0, 0.0, TAU, 32, Color(AMBER, 0.35 + 0.4 * glow), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	if is_charging():
		var muzzle := DISH + Vector2(-52.0, 3.0)
		draw_dashed_line(muzzle, Vector2(0.0, muzzle.y), Color(AMBER, 0.3 + 0.5 * glow), 2.4, 12.0)
		draw_arc(muzzle, 30.0 - 16.0 * glow, 0.0, TAU, 30, Color(AMBER, 0.8), 2.5, true)
	if flash > 0.0 and not pod_open():
		draw_arc(DISH, DISH_RADIUS + 8.0, 0.0, TAU, 40, Color(ICE, flash * 2.0), 3.0, true)
