extends SceneTree

const Pilot = preload("res://tests/pilot.gd")
const Mill = preload("res://scripts/rolling_mill.gd")
const SCENE := "res://scenes/rolling_mill.tscn"
const NEXT := "res://scenes/steam_works.tscn"

var pilot: Pilot
var mill: Mill


func _initialize() -> void:
	pilot = Pilot.new(self)
	_run.call_deferred()


func _run() -> void:
	await pilot.open(SCENE)
	mill = current_scene as Mill
	if await _belts():
		if await _presses_and_ram():
			await _dispatch()
	await pilot.finish("belt jump, reverse belt, press rhythm, ram catch and break, gate, reinforced warden, exit and next stage")


func _belts() -> bool:
	var sera := mill.sera
	pilot.check(mill.spawns.size() == 3 and mill.rams.size() == 2 and mill.belts.size() == 4 and mill.hazards.size() == 3,
		"the mill finds its checkpoints, belts, presses and rams")
	# An ordinary jump from still ground falls short of the first pit.
	await pilot.place(Vector2(1100.0, 519.0), 0)
	mill.belts[0].constant_linear_velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	await pilot.until(func(): return sera.position.x >= 1166.0, 120)
	await pilot.tap(&"jump")
	var fell := await pilot.until(func(): return mill.retries == 1, 160)
	Input.action_release(&"move_right")
	pilot.check(fell, "without the belt's speed the pit is too wide to jump")
	mill.belts[0].constant_linear_velocity = Vector2(mill.belts[0].speed, 0.0)

	# With the belt running the same jump carries across.
	await pilot.frames(10)
	Input.action_press(&"move_right")
	if not pilot.check(await pilot.until(func(): return sera.position.x >= 1150.0, 300), "the feed belt carries Sera to its end"):
		return false
	var ground_speed := sera.get_real_velocity().x
	pilot.check(ground_speed > 500.0, "the belt adds its speed to her run (%.0f)" % ground_speed)
	await pilot.tap(&"jump")
	await pilot.frames(3)
	pilot.check(sera.air_carry and sera.velocity.x > 480.0, "jumping off keeps the belt's momentum (%.0f)" % sera.velocity.x)
	var landed := await pilot.until(func(): return sera.is_on_floor() and sera.position.x > 1380.0, 120)
	Input.action_release(&"move_right")
	if not pilot.check(landed and mill.retries == 1, "the belt jump clears the pit"):
		return false

	# The reverse belt pushes a walker back; hopping gets across.
	await pilot.walk_to(2200.0, 300)
	Input.action_press(&"move_right")
	await pilot.frames(120)
	Input.action_release(&"move_right")
	pilot.check(sera.position.x < 2330.0, "walking against the return belt goes nowhere (%.0f)" % sera.position.x)
	if not pilot.check(await pilot.hop_to(2660.0, 700), "hopping crosses the return belt"):
		return false
	await pilot.walk_to(2730.0, 120)
	return pilot.check(await pilot.until(func(): return mill.checkpoint == 1, 30), "the press approach is a checkpoint")


func _presses_and_ram() -> bool:
	var sera := mill.sera
	# Step onto the press belt right after the first press comes down.
	await pilot.walk_to(3020.0, 200)
	var press: Node = mill.hazards[0]
	await pilot.until(func(): return press.active(), 200)
	await pilot.until(func(): return not press.active(), 60)
	if not pilot.check(await pilot.walk_to(3870.0, 400), "the press belt can be run in one go"):
		return false
	pilot.check(sera.integrity == sera.MAX_INTEGRITY, "running on the beat passes all three presses unharmed")

	# A press that comes down on her hurts.
	await pilot.place(Vector2(3500.0, 519.0), 0)
	mill.belts[2].constant_linear_velocity = Vector2.ZERO
	var crushed := await pilot.until(func(): return sera.integrity < sera.MAX_INTEGRITY, 200)
	mill.belts[2].constant_linear_velocity = Vector2(mill.belts[2].speed, 0.0)
	pilot.check(crushed, "standing under a press takes a hit")

	# Ram: a shockwave bounces off, bracing stops it, then a shockwave breaks it.
	var ram: Node = mill.rams[0]
	var gate: Node = mill.get_node("World/RamGate")
	await pilot.place(Vector2(4040.0, 519.0), 50)
	await pilot.face(1.0)
	if not pilot.check(await pilot.until(func(): return ram.state == ram.State.CHARGE, 200), "the ram lines up and charges"):
		return false
	await pilot.until(func(): return ram.position.x - sera.position.x < 300.0, 60)
	await pilot.release()
	await pilot.frames(20)
	pilot.check(not ram.down and sera.energy == 0, "its front plate shrugs off a shockwave")
	await pilot.wait_control()

	# Jumping lets it pass underneath.
	await pilot.place(Vector2(4040.0, 519.0), 0)
	await pilot.face(1.0)
	ram.reset_foe()
	await pilot.until(func(): return ram.state == ram.State.CHARGE and ram.position.x - sera.position.x < 205.0, 300)
	await pilot.tap(&"jump")
	await pilot.until(func(): return ram.state == ram.State.BRAKE, 120)
	pilot.check(sera.integrity == sera.MAX_INTEGRITY, "a timed jump clears the charge")

	await pilot.place(Vector2(4100.0, 519.0), 0)
	await pilot.face(1.0)
	ram.reset_foe()
	var stopped := await pilot.absorb_until(func(): return ram.is_stunned(), 400)
	if not pilot.check(stopped and sera.energy >= 64 and sera.integrity == sera.MAX_INTEGRITY, "bracing into the charge stops the ram and banks its momentum"):
		return false
	await pilot.wait_control()
	await pilot.release()
	if not pilot.check(await pilot.until(func(): return ram.down, 40), "a shockwave breaks the stunned ram"):
		return false
	pilot.check(await pilot.until(func(): return gate.unlocked, 20), "breaking the ram opens the gate")
	await pilot.wait_control()
	await pilot.walk_to(4790.0, 400)
	return pilot.check(await pilot.until(func(): return mill.checkpoint == 2, 30), "past the gate is the last checkpoint")


func _dispatch() -> void:
	var sera := mill.sera
	var ram: Node = mill.rams[1]
	var warden: Node = mill.guards[0]
	# Take the second ram's charge on the reverse belt and use it to dash on.
	# Step onto the belt to draw it out, then fall back to the deck and brace there.
	await pilot.hop_to(5150.0, 300)
	await pilot.until(func(): return ram.is_threat(), 200)
	await pilot.stand_at(4975.0, 1.0)
	var stopped := await pilot.absorb_until(func(): return ram.is_stunned(), 500)
	if not pilot.check(stopped, "the second ram can be stopped from the deck before the belt"):
		return
	await pilot.wait_control()
	await pilot.face(1.0)
	await pilot.release()
	pilot.check(await pilot.until(func(): return ram.down, 40), "and broken on the belt")
	await pilot.wait_control()
	if not pilot.check(await pilot.hop_to(5810.0, 900), "the dispatch belt can be hopped"):
		return

	# Reinforced warden: absorb bolts, two shockwaves.
	for plates in [1, 0]:
		if not pilot.check(await pilot.absorb_until(func(): return sera.energy >= 50, 600), "the warden's bolts recharge the suit"):
			return
		await pilot.wait_control()
		if warden.position.x - sera.position.x > 330.0:
			await pilot.walk_to(warden.position.x - 300.0, 200)
		await pilot.face(1.0)
		await pilot.release()
		if not pilot.check(await pilot.until(func(): return warden.integrity <= plates, 60), "each shockwave breaks one plate"):
			return
		await pilot.wait_control()
	pilot.check(mill.exit_gate.unlocked, "the warden's fall opens the exit")
	await pilot.walk_to(mill.exit_point.x - 4.0, 500)
	await pilot.frames(10)
	await pilot.tap(&"interact")
	if not pilot.check(await pilot.until(func(): return mill.complete, 90), "the exit clears the mill"):
		return
	var id := mill.get_instance_id()
	await pilot.tap(&"continue_stage")
	var moved := await pilot.until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	pilot.check(moved and current_scene.scene_file_path == NEXT, "Enter continues to the steam works")
