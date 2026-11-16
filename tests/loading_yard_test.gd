extends SceneTree

const Pilot = preload("res://tests/pilot.gd")
const Yard = preload("res://scripts/loading_yard.gd")
const SCENE := "res://scenes/loading_yard.tscn"
const NEXT := "res://scenes/outer_ring.tscn"

var pilot: Pilot
var yard: Yard


func _initialize() -> void:
	pilot = Pilot.new(self)
	_run.call_deferred()


func _run() -> void:
	await pilot.open(SCENE)
	yard = current_scene as Yard
	if await _first_phase():
		if await _second_phase():
			await _last_phase()
	await pilot.finish("dormant crane, overhead catch opens the core, diagonal strike from the marks, slab dodge, wall sweeps, three checkpoints, shutdown and next stage")


func _first_phase() -> bool:
	var boss := yard.boss
	var sera := yard.sera
	await pilot.frames(90)
	if not pilot.check(boss.dormant and boss.health == 3 and sera.integrity == sera.MAX_INTEGRITY, "the crane waits until Sera steps into the yard"):
		return false
	await pilot.walk_to(520.0, 200)
	pilot.check(not boss.dormant, "stepping forward starts the fight")
	# Let the first beam fall without bracing: it hurts and leaves the core shut.
	pilot.check(await pilot.until(func(): return sera.integrity < sera.MAX_INTEGRITY, 400), "an uncaught beam hits")
	pilot.check(not boss.is_open(), "and the clamp stays locked")
	await pilot.place(Vector2(520.0, 519.0), 50)
	sera.integrity = sera.MAX_INTEGRITY
	await pilot.until(func(): return boss.state == boss.State.TRACK, 200)
	await pilot.release(true)
	await pilot.frames(30)
	pilot.check(boss.health == 3 and sera.energy == 0, "a shot at the shut core is wasted")
	await pilot.wait_control()
	if not pilot.check(await _catch(), "catching the blue-lit beam bares the core"):
		return false
	pilot.check(sera.energy >= 84, "the catch fills the suit")
	await pilot.wait_control()
	await pilot.release()
	await pilot.frames(24)
	pilot.check(boss.health == 3 and boss.is_open(), "a straight shockwave passes under the core")
	if not pilot.check(await pilot.until(func(): return not boss.is_open(), 260), "the core closes again"):
		return false
	if not pilot.check(await _catch() and await _strike(), "catch, step out to the mark, diagonal shot"):
		return false
	return pilot.check(boss.health == 2 and yard.checkpoint == 1, "the first hit is a checkpoint")


func _second_phase() -> bool:
	var boss := yard.boss
	var sera := yard.sera
	pilot.check(await pilot.until(func(): return boss.threatens_from_above() and boss.heavy, 400), "the second phase opens with a red-lit slab")
	var evades: int = yard.evade_count
	if not pilot.check(await _catch() and await _strike(), "dodge the slab, hop the wall sweep, catch the beam and strike"):
		return false
	pilot.check(yard.evade_count > evades, "the wall sweep was jumped")
	pilot.check(yard.retries == 0, "without a retry")
	# A retry keeps the phase.
	sera.integrity = 1
	sera.take_hit(-1.0)
	if not pilot.check(await pilot.until(func(): return yard.retries == 1, 200), "running out of suit retries"):
		return false
	return pilot.check(boss.health == 1 and yard.checkpoint == 2 and boss.dormant and sera.position.distance_to(yard.SAFE_START) < 4.0,
		"the retry keeps the second hit and waits at the yard entrance")


func _last_phase() -> void:
	var boss := yard.boss
	await pilot.walk_to(420.0, 200)
	for attempt in 3:
		if await _catch() and await _strike():
			break
	if not pilot.check(boss.health == 0 and yard.complete, "the last strike stops the crane and clears the yard"):
		return
	var id := yard.get_instance_id()
	await pilot.tap(&"continue_stage")
	var moved: bool = await pilot.until(func(): return current_scene != null and current_scene.get_instance_id() != id, 45)
	pilot.check(moved and current_scene.scene_file_path == NEXT, "E continues to the outer ring")


## Plays the crane's pattern until the core is bared: out from under red slabs,
## over the sweeps, braced under blue beams.
func _catch(limit: int = 1500) -> bool:
	var boss := yard.boss
	var sera := yard.sera
	for frame in limit:
		if boss.is_open():
			break
		var gap: float = boss.trolley_x - sera.position.x
		var toward := &"move_right" if gap > 0.0 else &"move_left"
		var away := &"move_left" if boss.trolley_x > 576.0 else &"move_right"
		if paused:
			pass
		elif boss.threatens_from_above() and boss.heavy:
			# Get well clear, toward the roomier side of the yard.
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
	return boss.is_open()


## Steps out to the nearer floor mark that is inside the yard and fires diagonally at the core.
func _strike() -> bool:
	var boss := yard.boss
	var sera := yard.sera
	var before: int = boss.health
	await pilot.wait_control()
	var best := Vector2.INF
	for mark: Vector2 in boss.aim_marks():
		if mark.x > 80.0 and mark.x < 1075.0 and (not best.is_finite() or absf(mark.x - sera.position.x) < absf(best.x - sera.position.x)):
			best = mark
	await pilot.advance_to(best.x, 200)
	await pilot.face(signf(boss.trolley_x - sera.position.x))
	await pilot.release(true)
	var hit: bool = await pilot.until(func(): return boss.health < before, 60)
	await pilot.wait_control()
	return hit
