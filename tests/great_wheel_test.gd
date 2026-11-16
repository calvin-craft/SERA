extends SceneTree

const Pilot = preload("res://tests/pilot.gd")
const Wheel = preload("res://scripts/great_wheel.gd")
const SCENE := "res://scenes/great_wheel.tscn"
const NEXT := "res://scenes/foundry.tscn"

var pilot: Pilot
var wheel: Wheel


func _initialize() -> void:
	pilot = Pilot.new(self)
	_run.call_deferred()


func _run() -> void:
	await pilot.open(SCENE)
	wheel = current_scene as Wheel
	if await _shield_phase():
		if await _charge_phase():
			await _wheel_phase()
	await pilot.finish("dormant foreman, shield relay and chest core, charge that must be caught, loads from the wheel and the perched core, checkpoints, upward finale and loop")


func _shield_phase() -> bool:
	var boss := wheel.boss
	var sera := wheel.sera
	await pilot.frames(90)
	if not pilot.check(boss.dormant and boss.health == 3 and wheel.shots.get_child_count() == 0, "the Foreman waits until Sera steps forward"):
		return false
	pilot.check(await pilot.advance_to(wheel.RELAY_AIM_X), "the relay pad is reached")
	pilot.check(not boss.dormant and boss.is_shielded(), "stepping forward starts the fight behind a shield")
	if not pilot.check(await pilot.charge_to(50, 900), "its bolts recharge the suit"):
		return false
	await pilot.release()
	await pilot.until(func(): return boss.flash > 0.0, 50)
	pilot.check(boss.health == 3 and boss.flash > 0.0, "the shield turns a straight shockwave")
	await pilot.wait_control()
	if not pilot.check(await pilot.charge_to(50, 900), "recharge for the relay"):
		return false
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return wheel.relay.powered and not boss.is_shielded(), 60), "the diagonal shot from the pad cuts the shield"):
		return false
	await pilot.wait_control()
	if not pilot.check(await pilot.charge_to(50, 900), "recharge for the core"):
		return false
	await pilot.advance_to(600.0)
	await pilot.release()
	if not pilot.check(await pilot.until(func(): return boss.health == 2, 60), "a straight shockwave breaks the bared chest core"):
		return false
	await pilot.wait_control()
	return pilot.check(wheel.checkpoint == 1, "the first hit is a checkpoint")


func _charge_phase() -> bool:
	var boss := wheel.boss
	var sera := wheel.sera
	# Taking the charge unbraced hurts, and it cannot be jumped.
	if not pilot.check(await pilot.until(func(): return boss.state == boss.State.CHARGE, 300), "the second phase is a charge"):
		return false
	await pilot.until(func(): return absf(boss.x - sera.position.x) < 210.0, 120)
	await pilot.tap(&"jump")
	pilot.check(await pilot.until(func(): return sera.integrity < sera.MAX_INTEGRITY, 60), "a jump does not clear the Foreman")
	sera.integrity = sera.MAX_INTEGRITY
	# Bracing into it stops it and bares the core.
	var caught := false
	for attempt in 4:
		await pilot.until(func(): return boss.state == boss.State.REV and sera.state == sera.State.MOVE, 400)
		await pilot.face(signf(boss.x - sera.position.x))
		if await pilot.absorb_until(func(): return boss.state == boss.State.STUN or boss.state == boss.State.BRAKE, 300) and boss.state == boss.State.STUN:
			caught = true
			break
	if not pilot.check(caught and sera.energy >= 80, "bracing into the charge stops the Foreman and fills the suit"):
		return false
	await pilot.wait_control()
	await pilot.face(signf(boss.x - sera.position.x))
	await pilot.release()
	if not pilot.check(await pilot.until(func(): return boss.health == 1, 60), "a shockwave breaks the stunned Foreman's core"):
		return false
	await pilot.wait_control()
	pilot.check(wheel.checkpoint == 2, "the second hit is a checkpoint")
	# A retry keeps the phase.
	sera.integrity = 1
	sera.take_hit(-1.0)
	if not pilot.check(await pilot.until(func(): return wheel.retries == 1, 200), "running out of suit retries"):
		return false
	return pilot.check(boss.health == 1 and boss.dormant and boss.perch == 1.0, "the retry keeps the Foreman on the wheel")


func _wheel_phase() -> void:
	var boss := wheel.boss
	var sera := wheel.sera
	await pilot.walk_to(420.0, 200)
	var struck := false
	for attempt in 3:
		if await _catch():
			await pilot.wait_control()
			await pilot.advance_to(boss.PERCH_AIM_X, 200)
			await pilot.face(1.0)
			await pilot.release(true)
			if await pilot.until(func(): return boss.health == 0, 60):
				struck = true
				break
			await pilot.wait_control()
	if not pilot.check(struck, "catching the wheel's load and a diagonal shot break the last core"):
		return
	await pilot.wait_control()
	pilot.check(wheel.finale and not wheel.complete and sera.energy == sera.CAPACITY, "the wheel's momentum floods the suit instead of ending the stage")
	await pilot.face(1.0)
	await pilot.release()
	await pilot.frames(30)
	pilot.check(not wheel.complete, "releasing it forward is not the answer")
	await pilot.wait_control()
	pilot.check(sera.energy == sera.CAPACITY, "the suit stays full until it is released upward")
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return wheel.complete, 60), "releasing it upward stops the wheel and clears the campaign's last stage"):
		return
	var id := wheel.get_instance_id()
	await pilot.tap(&"continue_stage")
	var moved: bool = await pilot.until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	pilot.check(moved and current_scene.scene_file_path == NEXT and current_scene.sera.energy == 0, "E starts a fresh circuit at the foundry")


## Plays the wheel's pattern until the core is bared.
func _catch(limit: int = 1800) -> bool:
	var boss := wheel.boss
	var sera := wheel.sera
	for frame in limit:
		if boss.state == boss.State.OPEN:
			break
		var gap: float = boss.drop_x - sera.position.x
		var toward := &"move_right" if gap > 0.0 else &"move_left"
		var away := &"move_left" if boss.drop_x > 450.0 else &"move_right"
		if paused:
			pass
		elif boss.threatens_from_above() and boss.heavy:
			Input.action_release(&"absorb")
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			if absf(gap) < 170.0:
				Input.action_press(away)
		elif pilot._sweep_near():
			Input.action_release(&"absorb")
			await pilot.tap(&"jump")
		elif boss.threatens_from_above():
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			if absf(gap) > 40.0:
				Input.action_release(&"absorb")
				Input.action_press(toward)
			else:
				Input.action_press(&"absorb")
		else:
			Input.action_release(&"absorb")
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		await physics_frame
	pilot.release_all()
	return boss.state == boss.State.OPEN
