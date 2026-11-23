extends CharacterBody2D

signal boost_started(origin: Vector2, direction: float, upward: bool)
signal shockwave(origin: Vector2, direction: Vector2)
signal landed(origin: Vector2, speed: float)
signal injured(origin: Vector2, remaining: int)
signal action_denied

enum State { MOVE, BRACE, CATCH, BOOST_WINDUP, BOOST, RELEASE, HURT }

const CAPACITY := 100
const MAX_INTEGRITY := 3
const BOOST_COST := 34
const RELEASE_COST := 50
const RUN_SPEED := 253.0
const GRAVITY := 1410.0
const JUMP_SPEED := 448.0
const BOOST_TIME := 0.235
const PERFECT_WINDOW := 0.22
const INPUT_WINDOW := 0.34
const JUMP_BUFFER := 0.13
const COYOTE_TIME := 0.085
## Speed of the hop a downward release gives: about 270 px straight up, enough
## for a 220 px container wall that a jump and an energy leap together cannot top.
const DOWN_LAUNCH := 873.0
## A bolt caught in the air carries Sera along with it, with a little lift.
const AIR_CATCH_PUSH := 300.0
const AIR_CATCH_HOP := 160.0
## Reflect: RMB pressed while bracing opens this window. A shot that reaches the
## hands inside it goes back the way it came (up and away with W held).
const REFLECT_WINDOW := 0.22
## After a reflect that met nothing, the hands need this long before the next try.
const REFLECT_LOCK := 0.42
const FALL_CAP := 980.0

var state := State.MOVE
var energy := 0
var integrity := MAX_INTEGRITY
var facing := 1.0
var launch_up := false
var release_up := false
var air_carry := false
var boost_left := 0.0
var hurt_left := 0.0
var empty_action := &""
var hint_left := 0.0
var airborne := false
var invulnerable_left := 0.0
var absorb_age := 1.0
var coyote_left := 0.0
var jump_left := 0.0
var action_left := 0.0
var buffered_action := &""
var buffered_up := false
var buffered_down := false
var forward_brace := false
## Abilities the stage switches on. Chapter one teaches the basics; later
## chapters add these from the stage where each first appears.
var air_absorb := false
var down_release := false
var release_down := false
## Chapter three: RMB while bracing turns an arriving shot back instead of firing.
var reflect := false
var reflect_age := 1.0
var reflect_up := false
var reflect_lock := 0.0
## Low-gravity rooms lower this while Sera is inside them.
var gravity_scale := 1.0

@onready var look: Node2D = $Look
@onready var sprite: AnimatedSprite2D = $Look/Sprite
@onready var timeline: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	timeline.animation_finished.connect(_on_action_finished)
	sprite.play(&"idle")


# The level calls this even during hitstop. The buffer ages with the player.
func read_input() -> void:
	if Input.is_action_just_pressed(&"absorb"):
		absorb_age = 0.0
	if Input.is_action_just_pressed(&"jump"):
		jump_left = JUMP_BUFFER
	if reflect and Input.is_action_just_pressed(&"release_force") and Input.is_action_pressed(&"absorb"):
		# Bracing hands meet the shot instead of firing: no shockwave, no cost.
		if reflect_lock <= 0.0 and reflect_age >= REFLECT_WINDOW:
			reflect_age = 0.0
			reflect_up = Input.is_action_pressed(&"aim_up")
	elif Input.is_action_just_pressed(&"release_force"):
		buffered_action = &"release_force"
		buffered_up = Input.is_action_pressed(&"aim_up")
		buffered_down = Input.is_action_pressed(&"aim_down")
		action_left = INPUT_WINDOW
	elif Input.is_action_just_pressed(&"boost"):
		buffered_action = &"boost"
		buffered_up = Input.is_action_pressed(&"aim_up")
		buffered_down = false
		action_left = INPUT_WINDOW


func _physics_process(delta: float) -> void:
	hint_left = maxf(0.0, hint_left - delta)
	absorb_age = minf(absorb_age + delta, 1.0)
	if reflect_age < REFLECT_WINDOW and reflect_age + delta >= REFLECT_WINDOW:
		# The window closed on nothing: a short wait stops RMB being mashed.
		reflect_lock = REFLECT_LOCK
	reflect_age = minf(reflect_age + delta, 1.0)
	reflect_lock = maxf(0.0, reflect_lock - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	sprite.self_modulate.a = 0.48 if invulnerable_left > 0.0 and int(invulnerable_left * 22.0) % 2 == 1 else 1.0
	var axis := Input.get_axis(&"move_left", &"move_right")
	var on_ground := is_on_floor()
	coyote_left = COYOTE_TIME if on_ground else maxf(0.0, coyote_left - delta)
	if not on_ground and (state != State.BOOST or launch_up):
		velocity.y = minf(velocity.y + GRAVITY * gravity_scale * delta, FALL_CAP * sqrt(gravity_scale))

	match state:
		State.MOVE, State.BRACE:
			_read_controls(axis, delta, on_ground)
		State.CATCH, State.BOOST_WINDUP, State.RELEASE:
			# A catch in the air keeps the push it gave; everything else plants her.
			if on_ground or state != State.CATCH:
				velocity.x = move_toward(velocity.x, 0.0, 3150.0 * delta)
		State.BOOST:
			boost_left -= delta
			if boost_left <= 0.0:
				state = State.MOVE
		State.HURT:
			hurt_left -= delta
			velocity.x = move_toward(velocity.x, 0.0, 880.0 * delta)
			if hurt_left <= 0.0 and integrity > 0:
				state = State.MOVE

	jump_left = maxf(0.0, jump_left - delta)
	action_left = maxf(0.0, action_left - delta)
	var impact_speed := velocity.y
	var belt_speed := get_platform_velocity().x if on_ground else 0.0
	move_and_slide()
	if not is_on_floor():
		# Leaving a moving belt or shuttle adds its speed; keep that extra reach in the air.
		if not airborne and belt_speed != 0.0 and absf(velocity.x) > RUN_SPEED + 20.0:
			air_carry = true
		airborne = true
	elif airborne:
		airborne = false
		air_carry = false
		if impact_speed > 230.0:
			landed.emit(global_position, impact_speed)
	_update_locomotion(axis, delta)


func _read_controls(axis: float, delta: float, on_ground: bool) -> void:
	if axis != 0.0:
		facing = signf(axis)

	state = State.MOVE
	if _use_buffered_action():
		return
	if coyote_left > 0.0 and jump_left > 0.0:
		velocity.y = -JUMP_SPEED
		jump_left = 0.0
		coyote_left = 0.0
	elif on_ground and Input.is_action_pressed(&"absorb"):
		state = State.BRACE
		velocity.x = move_toward(velocity.x, 0.0, 3900.0 * delta)
		return
	elif air_absorb and Input.is_action_pressed(&"absorb"):
		# Bracing in the air keeps the jump's course; only the hands come up.
		state = State.BRACE
		return

	if air_carry and not on_ground and (axis == 0.0 or signf(axis) == signf(velocity.x)):
		velocity.x = move_toward(velocity.x, signf(velocity.x) * RUN_SPEED, 550.0 * delta)
	else:
		var acceleration := 2400.0 if on_ground else 1520.0
		velocity.x = move_toward(velocity.x, axis * RUN_SPEED, acceleration * delta)


func _use_buffered_action() -> bool:
	if action_left <= 0.0:
		return false
	action_left = 0.0
	var cost := RELEASE_COST if buffered_action == &"release_force" else BOOST_COST
	if energy < cost:
		empty_action = buffered_action
		hint_left = 1.25
		action_denied.emit()
		return false

	hint_left = 0.0
	if buffered_action == &"release_force":
		release_down = buffered_down and down_release
		release_up = buffered_up and not release_down
		_start_action(State.RELEASE, &"burst", &"lift" if release_down else (&"burst_up" if release_up else &"burst"))
	else:
		launch_up = buffered_up
		_start_action(State.BOOST_WINDUP, &"boost", &"lift" if launch_up else &"dash")
	return true


func can_absorb() -> bool:
	return state == State.BRACE and is_on_floor() and Input.is_action_pressed(&"absorb")


## Bolts can also be caught in the air once air absorb has been learned.
func can_absorb_shot() -> bool:
	return state == State.BRACE and (is_on_floor() or air_absorb) and Input.is_action_pressed(&"absorb")


## True while a reflect press is waiting for a shot at the bracing hands.
func can_reflect() -> bool:
	return reflect and reflect_age < REFLECT_WINDOW and can_absorb_shot()


## A shot was turned back. Like a catch with nothing gained: the hands thrust
## out, and in the air the shove pushes Sera back a little and holds her up.
func reflect_shot(push: float = 0.0) -> void:
	reflect_age = 1.0
	reflect_lock = 0.0
	var airborne_return := not is_on_floor()
	velocity.x = 0.0
	hint_left = 0.0
	_start_action(State.CATCH, &"catch", &"burst_up" if reflect_up else &"burst")
	if airborne_return:
		velocity = Vector2(push * AIR_CATCH_PUSH * 0.5, -AIR_CATCH_HOP)
		air_carry = true


## `push` is the direction the caught thing was travelling. In the air the
## catch carries Sera that way; on her feet it only stops her.
func absorb(amount: int, overhead: bool = true, push: float = 0.0) -> void:
	energy = mini(CAPACITY, energy + amount)
	var airborne_catch := not is_on_floor() and push != 0.0
	velocity.x = 0.0
	hint_left = 0.0
	_start_action(State.CATCH, &"catch", &"catch" if overhead else &"catch_shot")
	if airborne_catch:
		velocity = Vector2(push * AIR_CATCH_PUSH, -AIR_CATCH_HOP)
		air_carry = true


func take_hit(direction: float) -> bool:
	if invulnerable_left > 0.0 or integrity == 0 or state == State.BOOST:
		return false
	integrity -= 1
	invulnerable_left = 0.95
	air_carry = false
	action_left = 0.0
	jump_left = 0.0
	_reset_pose()
	state = State.HURT
	hurt_left = 0.34
	velocity = Vector2(direction * 325.0, -240.0)
	sprite.play(&"hurt")
	injured.emit(global_position + Vector2(0, -60), integrity)
	return true


func reset_at(point: Vector2, charge: int) -> void:
	_reset_pose()
	global_position = point
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	integrity = MAX_INTEGRITY
	energy = charge
	state = State.MOVE
	facing = 1.0
	sprite.flip_h = false
	sprite.self_modulate.a = 1.0
	sprite.play(&"idle")
	airborne = false
	air_carry = false
	release_down = false
	action_left = 0.0
	jump_left = 0.0
	coyote_left = 0.0
	hint_left = 0.0
	absorb_age = 1.0
	reflect_age = 1.0
	reflect_lock = 0.0
	gravity_scale = 1.0
	invulnerable_left = 0.7


func _reset_pose() -> void:
	timeline.stop()
	look.scale = Vector2.ONE
	look.position = Vector2.ZERO
	look.rotation = 0.0


func _start_action(next_state: State, clip: StringName, frames: StringName) -> void:
	_reset_pose()
	state = next_state
	sprite.flip_h = facing < 0.0
	sprite.stop()
	sprite.play(frames)
	timeline.play(clip)


# Called by the method track in the boost clip.
func launch_boost() -> void:
	if state != State.BOOST_WINDUP:
		return
	energy -= BOOST_COST
	state = State.BOOST
	boost_left = BOOST_TIME
	air_carry = true
	coyote_left = 0.0
	velocity = Vector2(facing * (675.0 if launch_up else 950.0), -633.0 if launch_up else 0.0)
	boost_started.emit(global_position + Vector2(0.0, -44.0), facing, launch_up)


# Called at 0.10 seconds, when the palm thrust frame begins.
func emit_shockwave() -> void:
	if state == State.RELEASE:
		energy -= RELEASE_COST
		if release_down:
			# Fired at her own feet: the blast throws her straight up.
			velocity = Vector2(velocity.x * 0.35, -DOWN_LAUNCH)
			air_carry = false
			coyote_left = 0.0
			jump_left = 0.0
			shockwave.emit(release_origin_down(), Vector2.DOWN)
			return
		var direction := Vector2(facing, -1.0 if release_up else 0.0).normalized()
		shockwave.emit(release_origin(release_up), direction)


func release_origin(upward: bool) -> Vector2:
	return global_position + (Vector2(facing * 48.0, -119.0) if upward else Vector2(facing * 56.0, -89.0))


func release_origin_down() -> Vector2:
	return global_position + Vector2(0.0, -6.0)


func _on_action_finished(clip: StringName) -> void:
	look.scale = Vector2.ONE
	look.position = Vector2.ZERO
	if (clip == &"catch" and state == State.CATCH) or (clip == &"burst" and state == State.RELEASE):
		state = State.MOVE


func _update_locomotion(axis: float, delta: float) -> void:
	if state == State.BRACE:
		_blend_locomotion_pose(0.0, 1.0, delta)
		sprite.flip_h = facing < 0.0
		sprite.play(&"brace_shot" if forward_brace else &"brace")
	elif state == State.MOVE:
		if not is_on_floor():
			_blend_locomotion_pose(0.0, 1.0, delta)
			sprite.flip_h = facing < 0.0
			sprite.play(&"air" if velocity.y < -25.0 else &"fall")
		elif axis != 0.0 or absf(velocity.x) > 26.0:
			_update_run(axis, delta)
		else:
			_blend_locomotion_pose(0.0, 1.0, delta)
			sprite.flip_h = facing < 0.0
			sprite.play(&"idle")


func _update_run(axis: float, delta: float) -> void:
	var speed := absf(velocity.x)
	var direction := signf(velocity.x) if speed > 26.0 else facing
	var turning := sprite.flip_h != (direction < 0.0)
	var starting := sprite.animation == &"run_start"
	var running := sprite.animation == &"run" or starting
	sprite.flip_h = direction < 0.0
	if axis != 0.0 and speed < RUN_SPEED * 0.82 and (turning or not running):
		sprite.stop()
		sprite.play(&"run_start")
	elif not starting or not sprite.is_playing() or axis == 0.0:
		sprite.play(&"run", clampf(speed / RUN_SPEED, 0.48, 1.3))
	starting = sprite.animation == &"run_start"
	var lean := direction * (0.064 if starting else 0.026) if axis != 0.0 else 0.0
	var height := 0.97 if starting and sprite.frame == 0 else 1.0
	_blend_locomotion_pose(lean, height, delta)


func _blend_locomotion_pose(lean: float, height: float, delta: float) -> void:
	look.rotation = move_toward(look.rotation, lean, delta * 1.38)
	look.scale.y = move_toward(look.scale.y, height, delta * 0.85)
