extends SceneTree

const Pilot = preload("res://tests/pilot.gd")

const Tower = preload("res://scripts/cooling_tower.gd")
const TOWER_SCENE := "res://scenes/cooling_tower.tscn"
const REACTOR_SCENE := "res://scenes/reactor.tscn"
const AIM_ATLAS := preload("res://assets/characters/sera_burst_up_atlas.png")

var tower: Tower
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check_bindings_and_atlas()
	change_scene_to_file(TOWER_SCENE)
	await scene_changed
	tower = current_scene as Tower
	await _frames(5)

	if await _use_lift():
		if await _cross_upper_walkway():
			await _clear_control_room()
	await _finish()


func _use_lift() -> bool:
	var sera := tower.sera
	_check(sera.energy == 0 and not tower.lift.powered and not tower.exit_gate.unlocked, "tower starts from zero with an unpowered lift and locked exit")
	await _frames(90)
	_check(tower.shots.get_child_count() == 0 and sera.integrity == sera.MAX_INTEGRITY,
		"the entrance is out of the valve's range")
	await _walk_right(184.0, 140)
	if not _check(await _absorb_to(100, 350), "the lower valve supplies repeatable charge"):
		return false
	await _wait_for_control()
	await _walk_right(553.0, 155)
	await _frames(9)
	await _tap(&"release_force")
	await _frames(30)
	_check(sera.energy == 50 and not tower.lift_relay.powered, "horizontal release passes underneath the switch")
	await _release_up()
	if not _check(await _until(func(): return tower.lift.powered, 60), "upward shot hits the lift relay"):
		return false
	_check(sera.energy == 0 and tower.lift_relay.powered, "relay uses the same 50 momentum cost")
	await _wait_for_control()
	if not _check(await _walk_right(901.0, 150), "lift can be boarded at the lower landing"):
		return false
	if not _check(await _until(func(): return sera.position.y < 785.0, 200), "the moving platform carries the player upward"):
		return false
	_check(absf(sera.position.x - tower.lift.position.x) < 74.0, "rider stays aboard without jumping")
	if not _check(await _until(func(): return tower.lift.motion == tower.lift.Motion.TOP, 80), "lift reaches the upper deck"):
		return false
	await _frames(2)
	await _walk_right(1114.0, 125)
	return _check(tower.checkpoint == 1 and sera.position.y < 693.0, "walking off the lift reaches the upper checkpoint")


func _cross_upper_walkway() -> bool:
	Input.action_press(&"move_right")
	var fell := await _until(func(): return tower.retries == 1, 255)
	Input.action_release(&"move_right")
	if not _check(fell and tower.checkpoint == 1 and tower.lift.powered and tower.lift_relay.powered, "fall returns to upper checkpoint with lift power intact"):
		return false
	_check(tower.sera.position.distance_to(tower.UPPER_CHECKPOINT) < 4.0, "upper checkpoint places player beside the valve")
	if not _check(await _absorb_to(100, 385), "the upper valve recharges both a leap and a shot"):
		return false
	await _wait_for_control()
	var reached := await _walk_right(1640.0, 195, true)
	if not _check(reached, "reaches the upper launch pad"):
		Input.action_release(&"move_right")
		return false
	Input.action_press(&"aim_up")
	await _tap(&"boost")
	Input.action_release(&"aim_up")
	var landed := await _until(func(): return tower.checkpoint == 2, 130)
	Input.action_release(&"move_right")
	return _check(landed and tower.sera.energy == 66, "upward boost crosses the second gap onto the raised control room")


func _clear_control_room() -> void:
	var boss := tower.sentinel
	var sera := tower.sera
	await _walk_right(2204.0, 138)
	await _frames(8)
	await _tap(&"release_force")
	var blocked := await _until(func(): return boss.shield_flash > 0.0, 56)
	if not _check(blocked and boss.integrity == 2 and boss.shielded and not tower.exit_gate.unlocked, "an active shield deflects the horizontal wave"):
		return

	if not _check(await _absorb_to(50, 410), "the sentinel supplies charge even while shielded"):
		return
	await _wait_for_control()
	await _aim_from(tower.SHIELD_AIM_X)
	await _release_up()
	var relay_hit := await _until(func(): return tower.shield_relay.powered, 60)
	if not _check(relay_hit and not boss.shielded, "the upper relay removes the sentinel shield"):
		return
	_check(boss.integrity == 2 and not tower.exit_gate.unlocked, "cutting shield power still requires defeating the sentinel")
	await _wait_for_control()

	for required_integrity in [1, 0]:
		if not _check(await _absorb_to(50, 420), "recharges before damaging the sentinel"):
			return
		await _wait_for_control()
		if boss.position.x - sera.position.x > 332.0:
			await _walk_right(boss.position.x - 310.0, 68)
		await _tap(&"release_force")
		var connected := await _until(func(): return boss.integrity <= required_integrity, 60)
		if not _check(connected and boss.integrity == required_integrity, "each hit damages a single armor plate"):
			return
		await _wait_for_control()
	if not _check(tower.exit_gate.unlocked and boss.knocked_out and not tower.complete, "sentinel defeat opens the exit"):
		return
	await _walk_right(tower.EXIT_X - 4.0, 425)
	await _frames(10)
	await _tap(&"interact")
	if not _check(await _until(func(): return tower.complete, 90), "interacting with the exit portal clears the tower"):
		return
	var charge := tower.sera.energy
	var previous := tower.get_instance_id()
	await _tap(&"continue_stage")
	var returned := await _until(func(): return current_scene != null and current_scene.get_instance_id() != previous, 35)
	_check(returned and current_scene.scene_file_path == REACTOR_SCENE and current_scene.sera.energy == charge,
		"Enter on tower results carries the remaining momentum into the reactor")


func _absorb_to(charge: int, frames: int) -> bool:
	Input.action_press(&"absorb")
	for frame in frames:
		if tower.sera.energy >= charge:
			break
		if not paused and _sweep_near():
			await _tap(&"jump")
		await physics_frame
	Input.action_release(&"absorb")
	return tower.sera.energy >= charge


func _sweep_near() -> bool:
	for shot in tower.shots.get_children():
		var x: float = shot.position.x - tower.sera.position.x
		if shot.sweep and shot.direction * x < 0.0 and absf(x) <= 139.0 and tower.sera.is_on_floor():
			return true
	return false


func _wait_for_control() -> void:
	await _until(func(): return not paused and tower.sera.state == tower.sera.State.MOVE, 65)


func _walk_right(x: float, frames: int, keep_held: bool = false) -> bool:
	Input.action_press(&"move_right")
	var reached := await _until(func(): return tower.sera.position.x >= x, frames)
	if not keep_held:
		Input.action_release(&"move_right")
	return reached


func _release_up() -> void:
	Input.action_press(&"aim_up")
	await _tap(&"release_force")
	Input.action_release(&"aim_up")


func _aim_from(x: float) -> void:
	var gap := x - tower.sera.position.x
	if absf(gap) > 21.0:
		var move := &"move_right" if gap > 0.0 else &"move_left"
		var stop := x - signf(gap) * 13.0
		Input.action_press(move)
		await _until(func(): return (tower.sera.position.x - stop) * signf(gap) >= 0.0, 130)
		Input.action_release(move)
		await _frames(8)
	if tower.sera.facing < 0.0:
		await _tap(&"move_right")
		await _frames(4)


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


func _check_bindings_and_atlas() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	_check(InputMap.action_has_event(&"continue_stage", key), "physical Enter continues between stages")
	var atlas := AIM_ATLAS.get_image()
	_check(atlas.get_size() == Vector2i(768, 256), "the aim atlas contains three fixed-size cells")
	for index in 3:
		var cell := atlas.get_region(Rect2i(index * 256, 0, 256, 256))
		var used := cell.get_used_rect()
		_check(used.has_area() and Rect2i(4, 4, 248, 248).encloses(used), "aim pose has transparent margins")


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition


func _finish() -> void:
	await Pilot.close_scene(self)
	if failures.is_empty():
		print("PASS: renewable charge, 45 degree switch, lift rider, checkpoint retry, upper leap, shield removal, sentinel, exit and reactor transition")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
