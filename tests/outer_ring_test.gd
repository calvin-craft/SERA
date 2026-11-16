extends SceneTree

const Pilot = preload("res://tests/pilot.gd")
const Ring = preload("res://scripts/outer_ring.gd")
const SCENE := "res://scenes/outer_ring.tscn"
const NEXT := "res://scenes/control_spine.tscn"

var pilot: Pilot
var ring: Ring


func _initialize() -> void:
	pilot = Pilot.new(self)
	_run.call_deferred()


func _run() -> void:
	await pilot.open(SCENE)
	ring = current_scene as Ring
	if await _cross_ramp():
		await _maintenance_route()
	if pilot.failures.is_empty():
		await pilot.open(SCENE)
		ring = current_scene as Ring
		if await _cross_ramp() and await _ramp() and await _drag_belts():
			await _vault()
	await pilot.finish("standard and precise ram catches, both steam lock routes, maintenance lift and upper belt, drag belts, ferry, sentinel and exit")


func _cross_ramp() -> bool:
	var sera := ring.sera
	# The launch belt throws a jump across the wide pit.
	Input.action_press(&"move_right")
	if not pilot.check(await pilot.until(func(): return sera.position.x >= 1066.0, 300), "the ramp belt carries Sera to its end"):
		return false
	await pilot.tap(&"jump")
	var landed := await pilot.until(func(): return sera.is_on_floor() and sera.position.x > 1350.0, 120)
	Input.action_release(&"move_right")
	return pilot.check(landed and ring.retries == 0, "the fast belt jump clears the wide pit")


func _ramp() -> bool:
	var sera := ring.sera
	var ram: Node = ring.rams[0]
	var lock: Node = ring.get_node("World/SteamLock")

	# Way one: take the ram's charge and dash through the steam, leaving the ram alive.
	await pilot.walk_to(1620.0, 200)
	await pilot.face(1.0)
	if not pilot.check(await pilot.absorb_until(func(): return ram.is_stunned(), 500), "the ram's charge can be taken"):
		return false
	await pilot.wait_control()
	pilot.check(sera.energy == 64 and lock.active(), "a standard catch gives enough for a dash")
	if not pilot.check(await pilot.walk_to(2236.0, 240), "a standard catch leaves time to reach the steam"):
		return false
	await pilot.boost()
	await pilot.until(func(): return sera.state == sera.State.MOVE and sera.is_on_floor(), 60)
	pilot.check(sera.position.x > 2380.0 and sera.integrity == sera.MAX_INTEGRITY and not ram.down, "a dash gets through the lock without breaking the ram")
	await pilot.stand_at(2420.0)
	await pilot.release(true)
	await pilot.frames(18)
	pilot.check(sera.energy == 30 and not ring.maintenance_relay.powered, "a standard catch used for a dash does not power the lift")

	# Way two: break the ram and the steam is cut.
	await pilot.place(Vector2(1700.0, 519.0), 0)
	await pilot.face(1.0)
	ram.reset_foe()
	if not pilot.check(await pilot.absorb_until(func(): return ram.is_stunned(), 500), "the ram charges again"):
		return false
	await pilot.wait_control()
	await pilot.release()
	pilot.check(await pilot.until(func(): return ram.down, 40), "the stunned ram breaks")
	pilot.check(await pilot.until(func(): return lock.is_shut(), 20), "breaking the ram cuts the steam lock")
	await pilot.wait_control()
	await pilot.walk_to(2430.0, 400)
	return pilot.check(await pilot.until(func(): return ring.checkpoint == 1, 30) and sera.integrity == sera.MAX_INTEGRITY, "walking through the dead lock reaches the checkpoint")


func _maintenance_route() -> void:
	var sera := ring.sera
	var ram := ring.rams[0]
	var lift := ring.maintenance_lift
	var hits: Array[Vector2] = []
	sera.injured.connect(func(origin: Vector2, _remaining: int): hits.append(origin))
	await pilot.walk_to(1620.0, 200)
	await pilot.face(1.0)
	if not pilot.check(await pilot.until(func(): return ram.state == ram.State.CHARGE and ram.position.x - sera.position.x <= 172.0, 210),
		"the ram reaches the precise catch window"):
		return
	pilot.check(ram.precise_cue_visible(), "the ram shows the brace cue before the precise catch")
	if not pilot.check(await pilot.absorb_until(func(): return ram.is_stunned(), 36), "the ram is caught with a late brace"):
		return
	await pilot.wait_control()
	if not pilot.check(sera.energy == 90 and ring.perfect_shots == 1, "the precise catch charges both actions"):
		return
	if not pilot.check(await pilot.walk_to(2236.0, 240), "Sera runs up to the steam with the full charge"):
		return
	await pilot.boost()
	await pilot.wait_control()
	await pilot.stand_at(2420.0)
	if not pilot.check(sera.energy == 56 and ring.checkpoint == 1 and not ram.down, "one dash brings the remaining charge to the lift"):
		return
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return lift.powered, 90) and sera.energy == 6, "the diagonal release powers the lift with the leftover charge"):
		return
	if not pilot.check(await pilot.until(func(): return lift.progress == 1.0 and sera.position.y < 224.0, 240),
		"the lift carries Sera up to the maintenance belt"):
		return
	if not pilot.check(await pilot.walk_to(3530.0, 240), "the upper belt carries Sera past both steam columns"):
		return
	pilot.check(await pilot.until(func(): return ring.checkpoint == 2, 120),
		"the route rejoins at the next checkpoint from %s" % sera.position)
	pilot.check(ring.retries == 0 and hits.is_empty(), "the upper route passes without hit or retry: %s" % str(hits))
	pilot.check(not ring.drones[0].down, "the upper route bypasses the active drone")


func _drag_belts() -> bool:
	var sera := ring.sera
	var drone: Node = ring.get_node("World/DroneA")
	var steam_a: Node = ring.get_node("World/SteamA")
	var steam_b: Node = ring.get_node("World/SteamB")
	# Clear the drone from the safe deck first.
	await pilot.stand_at(2450.0, 1.0)
	if not pilot.check(await pilot.charge_to(50, 900), "the drone over the belts feeds the suit from the deck"):
		return false
	pilot.check(await pilot.shoot_low(drone), "and is shot down from the deck")
	# Hop each drag belt in the window after its steam stops.
	await pilot.stand_at(2480.0, 1.0)
	await pilot.until(func(): return steam_a.active(), 250)
	await pilot.until(func(): return not steam_a.active(), 120)
	if not pilot.check(await pilot.hop_to(2905.0, 500), "the first drag belt is hopped to the island"):
		return false
	await pilot.stand_at(2990.0, 1.0)
	await pilot.until(func(): return steam_b.active(), 250)
	await pilot.until(func(): return not steam_b.active(), 120)
	if not pilot.check(await pilot.hop_to(3455.0, 500), "the second drag belt is hopped"):
		return false
	pilot.check(ring.retries == 0 and sera.integrity == sera.MAX_INTEGRITY, "timing the steam crosses both belts unharmed")
	await pilot.walk_to(3550.0, 200)
	return pilot.check(await pilot.until(func(): return ring.checkpoint == 2, 30), "beyond the belts is the last checkpoint")


func _vault() -> void:
	var sera := ring.sera
	var ferry: Node = ring.get_node("World/Ferry")
	var drone: Node = ring.get_node("World/DroneB")
	var sentinel: Node = ring.get_node("World/Sentinel")
	var relay: Node = ring.get_node("World/ShieldRelay")
	await pilot.walk_to(3870.0, 300)
	await pilot.face(1.0)
	if not pilot.check(await pilot.charge_to(50, 900), "the drone over the pit can be milked from the ledge"):
		return
	pilot.check(await pilot.shoot_low(drone), "and shot down")
	if not pilot.check(await pilot.ride(ferry, 4540.0), "the ferry crosses to the vault"):
		return

	await pilot.walk_to(4700.0, 200)
	if not pilot.check(await pilot.charge_to(50, 900), "the shielded sentinel still feeds the suit"):
		return
	await pilot.stand_at(4932.0, 1.0)
	await pilot.release()
	await pilot.until(func(): return sentinel.shield_flash > 0.0, 50)
	pilot.check(sentinel.integrity == 2 and sentinel.shielded, "its shield turns a straight shockwave")
	await pilot.wait_control()
	if not pilot.check(await pilot.charge_to(50, 900), "recharge for the relay"):
		return
	await pilot.stand_at(4932.0, 1.0)
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return relay.powered and not sentinel.shielded, 60), "the diagonal shot from the pad cuts the shield"):
		return
	await pilot.wait_control()
	for plates in [1, 0]:
		if not pilot.check(await pilot.charge_to(50, 900), "recharge between plates"):
			return
		if sentinel.position.x - sera.position.x > 330.0:
			await pilot.walk_to(sentinel.position.x - 300.0, 200)
		await pilot.face(1.0)
		await pilot.release()
		if not pilot.check(await pilot.until(func(): return sentinel.integrity <= plates, 60), "each shockwave breaks a plate"):
			return
		await pilot.wait_control()
	pilot.check(await pilot.until(func(): return ring.exit_gate.unlocked, 20), "the sentinel's fall opens the vault door")
	await pilot.walk_to(ring.exit_point.x - 4.0, 500)
	await pilot.frames(10)
	await pilot.tap(&"interact")
	if not pilot.check(await pilot.until(func(): return ring.complete, 90), "the exit clears the ring"):
		return
	var id := ring.get_instance_id()
	await pilot.tap(&"continue_stage")
	var moved: bool = await pilot.until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	pilot.check(moved and current_scene.scene_file_path == NEXT, "Enter continues to the control spine")
