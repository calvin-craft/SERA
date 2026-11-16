extends RefCounted

const Audio = preload("res://scripts/game_audio.gd")

## Shared input helpers for the stage tests: they press the same actions a
## player would and wait on physics frames. `tree` is the running test.

var tree: SceneTree
var failures: Array[String] = []


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree


var level: Variant:
	get:
		return tree.current_scene


var sera: Variant:
	get:
		return tree.current_scene.sera


func open(scene_path: String) -> void:
	tree.change_scene_to_file(scene_path)
	await tree.scene_changed
	await frames(5)


func check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition


func frames(count: int) -> void:
	for frame in count:
		await tree.physics_frame


func until(condition: Callable, limit: int) -> bool:
	for frame in limit:
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func tap(action: StringName, hold: int = 2) -> void:
	Input.action_press(action)
	await frames(hold)
	Input.action_release(action)


func release_all() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"absorb", &"boost", &"aim_up", &"release_force", &"interact"]:
		Input.action_release(action)


## Puts Sera on the floor at `point` with `energy`, as a retry would.
func place(point: Vector2, energy: int) -> void:
	release_all()
	tree.paused = false
	level.freeze_left = 0.0
	sera.reset_at(point, energy)
	sera.invulnerable_left = 0.0
	if "ground_y" in level:
		level.ground_y = point.y
	level.camera.position = level._camera_goal(point)
	await frames(3)


func wait_control(limit: int = 80) -> void:
	await until(func(): return not tree.paused and sera.state == sera.State.MOVE, limit)


## Runs toward world x and stops there. Returns false if it was not reached in time.
func walk_to(x: float, limit: int = 240, keep_held: bool = false) -> bool:
	var heading: float = signf(x - sera.position.x)
	if heading == 0.0:
		return true
	var move := &"move_right" if heading > 0.0 else &"move_left"
	Input.action_press(move)
	var reached := await until(func(): return (sera.position.x - x) * heading >= 0.0, limit)
	if not keep_held:
		Input.action_release(move)
	return reached


func face(heading: float) -> void:
	if sera.facing != heading:
		await tap(&"move_right" if heading > 0.0 else &"move_left", 1)
		await frames(3)


## Stops with Sera within a few pixels of x, facing `heading`.
func stand_at(x: float, heading: float = 1.0) -> void:
	for attempt in 6:
		var gap: float = x - sera.position.x
		if absf(gap) <= 9.0:
			break
		await walk_to(x - signf(gap) * 6.0, 200)
		await frames(10)
	await face(heading)


## Holds absorb until `condition` is true, hopping over floor sweeps on the way.
func absorb_until(condition: Callable, limit: int) -> bool:
	Input.action_press(&"absorb")
	for frame in limit:
		if condition.call():
			break
		if not tree.paused and _sweep_near():
			Input.action_release(&"absorb")
			await tap(&"jump")
			Input.action_press(&"absorb")
		await tree.physics_frame
	Input.action_release(&"absorb")
	return condition.call()


func _sweep_near() -> bool:
	if not sera.is_on_floor():
		return false
	for shot in level.shots.get_children():
		var gap: float = (shot.position.x - sera.position.x) * -shot.direction
		if shot.sweep and gap >= 0.0 and gap < 137.0 and absf(shot.position.y - sera.position.y) < 60.0:
			return true
	return false


func release(upward: bool = false) -> void:
	if upward:
		Input.action_press(&"aim_up")
	await tap(&"release_force")
	if upward:
		Input.action_release(&"aim_up")


func boost(upward: bool = false) -> void:
	if upward:
		Input.action_press(&"aim_up")
	await tap(&"boost")
	if upward:
		Input.action_release(&"aim_up")


## Walks to world x under fire: braces for bolts coming from ahead and hops floor sweeps.
func advance_to(x: float, limit: int = 900) -> bool:
	var heading: float = signf(x - sera.position.x)
	var move := &"move_right" if heading > 0.0 else &"move_left"
	for frame in limit:
		var gap: float = (x - sera.position.x) * heading
		if gap <= 6.0 and sera.state == sera.State.MOVE and sera.is_on_floor():
			break
		if tree.paused or sera.state == sera.State.CATCH or sera.state == sera.State.HURT:
			pass
		elif _bolt_near(heading):
			Input.action_release(move)
			Input.action_press(&"absorb")
		else:
			Input.action_release(&"absorb")
			if _sweep_near():
				Input.action_press(&"jump")
				await tree.physics_frame
				Input.action_release(&"jump")
			if gap > 6.0:
				Input.action_press(move)
			else:
				Input.action_release(move)
		await tree.physics_frame
	Input.action_release(move)
	Input.action_release(&"absorb")
	await frames(8)
	await face(heading)
	return absf(x - sera.position.x) <= 16.0


func _bolt_near(heading: float) -> bool:
	for shot in level.shots.get_children():
		var gap: float = (shot.position.x - sera.position.x) * heading
		if not shot.sweep and shot.direction == -heading and gap > 0.0 and gap < 250.0 and absf(shot.position.y - sera.position.y + 85.0) < 60.0:
			return true
	return false


## Takes bolts until the suit holds at least `energy`.
func charge_to(energy: int, limit: int = 700) -> bool:
	var ok := await absorb_until(func(): return sera.energy >= energy, limit)
	await wait_control()
	return ok


## Waits for a drone to drop to firing height, then shoots it straight on.
func shoot_low(drone: Node, limit: int = 500) -> bool:
	var ready := func() -> bool:
		return drone.is_low() and (drone.state == drone.State.AIM or drone.left > 0.45) and not tree.paused and sera.state == sera.State.MOVE
	if not await until(ready, limit):
		return false
	await face(signf(drone.position.x - sera.position.x))
	await release()
	var hit := await until(func(): return drone.down, 40)
	await wait_control()
	return hit


## Closes to diagonal range under a hovering drone, holds there, and shoots it diagonally.
func shoot_high(drone: Node, limit: int = 700) -> bool:
	for frame in limit:
		var gap: float = drone.position.x - sera.position.x
		var side := signf(gap)
		var toward := &"move_right" if side > 0.0 else &"move_left"
		var away := &"move_left" if side > 0.0 else &"move_right"
		Input.action_release(away)
		if absf(gap) > 172.0:
			Input.action_press(toward)
		else:
			Input.action_release(toward)
			if absf(gap) < 128.0:
				Input.action_press(away)
			elif drone.state == drone.State.HOVER and sera.is_on_floor() and sera.state == sera.State.MOVE 					and sera.facing == side and not tree.paused:
				Input.action_release(away)
				await release(true)
				var hit := await until(func(): return drone.down, 40)
				await wait_control()
				return hit
			elif sera.facing != side:
				Input.action_press(toward)
		await tree.physics_frame
	release_all()
	return false


## Boards a shuttle while it rests at its start, rides to the far end and steps off toward `off_x`.
func ride(shuttle: Node, off_x: float, limit: int = 900) -> bool:
	if not await until(func(): return shuttle.powered and shuttle.progress == 0.0 and shuttle.rest_left > 0.25, limit):
		return false
	if not await walk_to(shuttle.position.x - 6.0, 200):
		return false
	if not await until(func(): return shuttle.progress == 1.0, limit):
		return false
	return await walk_to(off_x, 200)


## Jumps whenever Sera is on the floor until she is past world x.
func hop_to(x: float, limit: int = 600) -> bool:
	Input.action_press(&"move_right")
	for frame in limit:
		if sera.position.x >= x:
			break
		if sera.is_on_floor() and not tree.paused:
			Input.action_press(&"jump")
			await tree.physics_frame
			Input.action_release(&"jump")
		await tree.physics_frame
	Input.action_release(&"move_right")
	return sera.position.x >= x


func finish(pass_line: String) -> void:
	release_all()
	await close_scene(tree)
	if failures.is_empty():
		print("PASS: " + pass_line)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	tree.quit(0 if failures.is_empty() else 1)


static func close_scene(tree: SceneTree) -> void:
	if tree.current_scene != null:
		tree.paused = true
		tree.current_scene.process_mode = Node.PROCESS_MODE_DISABLED
		await Audio.drain(tree.current_scene)
		tree.unload_current_scene()
	tree.paused = false
	await tree.process_frame
