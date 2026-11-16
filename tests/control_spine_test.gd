extends SceneTree

const Pilot = preload("res://tests/pilot.gd")
const Spine = preload("res://scripts/control_spine.gd")
const SCENE := "res://scenes/control_spine.tscn"
const NEXT := "res://scenes/great_wheel.tscn"

var pilot: Pilot
var spine: Spine


func _initialize() -> void:
	pilot = Pilot.new(self)
	_run.call_deferred()


func _run() -> void:
	await pilot.open(SCENE)
	spine = current_scene as Spine
	if await _lower_floor():
		if await _middle_floor():
			await _upper_floor()
	await pilot.finish("ram and drone together, relay-powered lift, press belt under fire, free lift, timed door behind steam, shielded sentinel with a drone, exit and next stage")


func _lower_floor() -> bool:
	var sera := spine.sera
	var ram: Node = spine.rams[0]
	var drone: Node = spine.get_node("World/DroneA")
	var relay: Node = spine.get_node("World/LiftRelay")
	var lift: Node = spine.get_node("World/LiftA")
	pilot.check(not lift.powered and absf(spine.camera.position.y - 982.0) < 3.0, "the spine starts on the lower floor with the lift dead")
	# Ram and drone come together; stop the ram, break it, then down the drone.
	await pilot.walk_to(360.0, 200)
	await pilot.face(1.0)
	if not pilot.check(await pilot.absorb_until(func(): return ram.is_stunned(), 700), "the ram is stopped with the drone overhead"):
		return false
	await pilot.wait_control()
	await pilot.release()
	pilot.check(await pilot.until(func(): return ram.down, 40), "and broken")
	await pilot.wait_control()
	if not drone.down:
		if not pilot.check(await pilot.charge_to(50, 900), "the drone's bolts recharge the suit"):
			return false
		pilot.check(await pilot.shoot_low(drone), "the drone is shot down")
	# The valve feeds the relay shot that powers the lift.
	await pilot.walk_to(800.0, 300)
	if not pilot.check(await pilot.charge_to(50, 900), "the floor valve supplies the relay shot"):
		return false
	await pilot.stand_at(1112.0, 1.0)
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return relay.powered and lift.powered, 60), "the diagonal shot from the pad powers the lift"):
		return false
	await pilot.wait_control()
	if not pilot.check(await pilot.ride(lift, 1580.0), "the lift carries Sera to the middle floor"):
		return false
	return pilot.check(await pilot.until(func(): return spine.checkpoint == 1, 30) and sera.position.y < 845.0, "the middle floor is a checkpoint")


func _middle_floor() -> bool:
	var sera := spine.sera
	var press: Node = spine.get_node("World/PressA")
	var warden: Node = spine.get_node("World/WardenA")
	var gate: Node = spine.get_node("World/MiddleGate")
	var lift: Node = spine.get_node("World/LiftB")
	await pilot.until(func(): return absf(spine.camera.position.y - 662.0) < 3.0, 200)
	pilot.check(absf(spine.camera.position.y - 662.0) < 3.0, "the camera follows up to the middle floor")
	await pilot.walk_to(1680.0, 200)
	await pilot.until(func(): return press.active(), 250)
	await pilot.until(func(): return not press.active(), 60)
	if not pilot.check(await pilot.walk_to(2215.0, 300), "the transfer belt is run in one go"):
		return false
	pilot.check(sera.integrity == sera.MAX_INTEGRITY, "on the beat both presses miss")
	for plates in [1, 0]:
		if not pilot.check(await pilot.charge_to(50, 900), "the warden's bolts recharge the suit"):
			return false
		if warden.position.x - sera.position.x > 330.0:
			await pilot.walk_to(warden.position.x - 300.0, 200)
		await pilot.face(1.0)
		await pilot.release()
		if not pilot.check(await pilot.until(func(): return warden.integrity <= plates, 60), "each shockwave breaks a plate"):
			return false
		await pilot.wait_control()
	pilot.check(await pilot.until(func(): return gate.unlocked, 20), "the warden's fall opens the way to the lift")
	await pilot.until(func(): return gate.open_ratio >= 0.9, 60)
	await pilot.walk_to(2680.0, 300)
	if not pilot.check(await pilot.ride(lift, 2960.0), "the second lift runs by itself and reaches the top floor"):
		return false
	return pilot.check(await pilot.until(func(): return spine.checkpoint == 2, 30) and sera.position.y < 525.0, "the top floor is the last checkpoint")


func _upper_floor() -> void:
	var sera := spine.sera
	var steam: Node = spine.get_node("World/SteamA")
	var relay: Node = spine.get_node("World/TimedRelay")
	var door: Node = spine.get_node("World/Shutter")
	var shield_relay: Node = spine.get_node("World/ShieldRelay")
	var sentinel: Node = spine.get_node("World/Sentinel")
	var drone: Node = spine.get_node("World/DroneB")
	await pilot.walk_to(2960.0, 100)
	if not pilot.check(await pilot.charge_to(50, 900), "the top valve supplies the timed relay shot"):
		return
	await pilot.stand_at(3102.0, 1.0)
	# Fire as the steam is about to stop, so the run meets it switched off.
	await pilot.until(func(): return steam.active() and steam.cycle_time() >= steam.off_time + 0.55, 300)
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return relay.powered, 40), "the timed relay is hit from the pad"):
		return
	await pilot.wait_control()
	if not pilot.check(await pilot.walk_to(3470.0, 200), "the door is reached before the relay runs out"):
		return
	pilot.check(sera.integrity == sera.MAX_INTEGRITY, "and the steam on the way was off")
	await pilot.face(1.0)
	pilot.check(await pilot.absorb_until(func(): return not relay.powered and not door.is_open(), 260), "the door shuts behind her")
	await pilot.wait_control()

	# Shield first, then the drone, then the sentinel.
	pilot.check(await pilot.advance_to(3682.0), "the shield pad can be reached under fire")
	if not pilot.check(await pilot.charge_to(50, 900), "bolts recharge on the pad"):
		return
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return shield_relay.powered and not sentinel.shielded, 60), "the diagonal shot cuts the sentinel's shield"):
		return
	await pilot.wait_control()
	if not drone.down:
		if not pilot.check(await pilot.charge_to(50, 900), "recharge for the drone"):
			return
		if not await pilot.shoot_low(drone, 700):
			await pilot.charge_to(50, 900)
			pilot.check(await pilot.shoot_high(drone), "the control room drone is shot down")
	while not sentinel.knocked_out:
		if not pilot.check(await pilot.charge_to(50, 900), "recharge between plates"):
			return
		if sentinel.position.x - sera.position.x > 330.0:
			await pilot.walk_to(sentinel.position.x - 300.0, 200)
		await pilot.face(1.0)
		var before: int = sentinel.integrity
		await pilot.release()
		if not pilot.check(await pilot.until(func(): return sentinel.integrity < before, 60), "each shockwave breaks a plate"):
			return
		await pilot.wait_control()
	pilot.check(await pilot.until(func(): return spine.exit_gate.unlocked, 20), "the sentinel's fall opens the exit")
	await pilot.walk_to(spine.exit_point.x - 4.0, 500)
	await pilot.frames(10)
	await pilot.tap(&"interact")
	if not pilot.check(await pilot.until(func(): return spine.complete, 90), "the exit clears the spine"):
		return
	var id := spine.get_instance_id()
	await pilot.tap(&"continue_stage")
	var moved: bool = await pilot.until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	pilot.check(moved and current_scene.scene_file_path == NEXT, "Enter continues to the great wheel")
