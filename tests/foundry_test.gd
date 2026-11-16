extends SceneTree

const Pilot = preload("res://tests/pilot.gd")

const Level = preload("res://scripts/foundry.gd")
const FOUNDRY := "res://scenes/foundry.tscn"
const ATLAS := preload("res://assets/characters/sera_atlas.png")
const GUARD_ATLAS := preload("res://assets/characters/sera_guard_atlas.png")

var level: Level
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check_assets_and_controls()
	change_scene_to_file(FOUNDRY)
	await scene_changed
	level = current_scene as Level
	await _frames(5)

	var opening_ok := await _opening()
	var guard_ok := false
	if opening_ok:
		guard_ok = await _first_guard()
	if guard_ok:
		await _furnace()
	if level.complete:
		await _check_tower_transition()
	await _restart_and_dash()
	await _finish()


func _opening() -> bool:
	var sera := level.sera
	await _tap(&"release_force")
	_check(sera.energy == 0 and not level.wave_active and sera.hint_left > 0.0, "empty release shows the charge requirement")
	var starting_y := sera.position.y
	await _tap(&"jump", 8)
	_check(sera.position.y < starting_y - 25.0, "Space jumps")
	await _frames(60)
	_check(level.beam.phase == level.beam.Phase.WAIT and sera.integrity == sera.MAX_INTEGRITY, "the entrance is safe until Sera walks under the beam")
	await _run_right(level.beam.position.x - 8.0, 150)
	var hurt := await _until(func(): return sera.integrity == 2, 210)
	_check(hurt and sera.state == sera.State.HURT, "unabsorbed beam damages and staggers Sera")
	if not await _restart():
		return false

	await _run_right(level.beam.position.x - 8.0, 150)
	Input.action_press(&"absorb")
	var caught := await _until(func(): return level.caught_beam, 210)
	Input.action_release(&"absorb")
	if not _check(caught, "Q catches the falling beam"):
		return false
	_check(level.beam.speed == 0.0 and level.beam.phase == level.beam.Phase.HELD, "caught beam stops")
	_check(paused and level.freeze_left > 0.0, "beam impact applies hitstop")
	await _until(func(): return level.sera.state == level.sera.State.MOVE, 45)
	if not await _boost_off_edge(972.0):
		return false
	_check(level.sera.energy == 100 - level.sera.BOOST_COST, "upward boost consumes its cost once")
	return _check(await _until(func(): return level.checkpoint == 1, 120), "the first deck activates a checkpoint")


func _first_guard() -> bool:
	var sera := level.sera
	var saved_charge := sera.energy
	Input.action_press(&"move_left")
	var retried := await _until(func(): return level.retries == 1, 210)
	Input.action_release(&"move_left")
	if not _check(retried and level.checkpoint == 1, "fall respawns on the receiving deck"):
		return false
	_check(sera.integrity == sera.MAX_INTEGRITY and sera.energy == saved_charge, "retry restores entry charge and integrity")
	_check(sera.position.distance_to(level.CHECKPOINTS[1]) < 3.0, "retry snaps to the checkpoint beacon")
	if not _check(await _run_right(1410.0, 150), "the guard is approached from the crossing"):
		return false

	var incoming := await _until(func(): return _shot_near(false, 132.0), 190)
	if not _check(incoming, "the first guard fires an absorbable bolt"):
		return false
	Input.action_press(&"absorb")
	var caught := await _until(func(): return level.perfect_shots == 1, 45)
	if not _check(caught and sera.energy == 100 and sera.integrity == sera.MAX_INTEGRITY, "well-timed frontal Q absorbs the bolt intact"):
		Input.action_release(&"absorb")
		return false
	await _tap(&"release_force")
	Input.action_release(&"absorb")

	var first_hit := await _until(func(): return level.warden.knocked_out, 60)
	if not _check(first_hit and level.security_gate.unlocked and not level.complete, "hitstop-buffered E defeats the sentry and unlocks the passage"):
		return false
	_check(sera.energy == 100 - sera.RELEASE_COST and paused, "release charges once at the hit sequence")
	var enemy_x := level.warden.position.x
	await _frames(26)
	_check(level.warden.position.x > enemy_x + 120 and not paused, "sentry flies after hitstop")
	if not _check(await _run_right(2190.0, 290), "the second crane can be reached"):
		return false
	Input.action_press(&"absorb")
	var recharged := await _until(func(): return sera.energy == 100, 230)
	Input.action_release(&"absorb")
	if not _check(recharged, "the second beam replenishes momentum"):
		return false
	await _until(func(): return sera.state == sera.State.MOVE, 45)
	return await _boost_off_edge(2556.0)


func _furnace() -> void:
	if not _check(await _until(func(): return level.checkpoint == 2, 115), "boost lands on the raised furnace deck"):
		return
	var sera := level.sera
	var guard := level.furnace_warden
	var before := sera.energy
	_check(not level.warden.visible and level.warden.knocked_out, "a defeated guard disappears after a short while")
	_check(not level.exit_gate.unlocked and guard.integrity == 2, "the furnace exit starts locked by two armor plates")
	await _run_right(3120.0, 100)
	await _tap(&"release_force")
	if not _check(await _until(func(): return guard.integrity == 1, 60), "the first release breaks one armor plate"):
		return
	_check(not guard.knocked_out and not level.exit_gate.unlocked and sera.energy == before - sera.RELEASE_COST,
		"one shockwave damages reinforced armor once")

	if not _check(await _until(func(): return _shot_near(true, 140.0), 205), "reinforced guard follows with a ground wave"):
		return
	var prior_health := sera.integrity
	await _tap(&"jump")
	if not _check(await _until(func(): return level.evade_count == 1, 52), "jump clears the ground wave"):
		return
	_check(sera.integrity == prior_health, "evading a wave leaves integrity unchanged")

	Input.action_press(&"absorb")
	var charged := await _until(func(): return level.caught_shots >= 2, 230)
	Input.action_release(&"absorb")
	if not _check(charged and sera.energy == mini(100, before - sera.RELEASE_COST + 56), "an early hold absorbs the next bolt for regular charge"):
		return
	await _until(func(): return sera.state == sera.State.MOVE, 45)
	if guard.position.x - sera.position.x >= 335:
		await _until_near_guard(guard)
	await _tap(&"release_force")
	var defeated := await _until(func(): return guard.knocked_out, 65)
	if not _check(defeated and level.exit_gate.unlocked and not level.complete, "the second hit launches the reinforced guard and unlocks the exit"):
		return
	_check(await _run_right(level.EXIT_X - 4.0, 350) and not level.complete, "reaching the open exit does not end the stage by itself")
	await _frames(10)
	_check(level.exit_portal.open and level.exit_portal.near, "the exit portal is open and in reach")
	await _tap(&"interact")
	_check(await _until(func(): return level.complete, 90), "interacting with the exit portal clears the foundry")


func _restart_and_dash() -> void:
	if not await _restart():
		return
	var sera := level.sera
	_check(level.checkpoint == 0 and sera.energy == 0 and not level.exit_gate.unlocked and level.furnace_warden.integrity == 2,
		"R resets both encounters")
	await _run_right(level.beam.position.x - 8.0, 150)
	Input.action_press(&"absorb")
	var charged := await _until(func(): return level.caught_beam, 205)
	Input.action_release(&"absorb")
	if not _check(charged, "beam becomes available after restarting"):
		return
	await _until(func(): return sera.state == sera.State.MOVE, 45)
	await _tap(&"boost")
	var dashed := await _until(func(): return sera.state == sera.State.BOOST, 30)
	_check(dashed and sera.velocity.x > 850.0 and is_zero_approx(sera.velocity.y), "Shift without W performs a horizontal dash")


func _check_tower_transition() -> void:
	var charge := level.sera.energy
	var scene_id := level.get_instance_id()
	await _tap(&"continue_stage")
	var changed := await _until(func(): return current_scene != null and current_scene.get_instance_id() != scene_id, 35)
	if not _check(changed and current_scene.scene_file_path == "res://scenes/cooling_tower.tscn", "cleared foundry continues to the cooling tower"):
		return
	_check(current_scene.sera.energy == charge, "entering the tower carries remaining momentum")
	var tower_id := current_scene.get_instance_id()
	await _tap(&"restart")
	var restarted := await _until(func(): return current_scene != null and current_scene.get_instance_id() != tower_id, 35)
	_check(restarted and current_scene.sera.energy == charge and not current_scene.lift.powered,
		"R restarts the tower with its original entry charge")
	change_scene_to_file(FOUNDRY)
	await scene_changed
	level = current_scene as Level
	await _frames(4)


func _restart() -> bool:
	var previous := level.get_instance_id()
	Input.action_press(&"restart")
	var changed := await _until(func(): return current_scene != null and current_scene.get_instance_id() != previous, 40)
	Input.action_release(&"restart")
	if not _check(changed, "R reloads the whole foundry"):
		return false
	level = current_scene as Level
	await _frames(4)
	return true


func _boost_off_edge(edge_x: float) -> bool:
	var reached := await _run_right(edge_x, 220, true)
	if not _check(reached, "reaches takeoff marker %d" % edge_x):
		Input.action_release(&"move_right")
		return false
	Input.action_press(&"aim_up")
	await _tap(&"boost")
	Input.action_release(&"aim_up")
	var launched := await _until(func(): return level.sera.state == level.sera.State.BOOST, 28)
	_check(launched and level.sera.velocity.y < -520.0, "W and Shift launch upward")
	await _frames(31)
	Input.action_release(&"move_right")
	return launched


func _run_right(x: float, limit: int, keep_held: bool = false) -> bool:
	Input.action_press(&"move_right")
	var reached := await _until(func(): return level.sera.position.x >= x, limit)
	if not keep_held:
		Input.action_release(&"move_right")
	return reached


func _until_near_guard(guard: CharacterBody2D) -> void:
	Input.action_press(&"move_right")
	await _until(func(): return guard.position.x - level.sera.position.x < 305.0, 64)
	Input.action_release(&"move_right")


func _shot_near(sweep: bool, distance: float) -> bool:
	for shot in level.shots.get_children():
		var dx: float = shot.position.x - level.sera.position.x
		if shot.sweep == sweep and shot.direction * dx < 0.0 and absf(dx) <= distance:
			return true
	return false


func _check_assets_and_controls() -> void:
	var keys := {&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"jump": [KEY_SPACE], &"boost": [KEY_SHIFT],
		&"aim_up": [KEY_W, KEY_UP], &"restart": [KEY_R]}
	var buttons := {&"absorb": MOUSE_BUTTON_LEFT, &"release_force": MOUSE_BUTTON_RIGHT}
	for action in buttons:
		var click := InputEventMouseButton.new()
		click.button_index = buttons[action]
		_check(InputMap.action_has_event(action, click), "mouse button matches %s" % action)
	for action in keys:
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			_check(InputMap.action_has_event(action, event), "physical key matches %s" % action)
	_check_atlas(ATLAS.get_image(), Vector2i(5, 3))
	_check_atlas(GUARD_ATLAS.get_image(), Vector2i(3, 1))


func _check_atlas(atlas: Image, grid: Vector2i) -> void:
	if not _check(atlas.get_size() == grid * 256, "atlas has 256 px cells"):
		return
	for y in grid.y:
		for x in grid.x:
			var cell := atlas.get_region(Rect2i(x * 256, y * 256, 256, 256))
			var ink := cell.get_used_rect()
			_check(ink.has_area() and Rect2i(4, 4, 248, 248).encloses(ink), "cell %d,%d has a transparent margin" % [x, y])


func _tap(action: StringName, count: int = 2) -> void:
	Input.action_press(action)
	await _frames(count)
	Input.action_release(action)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _until(condition: Callable, max_frames: int) -> bool:
	for index in max_frames:
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
		print("PASS: atlas, input, beam, checkpoints, absorption, combat, exit, stage transition, carry-charge and reset")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
