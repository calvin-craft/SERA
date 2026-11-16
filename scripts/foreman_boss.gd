extends Node2D

## 포어맨. The plant's supervisor and the last boss, one phase per act:
##   1 차폐      Holds its ground behind a shield, firing bolts and sweeps. Cut
##               the shield relay with a diagonal shot, then hit the chest core.
##   2 돌진      Charges across the arena. It cannot be jumped: face it, brace
##               and take the charge, then hit the core while it is stunned.
##   3 관성 방출  Climbs onto the wheel and sheds its momentum as falling loads.
##               Catch the blue-lit one and hit the raised core diagonally.
## The node sits at the world origin; everything here is in world coordinates.

signal attack_prepared(sweep: bool)
signal attack_fired(origin: Vector2, direction: float, sweep: bool)
signal charge_prepared
signal charge_caught(origin: Vector2, charge: int, precise: bool)
signal braked(origin: Vector2)
signal load_caught(origin: Vector2, charge: int)
signal load_crashed(point: Vector2, hit_player: bool)

enum State { IDLE, BOLT_WARN, BOLT_FLY, SWEEP_WARN, SWEEP_FLY, BRAKE, REV, CHARGE, STUN, CLIMB, PERCH, LOCK, DROP, OPEN, DOWN }

const Sera = preload("res://scripts/sera.gd")
const DropLoad = preload("res://scripts/drop_load.gd")
const Texts = preload("res://texts.gd")
const ART := "res://assets/characters/foreman.png"
const HITS := 3
const FLOOR_Y := 520.0
const HOME_X := 930.0
const FAR_X := 190.0
const BODY_HALF := 74.0
const CHARGE_SPEED := 700.0
const REV_TIME := 0.9
const STUN_TIME := 2.8
const OPEN_TIME := 3.2
const CORE_WIDTH := 46.0
const PERCH_CORE := Vector2(900.0, 251.0)
## Standing here lines the diagonal shot up with the perched core.
const PERCH_AIM_X := 703.0
## How far the service lift raises it: high enough to be out of reach, low enough to stay under the HUD.
const PERCH_LIFT := 180.0
const DROP_FROM_Y := 70.0
const SWEEP_PORT := Vector2(1066.0, 510.0)
const ICE := Color("#84ebff")
const RED := Color("#ff7251")
const AMBER := Color("#ffc186")
const STEEL := Color("#2a3238")
const PLATE := Color("#8d979b")
const BLACK := Color("#10181d")

var player: Sera
var health := HITS
var state := State.IDLE
var state_left := 1.2
var state_duration := 1.2
var x := HOME_X
var direction := -1.0
var shield_cut := false
var dormant := false
var perch := 0.0
var climb_from := HOME_X
var drop_x := 576.0
var heavy := false
var drops := 0
var sweep_warning := 0.0
var flash := 0.0
var clock := 0.0
var art: Texture2D

@onready var cargo: DropLoad = $Load


func _ready() -> void:
	cargo.caught.connect(_on_cargo_caught)
	cargo.crashed.connect(_on_cargo_crashed)
	if ResourceLoader.exists(ART):
		art = load(ART)


## Starts the current phase over, as on a retry or a restored checkpoint.
func reset_attempt() -> void:
	cargo.clear()
	flash = 0.0
	sweep_warning = 0.0
	drops = 0
	x = HOME_X
	direction = -1.0
	perch = 0.0
	match health:
		3:
			_enter(State.IDLE, 1.2)
		2:
			_enter(State.BRAKE, 1.4)
		1:
			perch = 1.0
			_enter(State.PERCH, 1.5)
		_:
			_enter(State.DOWN, 0.0)
	queue_redraw()


func go_dormant() -> void:
	if health > 0:
		dormant = true


func wake() -> bool:
	if not dormant:
		return false
	dormant = false
	return true


func is_open() -> bool:
	return (health == HITS and shield_cut) or state == State.STUN or state == State.OPEN


func open_ratio() -> float:
	if state == State.STUN or state == State.OPEN:
		return state_left / state_duration
	return 1.0 if is_open() else 0.0


func status_text() -> String:
	match health:
		3:
			return Texts.WHEEL_STATUS_SHIELD_CUT if shield_cut else Texts.WHEEL_STATUS_SHIELDED
		2:
			return Texts.WHEEL_STATUS_STUNNED if state == State.STUN else Texts.WHEEL_STATUS_CHARGING
		1:
			return Texts.WHEEL_STATUS_OPEN if state == State.OPEN else Texts.WHEEL_STATUS_SHEDDING
		_:
			return Texts.WHEEL_STATUS_STOPPED


func is_shielded() -> bool:
	return health == HITS and not shield_cut


func is_charging() -> bool:
	return state == State.REV or state == State.CHARGE


func threatens_from_above() -> bool:
	return state == State.LOCK or state == State.DROP


func core_point() -> Vector2:
	if health <= 1:
		return PERCH_CORE
	return Vector2(x + direction * 30.0, FLOOR_Y - 89.0)


func cut_shield() -> void:
	shield_cut = true
	queue_redraw()


func hit_core() -> bool:
	if not is_open():
		flash = 0.3
		return false
	health -= 1
	cargo.clear()
	sweep_warning = 0.0
	match health:
		2:
			_enter(State.BRAKE, 1.5)
		1:
			climb_from = x
			drops = 0
			_enter(State.CLIMB, 1.3)
		_:
			_enter(State.DOWN, 0.0)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	clock += delta
	flash = maxf(0.0, flash - delta)
	cargo.advance(delta, player)
	if state == State.DOWN or dormant:
		queue_redraw()
		return
	if sweep_warning > 0.0:
		sweep_warning -= delta
		if sweep_warning <= 0.0:
			attack_fired.emit(SWEEP_PORT, -1.0, true)
	state_left = maxf(0.0, state_left - delta)
	match state:
		State.CHARGE:
			_run_charge(delta)
		State.CLIMB:
			var ratio := 1.0 - state_left / state_duration
			perch = smoothstep(0.0, 1.0, ratio)
			x = lerpf(climb_from, HOME_X, perch)
		State.PERCH:
			drop_x = move_toward(drop_x, clampf(player.global_position.x, 130.0, 760.0), 300.0 * delta)
	if state_left == 0.0:
		_advance()
	queue_redraw()


func _advance() -> void:
	match state:
		State.IDLE, State.SWEEP_FLY:
			_enter(State.BOLT_WARN, 0.7)
			attack_prepared.emit(false)
		State.BOLT_WARN:
			attack_fired.emit(Vector2(x - 88.0, FLOOR_Y - 85.0), -1.0, false)
			_enter(State.BOLT_FLY, 1.3)
		State.BOLT_FLY:
			_enter(State.SWEEP_WARN, 0.8)
			attack_prepared.emit(true)
		State.SWEEP_WARN:
			attack_fired.emit(Vector2(x - 88.0, FLOOR_Y - 10.0), -1.0, true)
			_enter(State.SWEEP_FLY, 1.0)
		State.BRAKE, State.STUN:
			var side := signf(player.global_position.x - x)
			direction = side if side != 0.0 else -direction
			_enter(State.REV, REV_TIME)
			charge_prepared.emit()
		State.REV:
			_enter(State.CHARGE, 6.0)
		State.CHARGE:
			_enter(State.BRAKE, 0.7)
		State.CLIMB:
			perch = 1.0
			x = HOME_X
			direction = -1.0
			_enter(State.PERCH, 1.0)
		State.PERCH:
			# Red-lit slab first, then the blue-lit load that can be caught.
			heavy = drops % 2 == 0
			_enter(State.LOCK, 0.85)
			attack_prepared.emit(heavy)
		State.LOCK:
			_enter(State.DROP, 3.0)
			cargo.drop(Vector2(drop_x, DROP_FROM_Y), FLOOR_Y, heavy)
		State.DROP, State.OPEN:
			_enter(State.PERCH, 0.8)


func _run_charge(delta: float) -> void:
	x += direction * CHARGE_SPEED * delta
	if player.integrity > 0:
		var body := player.global_position
		var gap := body.x - x
		if body.y > FLOOR_Y - 160.0 and absf(gap) < BODY_HALF + 22.0:
			if gap * direction > 0.0 and player.can_absorb() and player.facing == -direction:
				var precise := player.absorb_age <= player.PERFECT_WINDOW
				var charge := mini(100 if precise else 80, player.CAPACITY - player.energy)
				player.absorb(charge, false)
				x -= direction * 40.0
				_enter(State.STUN, STUN_TIME)
				charge_caught.emit(Vector2(body.x + player.facing * 36.0, FLOOR_Y - 62.0), charge, precise)
				return
			player.take_hit(direction)
	var limit := HOME_X if direction > 0.0 else FAR_X
	if (x - limit) * direction >= 0.0:
		x = limit
		_enter(State.BRAKE, 0.7)
		braked.emit(Vector2(x + direction * BODY_HALF, FLOOR_Y - 30.0))


func _on_cargo_caught(origin: Vector2, charge: int) -> void:
	drops += 1
	_enter(State.OPEN, OPEN_TIME)
	load_caught.emit(origin, charge)


func _on_cargo_crashed(point: Vector2, hit_player: bool) -> void:
	drops += 1
	if state == State.DROP:
		if heavy:
			# The slab is followed by a sweep from the wall under the perch.
			sweep_warning = 0.8
			attack_prepared.emit(true)
			_enter(State.PERCH, 1.7)
		else:
			_enter(State.PERCH, 0.9)
	load_crashed.emit(point, hit_player)


func _enter(next_state: State, duration: float) -> void:
	state = next_state
	state_left = duration
	state_duration = duration


func _draw() -> void:
	if health <= 1 or state == State.CLIMB:
		_draw_sweep_port()
	if threatens_from_above():
		_draw_drop_zone()
	var base := Vector2(x, FLOOR_Y - perch * PERCH_LIFT)
	var shake := Vector2.ZERO
	if state == State.REV:
		shake = Vector2(sin(clock * 70.0) * 3.0 * (1.0 - state_left / REV_TIME), 0.0)
	if perch > 0.0:
		_draw_perch_arm(base)
	draw_set_transform(base + shake, 0.0, Vector2(direction, 1.0))
	if art:
		var size := Vector2(230.0, 230.0 * art.get_height() / art.get_width())
		# The painting faces left; the transform mirrors it for a rightward charge.
		draw_set_transform(base + shake, 0.0, Vector2(-direction, 1.0))
		draw_texture_rect(art, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false, Color("#7d8a8d") if state == State.DOWN else Color.WHITE)
	else:
		_draw_body()
	draw_set_transform(Vector2.ZERO)
	_draw_core()
	if is_shielded():
		var glow := 0.13 + flash * 1.8 + sin(clock * 5.0) * 0.025
		draw_set_transform(Vector2(x - 12.0, FLOOR_Y - 96.0), 0.0, Vector2(0.86, 1.0))
		draw_circle(Vector2.ZERO, 128.0, Color(RED, glow * 0.4), true, -1.0, true)
		draw_arc(Vector2.ZERO, 128.0, 0.16, TAU - 0.16, 60, Color(RED, glow * 2.0), 3.2, true)
		draw_arc(Vector2.ZERO, 120.0, -2.8, -0.8, 30, Color("#ffe1aa", glow), 5.0, true)
		draw_set_transform(Vector2.ZERO)
	_draw_warnings()


## Drawn facing right, centred on the floor point under the body.
func _draw_body() -> void:
	var dead := state == State.DOWN
	var lamp := AMBER
	if dead:
		lamp = Color("#5d686e")
	elif state == State.STUN:
		lamp = ICE
	elif is_charging() and int(clock * 14.0) % 2 == 0:
		lamp = Color("#fff0d0")
	# Tracks.
	draw_rect(Rect2(-BODY_HALF, -34.0, BODY_HALF * 2.0, 34.0), BLACK)
	for wheel in range(int(-BODY_HALF) + 16, int(BODY_HALF), 29):
		draw_circle(Vector2(wheel, -15.0), 12.0, Color("#1c2830"))
		draw_arc(Vector2(wheel, -15.0), 12.0, 0.0, TAU, 18, PLATE.darkened(0.45), 1.5, true)
	draw_line(Vector2(-BODY_HALF, -34.0), Vector2(BODY_HALF, -34.0), PLATE.darkened(0.3), 2.0)
	# Torso, shoulders and the heavy plate it leads with.
	draw_colored_polygon(PackedVector2Array([Vector2(-58, -34), Vector2(-64, -150), Vector2(-20, -176), Vector2(46, -168), Vector2(62, -34)]), STEEL)
	draw_polyline(PackedVector2Array([Vector2(-64, -150), Vector2(-20, -176), Vector2(46, -168)]), PLATE, 2.0, true)
	draw_rect(Rect2(-52.0, -66.0, 100.0, 8.0), BLACK)
	for stripe in range(-48, 44, 16):
		draw_line(Vector2(stripe, -59.0), Vector2(stripe + 8, -66.0), AMBER.darkened(0.25), 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(46, -160), Vector2(80, -146), Vector2(84, -52), Vector2(60, -40)]),
		PLATE if state != State.STUN else PLATE.darkened(0.4))
	for rib in 5:
		draw_line(Vector2(54, -142.0 + rib * 20.0), Vector2(81, -134.0 + rib * 19.0), STEEL, 2.5)
	# Head: a hard hat over a visor slit.
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -176), Vector2(-24, -204), Vector2(20, -208), Vector2(36, -190), Vector2(34, -172)]), Color("#39444a"))
	draw_rect(Rect2(-34.0, -182.0, 74.0, 7.0), AMBER.darkened(0.2) if not dead else Color("#5d686e"))
	draw_rect(Rect2(2.0, -196.0, 30.0, 7.0), BLACK)
	draw_rect(Rect2(5.0, -194.0, 24.0, 3.0), lamp)
	# Radiator on its back.
	for fin in 5:
		draw_rect(Rect2(-72.0, -140.0 + fin * 18.0, 12.0, 11.0), Color("#1d262c"))
	if state == State.CHARGE:
		for i in 4:
			draw_line(Vector2(-BODY_HALF - 8.0 - i * 18.0, -40.0 - i * 24.0), Vector2(-BODY_HALF - 60.0 - i * 26.0, -40.0 - i * 24.0), Color(RED, 0.5 - i * 0.1), 3.0, true)


func _draw_perch_arm(base: Vector2) -> void:
	# The service lift that carries it up beside the wheel: two masts and a platform.
	for mast in [HOME_X - 96.0, HOME_X + 96.0]:
		draw_rect(Rect2(mast - 7.0, FLOOR_Y - PERCH_LIFT - 40.0, 14.0, PERCH_LIFT + 40.0), BLACK)
		draw_line(Vector2(mast - 3.0, FLOOR_Y - PERCH_LIFT - 40.0), Vector2(mast - 3.0, FLOOR_Y), Color("#4a5a62"), 2.0)
		for rung in range(int(FLOOR_Y - PERCH_LIFT), int(FLOOR_Y), 30):
			draw_rect(Rect2(mast - 7.0, rung, 14.0, 4.0), Color("#33424a"))
	draw_rect(Rect2(base.x - 112.0, base.y, 224.0, 16.0), STEEL)
	draw_line(Vector2(base.x - 112.0, base.y + 1.0), Vector2(base.x + 112.0, base.y + 1.0), PLATE, 2.0)
	for stripe in range(int(base.x) - 104, int(base.x) + 100, 22):
		draw_line(Vector2(stripe, base.y + 13.0), Vector2(stripe + 10, base.y + 5.0), AMBER.darkened(0.3), 2.5, true)


func _draw_core() -> void:
	var point := core_point()
	if health <= 1 and perch < 1.0:
		return
	var open := is_open()
	var tint := ICE if open else AMBER
	if state == State.DOWN:
		tint = Color("#5d686e")
	draw_circle(point, 27.0, BLACK, true, -1.0, true)
	draw_circle(point, 23.0, Color("#3e4b4d"), true, -1.0, true)
	draw_arc(point, 23.0, 0.0, TAU, 36, Color("#b2a19a"), 1.6, true)
	draw_circle(point, 16.0, Color(tint, 0.34), true, -1.0, true)
	if open:
		var breathe := 0.58 + sin(clock * 16.0) * 0.18
		if state == State.STUN or state == State.OPEN:
			draw_arc(point, 33.0, -PI * 0.5, -PI * 0.5 + TAU * state_left / state_duration, 44, Color(ICE, 0.9), 2.8, true)
		draw_circle(point, 11.0 + 4.0 * breathe, Color(ICE, breathe), true, -1.0, true)
		draw_circle(point, 6.0 + breathe * 2.0, Color("#ecffff"), true, -1.0, true)
	else:
		draw_line(point + Vector2(-12, -3), point + Vector2(12, -3), tint, 3.0, true)
		draw_line(point + Vector2(-9, 4), point + Vector2(9, 4), Color(tint, 0.54), 2.0, true)
		if flash > 0.0 and not is_shielded():
			draw_arc(point, 27.0 + (0.3 - flash) * 80.0, -PI, PI, 40, Color(AMBER, flash * 2.5), 3.0, true)


func _draw_warnings() -> void:
	if state == State.BOLT_WARN or state == State.SWEEP_WARN:
		var sweep := state == State.SWEEP_WARN
		var charge := 1.0 - state_left / state_duration
		var point := Vector2(x - 88.0, FLOOR_Y - (10.0 if sweep else 85.0))
		var tint := RED if sweep else ICE
		draw_dashed_line(point, point - Vector2(812, 0), Color(tint, 0.31 + charge * 0.43), 2.0, 10.0)
		draw_circle(point, 7.0 + charge * 8.0, Color(tint, 0.56), true, -1.0, true)
		draw_arc(point, 21.0 - charge * 7.0, 0.0, TAU, 32, tint, 2.0, true)
	elif state == State.REV:
		var rev := 1.0 - state_left / REV_TIME
		var from := Vector2(x + direction * (BODY_HALF + 10.0), FLOOR_Y - 60.0)
		for row in 3:
			draw_dashed_line(from + Vector2(0.0, row * 26.0 - 26.0), from + Vector2(direction * 780.0, row * 26.0 - 26.0), Color(RED, 0.25 + 0.45 * rev), 2.0, 14.0)
		draw_arc(from, 26.0 - 10.0 * rev, 0.0, TAU, 30, RED, 2.5, true)
	elif state == State.STUN:
		var top := Vector2(x, FLOOR_Y - 232.0)
		for i in 3:
			var angle := clock * 6.0 + TAU * i / 3.0
			draw_circle(top + Vector2(cos(angle) * 30.0, sin(angle) * 9.0), 4.0, Color("#fff3cc"))
	if flash > 0.0 and is_shielded():
		draw_arc(Vector2(x - 12.0, FLOOR_Y - 96.0), 128.0 + (0.3 - flash) * 60.0, 0.0, TAU, 60, Color("#ffe1aa", flash * 2.0), 3.0, true)


func _draw_sweep_port() -> void:
	var warming := sweep_warning > 0.0
	draw_rect(Rect2(SWEEP_PORT.x - 16.0, SWEEP_PORT.y - 34.0, 32.0, 44.0), STEEL)
	draw_rect(Rect2(SWEEP_PORT.x - 12.0, SWEEP_PORT.y - 30.0, 24.0, 5.0), Color("#6f858c"))
	draw_circle(SWEEP_PORT + Vector2(-10.0, -6.0), 6.0, RED if warming else Color("#5b4a44"))
	if warming:
		var charge := 1.0 - sweep_warning / 0.8
		draw_dashed_line(SWEEP_PORT + Vector2(-18.0, 0.0), SWEEP_PORT + Vector2(-880.0, 0.0), Color(RED, 0.3 + 0.45 * charge), 2.0, 10.0)
		draw_arc(SWEEP_PORT + Vector2(-10.0, -6.0), 20.0 - 8.0 * charge, 0.0, TAU, 28, RED, 2.0, true)


func _draw_drop_zone() -> void:
	var tint := RED if heavy else ICE
	var pulse := 0.14 + 0.07 * sin(clock * 20.0)
	var half := DropLoad.HALF + (10.0 if heavy else 0.0)
	draw_rect(Rect2(drop_x - half, DROP_FROM_Y, half * 2.0, FLOOR_Y - DROP_FROM_Y), Color(tint, pulse * 0.45))
	draw_rect(Rect2(drop_x - half, FLOOR_Y - 15.0, half * 2.0, 14.0), Color(tint, pulse * 1.6))
	for edge in [-half, half]:
		draw_dashed_line(Vector2(drop_x + edge, DROP_FROM_Y), Vector2(drop_x + edge, FLOOR_Y), Color(tint, 0.55), 1.5, 9.0)
	if state == State.LOCK:
		DropLoad.draw_load(self, Vector2(drop_x + sin(clock * 22.0) * 2.0, DROP_FROM_Y), heavy, clock)
