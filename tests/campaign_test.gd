extends SceneTree

const Store = preload("res://scripts/campaign.gd")
const Pilot = preload("res://tests/pilot.gd")
const Foundry = preload("res://scripts/foundry.gd")
const Tower = preload("res://scripts/cooling_tower.gd")
const Reactor = preload("res://scripts/reactor.gd")
const Mill = preload("res://scripts/rolling_mill.gd")
const Yard = preload("res://scripts/loading_yard.gd")
const Ring = preload("res://scripts/outer_ring.gd")
const Spine = preload("res://scripts/control_spine.gd")
const Wheel = preload("res://scripts/great_wheel.gd")

var progress: Store
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	progress = root.get_node("Campaign")
	if await _foundry_resume() and await _practice_records() and await _tower_resume() and await _reactor_resume():
		await _later_acts()
	await Pilot.close_scene(self)
	if failures.is_empty():
		print("PASS: title, pause and retry, checkpoint and maintenance power restoration, fixed practice starts and persistent splits, nine campaign records and the ending")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)


func _foundry_resume() -> bool:
	change_scene_to_file(Store.TITLE)
	await scene_changed
	_check(current_scene.continue_button.disabled, "fresh profile has no continue")
	_check(root.gui_get_focus_owner() == current_scene.new_button, "new game starts focused")
	await _press(KEY_ENTER)
	if not await _at_scene(Store.SCENES[0]):
		return false
	var foundry := current_scene as Foundry
	_check(foundry.play_mode == Store.Mode.CAMPAIGN, "new game opens campaign")
	foundry.warden.restore_defeated()
	foundry.sera.energy = 67
	foundry._reach_checkpoint(2, Foundry.CHECKPOINTS[2])
	foundry._hitstop(0.48, 0.0, 0.0, Color.WHITE)
	await _press(KEY_ESCAPE)
	var old_time := foundry.elapsed
	var old_freeze := foundry.freeze_left
	await create_timer(0.25).timeout
	_check(paused and foundry.player_paused and foundry.pause_menu.screen.visible, "Esc opens pause during hitstop")
	_check(foundry.elapsed == old_time and foundry.freeze_left == old_freeze and old_freeze > 0.0, "pause freezes game and hitstop timers")
	await _press(KEY_ENTER)
	await create_timer(0.6).timeout
	_check(not paused and not foundry.player_paused and foundry.freeze_left == 0.0, "resume returns through the remaining hitstop")
	await _press(KEY_ESCAPE)
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	_check(foundry.retries == 1 and foundry.sera.energy == 67 and not paused, "checkpoint retry returns charge and resumes")
	if not await _leave_and_continue(0):
		return false
	foundry = current_scene as Foundry
	_check(foundry.checkpoint == 2 and foundry.sera.energy == 67, "foundry checkpoint and charge restored")
	_check(absf(foundry.sera.position.x - Foundry.CHECKPOINTS[2].x) < 2.0, "foundry checkpoint spawns in the furnace")
	_check(foundry.warden.knocked_out and foundry.security_gate.unlocked and foundry.retries == 1, "foundry guard, gate and retry count restored")
	foundry.elapsed = 37.2
	foundry._finish_stage()
	var next := progress.resume_snapshot()
	_check(progress.best_ms(0) == 37200 and next["stage"] == 1 and next["charge"] == 67, "foundry clear records time and carries charge")
	return await _leave_to_title()


func _practice_records() -> bool:
	var saved := FileAccess.get_file_as_string(Store.SAVE_PATH)
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	_check(current_scene.confirm_new.visible, "new game asks before replacing the resume slot")
	await _press(KEY_ESCAPE)
	_check(not current_scene.confirm_new.visible and FileAccess.get_file_as_string(Store.SAVE_PATH) == saved, "cancelling the confirmation preserves the save")
	current_scene.practice_button.grab_focus()
	await _press(KEY_ENTER)
	_check(current_scene.practice_page.visible and current_scene.stage_buttons[0].text.contains("0:37.2"), "practice shows saved best time")
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	if not await _at_scene(Store.SCENES[2]):
		return false
	var reactor := current_scene as Reactor
	_check(reactor.play_mode == Store.Mode.PRACTICE and reactor.sera.energy == 0, "reactor practice starts at the entrance")
	reactor.elapsed = 10.0
	reactor._reach_checkpoint(1, Reactor.SAFE_START)
	reactor.elapsed = 27.25
	reactor._reach_checkpoint(2, Reactor.SAFE_START)
	reactor.elapsed = 41.6
	reactor._finish_stage()
	var first_ms: Array[int] = [10000, 27250, 41600]
	_check(reactor.new_record and progress.practice_splits(2) == first_ms, "clearing practice saves the total and two checkpoint times")
	var practice_file := FileAccess.get_file_as_string(Store.PRACTICE_SAVE_PATH)
	if not await _restart_current_stage():
		return false
	reactor = current_scene as Reactor
	_check(reactor.checkpoint == 0 and reactor.sera.energy == 0
		and reactor.practice_splits_ms == Store.EMPTY_PRACTICE_SPLITS and reactor.practice_previous_ms == first_ms,
		"R starts a fresh attempt with the previous best available for comparison")
	reactor.elapsed = 11.0
	reactor._reach_checkpoint(1, Reactor.SAFE_START)
	_check(reactor.feedback.contains("+1.00"), "the first split compares against the same segment of the previous best")
	reactor.elapsed = 44.0
	reactor._finish_stage()
	_check(not reactor.new_record and FileAccess.get_file_as_string(Store.PRACTICE_SAVE_PATH) == practice_file,
		"a slower attempt leaves the previous best on disk")
	await _press(KEY_ENTER)
	if not await _at_scene(Store.TITLE):
		return false
	progress.reload_practice_records()
	_check(progress.practice_splits(2) == first_ms and current_scene.stage_buttons[2].text.contains("0:41.6"),
		"the best splits reload from disk and the title card shows the best time")
	_check(FileAccess.get_file_as_string(Store.SAVE_PATH) == saved, "practice clears leave the campaign file alone")
	await _press(KEY_ENTER)
	return await _at_scene(Store.SCENES[1])


func _tower_resume() -> bool:
	var tower := current_scene as Tower
	_check(tower.sera.energy == 67 and tower.checkpoint == 0, "continue starts the next stage with carry charge")
	tower.lift_relay.energize(true)
	tower.shield_relay.energize(true)
	tower.sera.energy = 75
	tower._reach_checkpoint(2, Tower.ARENA_CHECKPOINT)
	if not await _leave_and_continue(1):
		return false
	tower = current_scene as Tower
	_check(tower.checkpoint == 2 and tower.sera.energy == 75, "tower checkpoint and charge restored")
	_check(tower.lift_relay.powered and tower.shield_relay.powered and tower.lift.powered and is_equal_approx(tower.lift.height, tower.lift.TOP_Y) and not tower.sentinel.shielded, "tower relays, lift and guard shield restored")
	tower._finish_stage()
	if not await _restart_current_stage():
		return false
	tower = current_scene as Tower
	_check(tower.play_mode == Store.Mode.PRACTICE and tower.entry_charge == 0 and tower.sera.energy == 0 and tower.checkpoint == 0,
		"replaying a campaign clear uses the same zero charge as title practice")
	return await _leave_and_continue(2)


func _reactor_resume() -> bool:
	var reactor := current_scene as Reactor
	reactor.boss.health = 1
	reactor.sera.energy = 43
	reactor._reach_checkpoint(2, Reactor.SAFE_START)
	if not await _leave_and_continue(2):
		return false
	reactor = current_scene as Reactor
	_check(reactor.boss.health == 1 and reactor.checkpoint == 2 and reactor.sera.energy == 43, "reactor restores the last core and charge")
	reactor.boss.health = 0
	reactor.sera.energy = 21
	reactor._finish_stage()
	await _press(KEY_ENTER)
	if not await _at_scene(Store.SCENES[3]):
		return false
	var next := progress.resume_snapshot()
	return _check(next["stage"] == 3 and next["charge"] == 21 and current_scene.sera.energy == 21, "stopping the reactor leads down into act two with its charge")


func _later_acts() -> void:
	# Act two: a sector checkpoint brings back what was already dealt with.
	var mill := current_scene as Mill
	mill.sera.energy = 40
	mill._reach_checkpoint(2, mill.spawns[2])
	if not await _leave_and_continue(3):
		return
	mill = current_scene as Mill
	_check(mill.checkpoint == 2 and mill.sera.energy == 40 and mill.sera.position.distance_to(mill.spawns[2]) < 3.0, "mill checkpoint and charge restored")
	_check(mill.rams[0].down and mill.get_node("World/RamGate").unlocked and not mill.rams[1].down and not mill.exit_gate.unlocked,
		"the ram and gate behind the checkpoint stay cleared, the ones ahead do not")
	if not await _clear_to(4) or not await _clear_to(5):
		return
	var yard := current_scene as Yard
	yard.boss.health = 1
	yard._reach_checkpoint(2, Yard.SAFE_START)
	if not await _leave_and_continue(5):
		return
	yard = current_scene as Yard
	_check(yard.boss.health == 1 and yard.checkpoint == 2 and yard.boss.dormant, "the yard crane restores its last phase")
	if not await _clear_to(6):
		return
	var ring := current_scene as Ring
	ring._reach_checkpoint(2, ring.spawns[2])
	if not await _leave_and_continue(6):
		return
	ring = current_scene as Ring
	_check(ring.checkpoint == 2 and not ring.maintenance_relay.powered and not ring.maintenance_lift.powered,
		"resuming after the lower route does not unlock the optional lift")
	ring.maintenance_relay.energize(true)
	if not await _leave_and_continue(6):
		return
	ring = current_scene as Ring
	_check(ring.maintenance_relay.powered and ring.maintenance_lift.powered and not ring.shield_relay.powered
		and progress.resume_snapshot()["relays"] == 2, "the saved optional relay has its own bit and does not remove the sentinel shield")
	if not await _clear_to(7):
		return

	# Act three: a relay-powered lift and the last boss.
	var spine := current_scene as Spine
	spine._reach_checkpoint(1, spine.spawns[1])
	if not await _leave_and_continue(7):
		return
	spine = current_scene as Spine
	_check(spine.checkpoint == 1 and spine.get_node("World/LiftRelay").powered and spine.get_node("World/LiftA").powered
		and spine.rams[0].down and absf(spine.camera.position.y - 661.0) < 3.0, "the spine restores its middle floor, lift power and camera")
	if not await _clear_to(8):
		return
	var wheel := current_scene as Wheel
	wheel.boss.health = 1
	wheel._reach_checkpoint(2, Wheel.SAFE_START)
	if not await _leave_and_continue(8):
		return
	wheel = current_scene as Wheel
	_check(wheel.boss.health == 1 and wheel.boss.perch == 1.0 and wheel.relay.powered and not wheel.finale, "the Foreman restores on the wheel with its shield already cut")
	wheel._finish_stage()
	await _press(KEY_ENTER)
	if await _at_scene(Store.TITLE):
		_check(current_scene.continue_button.disabled and progress.resume_snapshot().is_empty(), "campaign clear returns to title with no pending checkpoint")
		var all_recorded := progress.best_ms(0) == 37200
		for index in Store.SCENES.size():
			all_recorded = all_recorded and progress.best_ms(index) > 0
		_check(all_recorded, "all nine best times survive reload")
		current_scene.practice_button.grab_focus()
		await _press(KEY_ENTER)
		_check(current_scene.stage_buttons.size() == Store.SCENES.size(), "practice lists every stage")
		current_scene.stage_buttons[8].grab_focus()
		await _press(KEY_ENTER)
		if await _at_scene(Store.SCENES[8]):
			_check(current_scene.play_mode == Store.Mode.PRACTICE and current_scene.boss.health == 3, "the last stage can be practised from its card")


## Finishes the current stage and continues; expects the stage with this index next.
func _clear_to(index: int) -> bool:
	current_scene._finish_stage()
	await _press(KEY_ENTER)
	return await _at_scene(Store.SCENES[index])


func _restart_current_stage() -> bool:
	var previous := current_scene.get_instance_id()
	var scene_path := current_scene.scene_file_path
	await _press(KEY_R)
	for frame in 36:
		if current_scene and current_scene.get_instance_id() != previous:
			return _check(current_scene.scene_file_path == scene_path, "R reloads the same stage")
		await physics_frame
	return _check(false, "R creates a new attempt")


func _leave_and_continue(index: int) -> bool:
	if not await _leave_to_title():
		return false
	_check(not current_scene.continue_button.disabled, "saved campaign can be continued")
	await _press(KEY_ENTER)
	return await _at_scene(Store.SCENES[index])


func _leave_to_title() -> bool:
	await _press(KEY_ESCAPE)
	_check(paused and current_scene.pause_menu.screen.visible, "pause menu opens in a stage")
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	return await _at_scene(Store.TITLE)


func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.device = 16
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await physics_frame
	await physics_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
	await physics_frame
	await physics_frame


func _at_scene(path: String) -> bool:
	for i in 24:
		if current_scene and current_scene.scene_file_path == path:
			return true
		await physics_frame
	return _check(false, "expected scene: " + path)


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
