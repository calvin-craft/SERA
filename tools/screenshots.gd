extends SceneTree

## Opens each of the later stages in a real window, moves Sera to the spots
## worth looking at and saves the screen as PNG files in tmp/shots.
## Run without --headless:  godot --path <project> --script res://tools/screenshots.gd

var out_dir := ""
var only := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://tmp/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	only = OS.get_environment("SHOT_ONLY")
	_run.call_deferred()


func _run() -> void:
	if _wanted("title"):
		await _title()
	if _wanted("mill"):
		await _mill()
	if _wanted("steam"):
		await _steam()
	if _wanted("yard"):
		await _yard()
	if _wanted("ring"):
		await _ring()
	if _wanted("spine"):
		await _spine()
	if _wanted("wheel"):
		await _wheel()
	paused = false
	quit(0)


func _wanted(group: String) -> bool:
	return only.is_empty() or only.contains(group)


func _open(path: String, intro_shot: String = "") -> Node:
	paused = false
	change_scene_to_file(path)
	await scene_changed
	if not intro_shot.is_empty():
		await _wait(1.3)
		await _shot(intro_shot)
		await _wait(1.9)
	else:
		await _wait(3.1)
	return current_scene


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _until(condition: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not condition.call():
		await process_frame
		left -= 1.0 / 60.0


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


## Puts Sera on the floor at `point` and snaps the camera there.
func _place(level: Node, point: Vector2, energy: int = 60) -> void:
	paused = false
	level.freeze_left = 0.0
	level.sera.reset_at(point, energy)
	level.sera.invulnerable_left = 0.0
	if "ground_y" in level:
		level.ground_y = point.y
	level.camera.position = level._camera_goal(point)
	await _wait(0.25)


func _title() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await scene_changed
	await _wait(1.6)
	await _shot("title_main")
	var title := current_scene
	title.practice_button.grab_focus()
	title._show_practice()
	await _wait(0.9)
	await _shot("title_practice_act1")
	title.stage_buttons[4].grab_focus()
	await _wait(0.9)
	await _shot("title_practice_act2")
	title.stage_buttons[8].grab_focus()
	await _wait(0.9)
	await _shot("title_practice_act3")


func _mill() -> void:
	var mill := await _open("res://scenes/rolling_mill.tscn", "mill_intro")
	await _place(mill, Vector2(960.0, 519.0))
	await _shot("mill_feed_belt")
	await _place(mill, Vector2(2100.0, 519.0))
	await _shot("mill_return_belt")
	await _place(mill, Vector2(3060.0, 519.0))
	var press: Node = mill.get_node("World/PressA")
	await _until(func(): return press.warning(), 3.0)
	await _wait(0.3)
	await _shot("mill_presses")
	await _place(mill, Vector2(4020.0, 519.0))
	var ram: Node = mill.rams[0]
	await _until(func(): return ram.state == ram.State.AIM, 3.0)
	await _wait(0.4)
	await _shot("mill_ram_aim")
	ram.state = ram.State.STUN
	ram.left = 2.5
	ram.position.x = 4200.0
	await _wait(0.3)
	await _shot("mill_ram_stunned")
	await _place(mill, Vector2(6100.0, 519.0))
	await _wait(0.8)
	await _shot("mill_warden_exit")
	mill._finish_stage()
	await _wait(2.0)
	await _shot("mill_clear")


func _steam() -> void:
	var works := await _open("res://scenes/steam_works.tscn")
	await _place(works, Vector2(420.0, 519.0))
	var jet: Node = works.get_node("World/SteamA")
	await _until(func(): return jet.active(), 4.0)
	await _wait(0.5)
	await _shot("steam_timed_jet")
	await _place(works, Vector2(1040.0, 519.0), 40)
	await _wait(0.5)
	await _shot("steam_constant_jet")
	await _place(works, Vector2(2000.0, 519.0))
	var drone: Node = works.get_node("World/DroneA")
	await _wait(0.6)
	await _shot("steam_drone_hover")
	await _until(func(): return drone.state == drone.State.AIM, 5.0)
	await _wait(0.3)
	await _shot("steam_drone_aim")
	await _place(works, Vector2(2812.0, 519.0))
	Input.action_press(&"aim_up")
	await _wait(0.4)
	await _shot("steam_timed_relay")
	Input.action_release(&"aim_up")
	works.get_node("World/TimedRelay").energize()
	paused = false
	await _wait(0.9)
	await _shot("steam_relay_live")
	await _place(works, Vector2(3250.0, 519.0))
	await _wait(1.5)
	await _shot("steam_ferry")
	await _place(works, Vector2(4500.0, 519.0))
	await _wait(0.6)
	await _shot("steam_exit")


func _yard() -> void:
	var yard := await _open("res://scenes/loading_yard.tscn")
	var boss: Node = yard.boss
	await _shot("yard_dormant")
	await _place(yard, Vector2(560.0, 519.0), 0)
	await _until(func(): return boss.state == boss.State.LOCK, 4.0)
	await _wait(0.4)
	await _shot("yard_beam_lock")
	await _until(func(): return boss.state == boss.State.DROP, 2.0)
	await _wait(0.25)
	await _shot("yard_beam_falling")
	boss.cargo.clear()
	boss._on_cargo_caught(Vector2(560.0, 380.0), 100)
	paused = false
	yard.freeze_left = 0.0
	yard.sera.energy = 100
	await _place(yard, Vector2(boss.trolley_x - boss.AIM_OFFSET, 519.0), 100)
	Input.action_press(&"aim_up")
	await _wait(0.4)
	await _shot("yard_core_open_aim")
	Input.action_release(&"aim_up")
	boss.health = 2
	boss.reset_attempt()
	await _place(yard, Vector2(700.0, 519.0), 0)
	await _until(func(): return boss.state == boss.State.LOCK and boss.heavy, 4.0)
	await _wait(0.4)
	await _shot("yard_slab_lock")
	await _until(func(): return boss.sweep_warning > 0.0, 5.0)
	await _wait(0.4)
	await _shot("yard_wall_sweep")


func _ring() -> void:
	var ring := await _open("res://scenes/outer_ring.tscn")
	await _place(ring, Vector2(1010.0, 519.0))
	await _shot("ring_ramp_pit")
	await _place(ring, Vector2(2050.0, 519.0))
	await _wait(0.5)
	await _shot("ring_ram_steam_lock")
	await _place(ring, Vector2(2960.0, 519.0))
	await _wait(1.0)
	await _shot("ring_island")
	await _place(ring, Vector2(3880.0, 519.0))
	await _wait(1.2)
	await _shot("ring_ferry")
	await _place(ring, Vector2(4932.0, 519.0))
	Input.action_press(&"aim_up")
	await _wait(0.8)
	await _shot("ring_sentinel_relay")
	Input.action_release(&"aim_up")


func _spine() -> void:
	var spine := await _open("res://scenes/control_spine.tscn")
	await _place(spine, Vector2(520.0, 1159.0))
	await _wait(0.8)
	await _shot("spine_lower_arena")
	await _place(spine, Vector2(1150.0, 1159.0))
	spine.get_node("World/LiftRelay").energize()
	paused = false
	await _wait(2.4)
	await _shot("spine_lift")
	await _place(spine, Vector2(1640.0, 839.0))
	await _wait(0.8)
	await _shot("spine_middle_belt")
	await _place(spine, Vector2(2560.0, 839.0))
	await _wait(0.8)
	await _shot("spine_second_lift")
	await _place(spine, Vector2(3102.0, 519.0))
	await _wait(0.9)
	await _shot("spine_timed_door")
	await _place(spine, Vector2(3690.0, 519.0))
	await _wait(1.0)
	await _shot("spine_control_room")


func _wheel() -> void:
	var wheel := await _open("res://scenes/great_wheel.tscn")
	var boss: Node = wheel.boss
	await _shot("wheel_dormant")
	await _place(wheel, Vector2(492.0, 519.0), 60)
	await _until(func(): return boss.state == boss.State.BOLT_WARN, 4.0)
	await _wait(0.4)
	Input.action_press(&"aim_up")
	await _wait(0.1)
	await _shot("wheel_phase1_shield")
	Input.action_release(&"aim_up")
	boss.health = 2
	boss.reset_attempt()
	await _place(wheel, Vector2(420.0, 519.0), 0)
	await _until(func(): return boss.state == boss.State.REV, 4.0)
	await _wait(0.5)
	await _shot("wheel_phase2_rev")
	boss._enter(boss.State.STUN, 2.8)
	boss.x = 560.0
	await _wait(0.4)
	await _shot("wheel_phase2_stun")
	boss.health = 1
	boss.reset_attempt()
	await _place(wheel, Vector2(480.0, 519.0), 0)
	await _until(func(): return boss.state == boss.State.LOCK, 5.0)
	await _wait(0.4)
	await _shot("wheel_phase3_lock")
	boss.cargo.clear()
	boss._on_cargo_caught(Vector2(480.0, 380.0), 100)
	paused = false
	wheel.freeze_left = 0.0
	await _place(wheel, Vector2(boss.PERCH_AIM_X, 519.0), 100)
	Input.action_press(&"aim_up")
	await _wait(0.4)
	await _shot("wheel_phase3_open")
	Input.action_release(&"aim_up")
	boss.health = 0
	boss._enter(boss.State.DOWN, 0.0)
	wheel._begin_finale()
	await _wait(1.2)
	await _shot("wheel_finale")
	wheel._finish_stage()
	await _wait(2.2)
	await _shot("wheel_clear")
