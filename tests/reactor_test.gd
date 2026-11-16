extends SceneTree

const Pilot = preload("res://tests/pilot.gd")

const Reactor = preload("res://scripts/reactor.gd")
const REACTOR_SCENE := "res://scenes/reactor.tscn"
const NEXT_SCENE := "res://scenes/rolling_mill.tscn"
const MACHINE := preload("res://assets/characters/reactor_boss.png")

var level: Reactor
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(MACHINE.get_image().detect_alpha() != Image.ALPHA_NONE, "boss casing has genuine transparency")
	change_scene_to_file(REACTOR_SCENE)
	await scene_changed
	level = current_scene as Reactor
	await _frames(6)
	if await _upper_phase():
		if await _lower_phase():
			await _last_phase()
	await _finish()


func _upper_phase() -> bool:
	var boss := level.boss
	if not _check(boss.health == 3 and not boss.is_open() and level.sera.energy == 0, "reactor begins shielded and can be started from zero"):
		return false
	await _frames(90)
	if not _check(boss.dormant and level.shots.get_child_count() == 0, "the guardian stays idle until Sera steps forward"):
		return false
	await _walk_to_aim_pad()
	if not _check(await _catch_bolt(false), "absorbing a blue bolt opens the elevated core"):
		return false
	_check(level.sera.energy >= 50 and paused, "absorption supplies enough energy during hitstop")
	await _wait_for_control()
	await _tap(&"release_force")
	await _frames(30)
	_check(boss.health == 3 and boss.is_open(), "horizontal wave misses a high core")
	if not _check(await _until(func(): return not boss.is_open(), 190), "core closes after the exposure window"):
		return false
	if not _check(await _catch_bolt(false), "can recharge and reopen the core again"):
		return false
	await _wait_for_control()
	await _release_up()
	return _check(await _until(func(): return boss.health == 2, 65) and level.checkpoint == 1 and not level.complete,
		"upward wave breaks one core and saves the next phase")


func _lower_phase() -> bool:
	var boss := level.boss
	var sera := level.sera
	# Start this case with the last suit segment so the incoming sweep exercises a real lethal hit.
	sera.integrity = 1
	var retried := await _until(func(): return level.retries == 1, 305)
	if not _check(retried and boss.health == 2 and level.checkpoint == 1 and sera.integrity == sera.MAX_INTEGRITY,
		"dying to the sweep retries the current boss phase"):
		return false
	_check(sera.position.distance_to(level.SAFE_START) < 4.0, "phase retry spawns at reactor checkpoint")
	var evades := level.evade_count
	if not _check(await _catch_bolt(true), "a jump clears the sweep and Q absorbs the next pulse"):
		return false
	_check(level.evade_count > evades and sera.integrity == sera.MAX_INTEGRITY, "jump avoids sweep damage")
	_check(not boss.needs_aim_up(), "second core is at horizontal aim height")
	await _wait_for_control()
	await _tap(&"release_force")
	return _check(await _until(func(): return boss.health == 1, 60) and level.checkpoint == 2,
		"horizontal release breaks the lower core")


func _last_phase() -> void:
	var boss := level.boss
	var sera := level.sera
	if not _check(await _until(func(): return boss.state == boss.State.PRESS_WARNING, 115), "final phase telegraphs a targeted press"):
		return
	var locked_x := boss.press_x
	Input.action_press(&"move_left")
	var escaped := await _until(func(): return sera.position.x < locked_x - 116.0, 64)
	Input.action_release(&"move_left")
	_check(escaped and is_equal_approx(locked_x, boss.press_x), "the warning stays where the player's position was marked")
	if not _check(await _until(func(): return boss.state == boss.State.PRESS_RETURN, 105), "the marked press drops"):
		return
	_check(sera.integrity == sera.MAX_INTEGRITY, "moving off the marked area avoids the press")
	await _walk_to_aim_pad()
	if not _check(await _catch_bolt(true), "final sequence still provides a bolt to reopen the high core"):
		return
	await _wait_for_control()
	await _release_up()
	if not _check(await _until(func(): return level.complete, 62) and boss.health == 0 and boss.state == boss.State.DOWN,
		"last upper hit disables the reactor and clears the stage"):
		return
	var id := level.get_instance_id()
	var charge := sera.energy
	await _tap(&"continue_stage")
	var changed := await _until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	_check(changed and current_scene.scene_file_path == NEXT_SCENE and current_scene.sera.energy == charge,
		"E carries the remaining momentum down into the rolling mill")


func _walk_to_aim_pad() -> void:
	Input.action_press(&"move_right")
	await _until(func(): return level.sera.position.x >= level.AIM_X - 14.0, 130)
	Input.action_release(&"move_right")
	await _frames(8)


func _catch_bolt(dodge: bool) -> bool:
	Input.action_press(&"absorb")
	for frame in 475:
		if level.boss.is_open():
			break
		if dodge and not paused and _sweep_near():
			await _tap(&"jump")
		await physics_frame
	Input.action_release(&"absorb")
	return level.boss.is_open()


func _sweep_near() -> bool:
	if not level.sera.is_on_floor():
		return false
	for shot in level.shots.get_children():
		var gap: float = (shot.position.x - level.sera.position.x) * -shot.direction
		if shot.sweep and gap >= 0.0 and gap < 135.0:
			return true
	return false


func _wait_for_control() -> void:
	await _until(func(): return not paused and level.sera.state == level.sera.State.MOVE, 70)


func _release_up() -> void:
	Input.action_press(&"aim_up")
	await _tap(&"release_force")
	Input.action_release(&"aim_up")


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _until(condition: Callable, frames: int) -> bool:
	for frame in frames:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition


func _finish() -> void:
	await Pilot.close_scene(self)
	if failures.is_empty():
		print("PASS: absorb-to-open, core timing and aim, two phase checkpoints, fatal sweep retry, sweep dodge, press dodge, shutdown and the way down to act two")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
