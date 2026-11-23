extends Node2D

## 에코. Sera's old partner, in the prototype suit that gives back whatever it
## takes. A mirror match on one floor:
##  · He fires bolts from his hands, two to a volley. Catch one for force and
##    reflect the other into him: struck by his own shot he loses his balance.
##  · A shockwave while he has his balance is caught and fired back as a heavy
##    amber shell (catch it for a full suit, or reflect it into him).
##  · Off balance (균형 붕괴) for a moment, a shockwave is a hit.
##  · From the second phase he slides across the floor (jump it) and leaps to
##    stomp the deck with a downward release (two sweeps), and some volleys
##    come high, over a standing Sera's head.
##  · In the last phase the room's gravity field switches on and off, and he
##    turns the first reflected shot of each volley back once more.
## The node is Echo himself, standing at its position.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
## A shell he sends back: what he caught, or a reflected shot turned again.
signal echo_fired(origin: Vector2, direction: float, heavy: bool)
signal drank(origin: Vector2)
signal staggered(origin: Vector2)
signal stomped(origin: Vector2, hit_player: bool)

enum State { IDLE, WALK, AIM, RECOVER, CATCH, SLIDE_WINDUP, SLIDE, LEAP, STOMP, STAGGER, DOWN }

const Sera = preload("res://scripts/sera.gd")
const Texts = preload("res://texts.gd")
const HITS := 3
const FLOOR_Y := 520.0
const MIN_X := 110.0
const MAX_X := 1040.0
const CHEST := 92.0
const HIT_RADIUS := 50.0
const STAGGER_TIME := 2.5
const WALK_SPEED := 190.0
const SLIDE_SPEED := 820.0
const LEAP_SPEED := 900.0
const GRAVITY := 1500.0
const SUIT := Color("#2b2f36")
const PLATE := Color("#6d6a66")
const LIGHT := Color("#e9e2d6")
const AMBER := Color("#ffae66")
const ICE := Color("#84ebff")
const RED := Color("#ff7251")

var player: Sera
## The room's gravity field: he floats in it too.
var field: Node2D
var health := HITS
var state := State.IDLE
var left := 1.0
var duration := 1.0
var dormant := false
var facing := -1.0
var velocity := Vector2.ZERO
var home := Vector2.ZERO
var clock := 0.0
var glow := 0.0
var step := 0
var shots_left := 0
var high_volley := false
var rally_ready := false
var walk_goal := 0.0
var slide_goal := 0.0
var hurt_flash := 0.0
## Reflected shots flying at him, counted by the stage: he does not leap,
## slide or walk away from one already on its way.
var returns_in_flight := 0


func _ready() -> void:
	home = position


func phase() -> int:
	return HITS - health + 1


func reset_attempt() -> void:
	position = home
	velocity = Vector2.ZERO
	glow = 0.0
	step = 0
	shots_left = 0
	rally_ready = false
	hurt_flash = 0.0
	if health > 0:
		_enter(State.IDLE, 1.2)
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	_enter(State.IDLE, 0.9)
	return true


func chest_point() -> Vector2:
	var drop := 40.0 if state == State.SLIDE or state == State.SLIDE_WINDUP else 0.0
	return position + Vector2(0.0, -CHEST + drop)


func is_open() -> bool:
	return state == State.STAGGER


func open_ratio() -> float:
	return left / duration if is_open() and duration > 0.0 else 0.0


func status_text() -> String:
	if state == State.DOWN:
		return Texts.ECHO_STATUS_STOPPED
	return Texts.ECHO_STATUS_OPEN if is_open() else Texts.ECHO_STATUS_GUARD


func shot_coming() -> bool:
	return state == State.AIM


func slide_coming() -> bool:
	return state == State.SLIDE_WINDUP or state == State.SLIDE


func airborne() -> bool:
	return position.y < FLOOR_Y - 1.0


## A shockwave reached him. True when it was a hit (he was off balance);
## otherwise he caught it and will fire it back.
func take_wave() -> bool:
	if state == State.DOWN or dormant:
		return false
	if state == State.STAGGER:
		health -= 1
		hurt_flash = 0.6
		velocity = Vector2(-facing * 260.0, -260.0)
		if health == 0:
			_enter(State.DOWN, 0.0)
		else:
			step = 0
			_enter(State.RECOVER, 1.6)
		return true
	_face_player()
	velocity.x = 0.0
	glow = 1.0
	_enter(State.CATCH, 0.62)
	drank.emit(chest_point())
	return false


## A reflected shot reached him. Returns "stagger", "rally" or "absorb".
func take_returned(heavy: bool) -> String:
	if state == State.DOWN or state == State.STAGGER or dormant:
		return "absorb"
	if state == State.CATCH:
		glow = 1.0
		return "absorb"
	if rally_ready and not airborne():
		rally_ready = false
		_face_player()
		echo_fired.emit(chest_point() + Vector2(facing * 42.0, 0.0), facing, heavy)
		glow = 0.6
		return "rally"
	velocity = Vector2(-facing * 110.0, 0.0)
	_enter(State.STAGGER, STAGGER_TIME)
	staggered.emit(chest_point())
	return "stagger"


func _physics_process(delta: float) -> void:
	clock += delta
	glow = move_toward(glow, 1.0 if state == State.CATCH else 0.0, delta * 2.2)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	if not is_instance_valid(player):
		return
	var weight := 0.5 if _in_field() else 1.0
	if state == State.DOWN or dormant:
		_fall(delta, weight)
		queue_redraw()
		return
	left = maxf(0.0, left - delta)
	match state:
		State.IDLE:
			_face_player()
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			if left == 0.0:
				_next_move()
		State.WALK:
			_face_player()
			velocity.x = move_toward(velocity.x, signf(walk_goal - position.x) * WALK_SPEED, 900.0 * delta)
			if absf(walk_goal - position.x) < 12.0 or left == 0.0:
				velocity.x = 0.0
				_enter(State.IDLE, 0.25)
		State.AIM:
			_face_player()
			velocity.x = 0.0
			if left == 0.0:
				var height := 140.0 if high_volley else 85.0
				attack_fired.emit(position + Vector2(facing * 44.0, -height), facing, false)
				shots_left -= 1
				if shots_left > 0:
					_enter(State.AIM, 0.62 if phase() == 1 else 0.5)
					attack_prepared.emit(false)
				else:
					_enter(State.RECOVER, 1.1 if phase() < 3 else 0.9)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if left == 0.0:
				_enter(State.IDLE, 0.3)
		State.CATCH:
			velocity.x = 0.0
			if left == 0.0:
				echo_fired.emit(chest_point() + Vector2(facing * 46.0, 0.0), facing, true)
				_enter(State.RECOVER, 0.9)
		State.SLIDE_WINDUP:
			velocity.x = 0.0
			if left == 0.0:
				_enter(State.SLIDE, 2.0)
		State.SLIDE:
			var heading := signf(slide_goal - position.x)
			velocity.x = heading * SLIDE_SPEED
			_slide_contact()
			if absf(slide_goal - position.x) < 20.0 or left == 0.0:
				velocity.x = 0.0
				_enter(State.RECOVER, 0.8)
		State.LEAP:
			if velocity.y >= 0.0:
				# The top of the leap: a downward release drives him into the deck.
				velocity = Vector2(0.0, 1300.0)
				_enter(State.STOMP, 2.0)
		State.STOMP:
			if not airborne():
				_land_stomp()
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if left == 0.0:
				_enter(State.RECOVER, 0.5)
	_fall(delta, weight)
	queue_redraw()


func _fall(delta: float, weight: float) -> void:
	if airborne() or velocity.y < 0.0:
		velocity.y = minf(velocity.y + GRAVITY * weight * delta, 1400.0)
	position += velocity * delta
	position.x = clampf(position.x, MIN_X, MAX_X)
	if position.y >= FLOOR_Y:
		position.y = FLOOR_Y
		if velocity.y > 0.0:
			velocity.y = 0.0


func _in_field() -> bool:
	return is_instance_valid(field) and field.active() and field.contains(position + Vector2(0.0, -60.0))


func _face_player() -> void:
	var gap := player.global_position.x - position.x
	if absf(gap) > 4.0:
		facing = signf(gap)


## The moves cycle per phase; between them he keeps his distance.
func _next_move() -> void:
	var plans := [
		["volley", "walk", "volley", "walk"],
		["volley", "slide", "high", "leap", "volley", "walk"],
		["volley", "leap", "high", "slide", "volley", "leap"],
	]
	var plan: Array = plans[clampi(phase() - 1, 0, 2)]
	var move: String = plan[step % plan.size()]
	if returns_in_flight > 0 and move != "volley" and move != "high":
		_enter(State.IDLE, 0.1)
		return
	step += 1
	match move:
		"volley", "high":
			high_volley = move == "high"
			shots_left = 2
			rally_ready = phase() == 3
			_enter(State.AIM, 0.75 if phase() == 1 else 0.6)
			attack_prepared.emit(false)
		"walk":
			var side := signf(position.x - player.global_position.x)
			if side == 0.0:
				side = 1.0
			# Out of reach of a shockwave, but only a few steps out.
			walk_goal = clampf(player.global_position.x + side * 360.0, MIN_X + 20.0, MAX_X - 20.0)
			if absf(walk_goal - player.global_position.x) < 250.0:
				walk_goal = clampf(player.global_position.x - side * 360.0, MIN_X + 20.0, MAX_X - 20.0)
			_enter(State.WALK, 1.6)
		"slide":
			_face_player()
			slide_goal = MAX_X - 30.0 if facing > 0.0 else MIN_X + 30.0
			_enter(State.SLIDE_WINDUP, 0.65)
			attack_prepared.emit(true)
		"leap":
			_face_player()
			var flight := 2.0 * LEAP_SPEED / (GRAVITY * (0.5 if _in_field() else 1.0))
			var reach := clampf(player.global_position.x - position.x, -620.0, 620.0)
			velocity = Vector2(reach / maxf(flight * 0.5, 0.3), -LEAP_SPEED)
			_enter(State.LEAP, 3.0)
			attack_prepared.emit(true)


func _slide_contact() -> void:
	var gap := player.global_position.x - position.x
	if absf(gap) < 42.0 and player.global_position.y > FLOOR_Y - 58.0:
		player.take_hit(signf(velocity.x) if velocity.x != 0.0 else facing)


func _land_stomp() -> void:
	velocity = Vector2.ZERO
	var hit_player := false
	if absf(player.global_position.x - position.x) < 60.0 and player.global_position.y > FLOOR_Y - 80.0:
		hit_player = player.take_hit(signf(player.global_position.x - position.x) if player.global_position.x != position.x else 1.0)
	for side in [-1.0, 1.0]:
		attack_fired.emit(Vector2(position.x + side * 46.0, FLOOR_Y - 10.0), side, true)
	stomped.emit(position, hit_player)
	_enter(State.RECOVER, 1.0)


func _enter(next_state: State, time: float) -> void:
	state = next_state
	left = time
	duration = time


func _draw() -> void:
	var f := facing
	var dead := state == State.DOWN
	var trim := AMBER.lerp(Color.WHITE, hurt_flash)
	if state == State.SLIDE or state == State.SLIDE_WINDUP:
		_draw_slide(f, trim)
		return
	var crouch := 0.0
	var lean := 0.0
	match state:
		State.LEAP:
			crouch = 0.35
		State.STOMP:
			crouch = 0.1
		State.CATCH:
			lean = -0.08 * f
		State.STAGGER:
			lean = -0.32 * f + sin(clock * 30.0) * 0.03
		State.DOWN:
			crouch = 0.9
			lean = 0.25 * f
	var walking := state == State.WALK
	var stride := sin(clock * 11.0) * 18.0 if walking else 0.0
	var hip := Vector2(0.0, -70.0 + crouch * 30.0)
	var shoulder := hip + Vector2(lean * 60.0, -54.0)
	var head := shoulder + Vector2(lean * 20.0 + f * 3.0, -22.0)
	# Legs.
	for side in [-1.0, 1.0]:
		var foot := Vector2(side * 12.0 + stride * side, 0.0) if not airborne() else Vector2(side * 10.0, -16.0 - crouch * 20.0)
		var knee := (hip + foot) * 0.5 + Vector2(f * (8.0 + crouch * 16.0), 0.0)
		draw_line(hip + Vector2(side * 8.0, 0.0), knee, SUIT, 11.0)
		draw_line(knee, foot, SUIT, 10.0)
		draw_line(foot + Vector2(-f * 4.0, 0.0), foot + Vector2(f * 12.0, 0.0), PLATE, 5.0)
	# Torso.
	var torso := PackedVector2Array([hip + Vector2(-14.0, 4.0), hip + Vector2(14.0, 4.0), shoulder + Vector2(18.0, 0.0), shoulder + Vector2(-18.0, 0.0)])
	draw_colored_polygon(torso, SUIT.lightened(0.05))
	draw_line(hip + Vector2(-14.0, 0.0), hip + Vector2(14.0, 0.0), trim, 3.0)
	# Back unit, the store for what he catches.
	draw_rect(Rect2(shoulder.x - f * 26.0 - 8.0, shoulder.y + 4.0, 16.0, 36.0), SUIT.darkened(0.2))
	# Arms: hands up for a catch, one hand out to fire, otherwise low.
	var hand_a := shoulder + Vector2(f * 10.0, 46.0)
	var hand_b := shoulder + Vector2(-f * 6.0, 48.0)
	if state == State.AIM or state == State.CATCH or state == State.RECOVER:
		hand_a = shoulder + Vector2(f * 42.0, 22.0)
		hand_b = shoulder + Vector2(f * 36.0, 30.0) if state == State.CATCH else hand_b
	for hand in [hand_b, hand_a]:
		var elbow: Vector2 = (shoulder + hand) * 0.5 + Vector2(0.0, 8.0)
		draw_line(shoulder, elbow, SUIT, 9.0)
		draw_line(elbow, hand, SUIT, 8.0)
		draw_circle(hand, 6.0, PLATE)
	# Head and visor.
	draw_circle(head, 14.0, SUIT.lightened(0.08))
	draw_line(head + Vector2(-f * 2.0, -2.0), head + Vector2(f * 12.0, -2.0), trim if not dead else PLATE, 4.0)
	# The chest disc: amber while it holds force, cold blue when he is off balance.
	var disc := shoulder + Vector2(f * 4.0, 22.0)
	var tint := ICE if state == State.STAGGER else AMBER
	draw_circle(disc, 10.0, Color("#1a1d22"))
	draw_circle(disc, 7.0, Color("#3b2f28").lerp(tint, 0.3 + 0.7 * maxf(glow, 1.0 if state == State.STAGGER else 0.0)))
	if glow > 0.05:
		draw_circle(disc, 18.0 + 10.0 * glow, Color(AMBER, 0.2 * glow), true, -1.0, true)
	if state == State.AIM:
		var charge := 1.0 - left / duration if duration > 0.0 else 1.0
		var muzzle := Vector2(f * 44.0, -140.0 if high_volley else -85.0)
		draw_circle(muzzle, 4.0 + 8.0 * charge, Color(AMBER, 0.55), true, -1.0, true)
		draw_dashed_line(muzzle, muzzle + Vector2(f * 600.0, 0.0), Color(AMBER, 0.2 + 0.45 * charge), 1.6, 12.0)
	if state == State.STAGGER:
		var spin := clock * 5.0
		draw_arc(disc, 34.0, spin, spin + 4.0, 30, Color(ICE, 0.8), 2.5, true)
		draw_arc(Vector2(0.0, -CHEST), 54.0, -PI * 0.5, -PI * 0.5 + TAU * open_ratio(), 40, Color(ICE, 0.75), 2.4, true)
	if state == State.LEAP or state == State.STOMP:
		draw_set_transform(Vector2(0.0, FLOOR_Y - position.y + 4.0), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 60.0, Color(RED, 0.18))
		draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 32, Color(RED, 0.6), 3.0, true)
		draw_set_transform(Vector2.ZERO)


func _draw_slide(f: float, trim: Color) -> void:
	var winding := state == State.SLIDE_WINDUP
	if winding:
		# Crouched, one hand on the deck, the trail line ahead of him.
		var charge := 1.0 - left / duration if duration > 0.0 else 1.0
		draw_dashed_line(Vector2(f * 30.0, -12.0), Vector2(f * 900.0, -12.0), Color(RED, 0.25 + 0.45 * charge), 2.0, 10.0)
		draw_line(Vector2(-f * 10.0, 0.0), Vector2(0.0, -40.0), SUIT, 12.0)
		draw_line(Vector2(0.0, -40.0), Vector2(f * 6.0, -84.0), SUIT, 16.0)
		draw_circle(Vector2(f * 10.0, -98.0), 14.0, SUIT.lightened(0.08))
		draw_line(Vector2(f * 8.0, -100.0), Vector2(f * 22.0, -100.0), trim, 4.0)
		draw_line(Vector2(f * 4.0, -70.0), Vector2(f * 34.0, -6.0), SUIT, 8.0)
		return
	# Feet first along the deck, low enough to jump.
	draw_line(Vector2(f * 46.0, -8.0), Vector2(-f * 4.0, -16.0), SUIT, 12.0)
	draw_line(Vector2(-f * 4.0, -16.0), Vector2(-f * 46.0, -34.0), SUIT.lightened(0.05), 18.0)
	draw_circle(Vector2(-f * 58.0, -44.0), 13.0, SUIT.lightened(0.08))
	draw_line(Vector2(-f * 56.0, -46.0), Vector2(-f * 44.0, -46.0), trim, 4.0)
	for streak in 4:
		var y := -6.0 - streak * 10.0
		draw_line(Vector2(-f * (70.0 + streak * 16.0), y), Vector2(-f * (150.0 + streak * 30.0), y), Color(AMBER, 0.35 - streak * 0.07), 2.0)
