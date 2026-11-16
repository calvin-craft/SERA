extends SceneTree

const Pilot = preload("res://tests/pilot.gd")
const Works = preload("res://scripts/steam_works.gd")
const SCENE := "res://scenes/steam_works.tscn"
const NEXT := "res://scenes/loading_yard.tscn"

var pilot: Pilot
var works: Works


func _initialize() -> void:
	pilot = Pilot.new(self)
	_run.call_deferred()


func _run() -> void:
	await pilot.open(SCENE)
	works = current_scene as Works
	if await _leaks():
		if await _service_way():
			await _outfall()
	await pilot.finish("timed steam, dash through steam, drone bolts and both ways to shoot one down, timed relay door, ferry, exit and next stage")


func _hazard(node_name: String) -> Node:
	return works.get_node("World/" + node_name)


func _leaks() -> bool:
	var sera := works.sera
	var timed := _hazard("SteamA")
	var constant := _hazard("SteamB")
	pilot.check(works.hazards.size() == 3 and works.drones.size() == 3 and works.valves.size() == 4, "the works finds its steam, drones and valves")
	# Timed steam: wait for it to stop, then walk through.
	await pilot.walk_to(520.0, 200)
	await pilot.until(func(): return timed.active(), 250)
	await pilot.until(func(): return not timed.active(), 120)
	await pilot.walk_to(700.0, 120)
	pilot.check(sera.integrity == sera.MAX_INTEGRITY, "walking through while the jet is off is safe")
	# Standing in it when it comes on is not.
	await pilot.place(Vector2(600.0, 519.0), 0)
	pilot.check(await pilot.until(func(): return sera.integrity < sera.MAX_INTEGRITY, 260), "the jet scalds when it comes back on")

	# The second jet never stops: walking in is turned back, a dash goes through.
	await pilot.place(Vector2(1100.0, 519.0), 0)
	await pilot.walk_to(1260.0, 60)
	pilot.check(sera.integrity < sera.MAX_INTEGRITY and sera.position.x < 1200.0, "a constant jet throws a walker back")
	await pilot.place(Vector2(800.0, 519.0), 0)
	if not pilot.check(await pilot.charge_to(34, 500), "the first valve supplies the dash"):
		return false
	await pilot.walk_to(1100.0, 200)
	await pilot.frames(6)
	await pilot.boost()
	await pilot.until(func(): return sera.state == sera.State.MOVE and sera.is_on_floor(), 60)
	if not pilot.check(sera.position.x > 1250.0 and sera.integrity == sera.MAX_INTEGRITY and constant.active(), "a dash carries through the jet unharmed"):
		return false
	pilot.check(await pilot.charge_to(50, 500), "the next valve refills on the far side")
	await pilot.walk_to(1815.0, 300)
	return pilot.check(await pilot.until(func(): return works.checkpoint == 1, 30), "the service way is a checkpoint")


func _service_way() -> bool:
	var sera := works.sera
	var drone: Node = works.get_node("World/DroneA")
	var gate: Node = works.get_node("World/DroneGate")
	var relay: Node = works.get_node("World/TimedRelay")
	var door: Node = works.get_node("World/Shutter")
	sera.energy = 0
	await pilot.walk_to(1960.0, 200)
	await pilot.face(1.0)
	if not pilot.check(await pilot.charge_to(50, 900), "the drone dives and its bolt can be absorbed"):
		return false
	pilot.check(not drone.down and not gate.unlocked, "the gate stays shut while the drone flies")
	if not pilot.check(await pilot.shoot_low(drone), "a straight shockwave downs the drone while it is low"):
		return false
	pilot.check(await pilot.until(func(): return gate.unlocked, 20), "downing the drone opens the gate")

	await pilot.walk_to(2650.0, 400)
	if not pilot.check(await pilot.charge_to(100, 900), "the valve by the door supplies the relay shot"):
		return false
	await pilot.stand_at(2812.0, 1.0)
	var hud := works.get_node("HUDLayer/HUD")
	var target := Rect2(Vector2(598.0, 282.0), Vector2.ZERO).grow(46.0).expand(Vector2(487.0, 385.0))
	var bubble: Rect2 = hud._hint_bubble(Vector2(445.0, 371.0), Vector2(390.0, 92.0), 0.0, target)
	pilot.check(not bubble.grow(10.0).intersects(target), "the timed relay hint clears the target and its aiming line")
	await pilot.release(true)
	if not pilot.check(await pilot.until(func(): return relay.powered, 40), "the diagonal shot from the pad reaches the timed relay"):
		return false
	pilot.check(await pilot.until(func(): return door.is_open(), 40), "the door opens while the relay holds")
	await pilot.wait_control()
	pilot.check(await pilot.until(func(): return not relay.powered and not door.is_open(), 260), "the relay runs out and the door shuts again")
	await pilot.stand_at(2812.0, 1.0)
	await pilot.release(true)
	await pilot.until(func(): return relay.powered, 40)
	await pilot.wait_control()
	if not pilot.check(await pilot.walk_to(3236.0, 200), "there is time to run through the door"):
		return false
	return pilot.check(await pilot.until(func(): return works.checkpoint == 2, 30), "past the door is the last checkpoint")


func _outfall() -> void:
	var sera := works.sera
	var ferry: Node = works.get_node("World/Ferry")
	var over_pit: Node = works.get_node("World/DroneB")
	var last: Node = works.get_node("World/DroneC")
	var constant := _hazard("SteamC")
	# Clear the drone over the pit from the deck, then ride.
	await pilot.walk_to(3270.0, 100)
	await pilot.face(1.0)
	if not pilot.check(await pilot.charge_to(50, 900), "the drone over the pit feeds the suit from the ledge"):
		return
	pilot.check(await pilot.shoot_low(over_pit), "and can be shot down from the ledge")
	var retries: int = works.retries
	if not pilot.check(await pilot.ride(ferry, 3925.0), "the ferry carries Sera across the pit"):
		return
	pilot.check(works.retries == retries and sera.position.y < 525.0, "without falling")

	await pilot.walk_to(3985.0, 100)
	if not pilot.check(await pilot.charge_to(34, 600), "the far valve reaches the landing"):
		return
	await pilot.walk_to(4025.0, 100)
	await pilot.frames(6)
	await pilot.boost()
	await pilot.until(func(): return sera.state == sera.State.MOVE and sera.is_on_floor(), 60)
	pilot.check(sera.position.x > 4170.0 and constant.active(), "the last constant jet is dashed through")
	await pilot.face(1.0)
	if not pilot.check(await pilot.charge_to(50, 900), "valve and drone bolts refill beyond the jet"):
		return
	if not pilot.check(await pilot.shoot_high(last), "a diagonal shockwave downs a hovering drone"):
		return
	pilot.check(await pilot.until(func(): return works.exit_gate.unlocked, 20), "the last drone opens the exit")
	await pilot.walk_to(works.exit_point.x - 4.0, 400)
	await pilot.frames(10)
	await pilot.tap(&"interact")
	if not pilot.check(await pilot.until(func(): return works.complete, 90), "the exit clears the works"):
		return
	var id := works.get_instance_id()
	await pilot.tap(&"continue_stage")
	var moved := await pilot.until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	pilot.check(moved and current_scene.scene_file_path == NEXT, "Enter continues to the loading yard")
