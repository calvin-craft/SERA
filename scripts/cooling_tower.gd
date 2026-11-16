extends "res://scripts/stage.gd"

const Lift = preload("res://scripts/freight_lift.gd")
const Valve = preload("res://scripts/pulse_valve.gd")
const POWER := Color("#7eead8")
const LIFT_AIM_X := 564.0
const SHIELD_AIM_X := 2215.0
const UPPER_CHECKPOINT := Vector2(1042, 686)
const ARENA_CHECKPOINT := Vector2(1994, 599)
const EXIT_X := 3186.0

@onready var lower_valve: Valve = $World/LowerValve
@onready var upper_valve: Valve = $World/UpperValve
@onready var lift_relay: Relay = $World/LiftRelay
@onready var shield_relay: Relay = $World/ShieldRelay
@onready var lift: Lift = $World/FreightLift
@onready var sentinel: Guard = $World/Sentinel
@onready var exit_gate: Bulkhead = $World/ExitGate
@onready var deck_art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop
@onready var aim_guide: Node2D = $World/AimGuide


func _ready() -> void:
	guards = [sentinel]
	relays = [lift_relay, shield_relay]
	super._ready()
	lift.rider = sera
	lift_relay.activated.connect(_on_lift_activated)
	shield_relay.activated.connect(_on_shield_deactivated)
	for valve in [lower_valve, upper_valve]:
		valve.target = sera
		_bind_weapon(valve)
	sera.forward_brace = true


func _camera_goal(point: Vector2) -> Vector2:
	var lead := 134.0 + clampf(sera.velocity.x * 0.10, -88.0, 85.0)
	return Vector2(clampf(point.x + lead, 516.0, 2724.0),
		clampf(point.y - 176.0, 377.0, 835.0))


func _update_backdrop() -> void:
	backdrop.position = Vector2(-46.0 - clampf((camera.position.x - 576.0) * 0.065, 0.0, 194.0),
		-95.0 + clampf((835.0 - camera.position.y) * 0.13, 0.0, 62.0))
	aim_guide.queue_redraw()


func _update_floor_progress() -> void:
	if not sera.is_on_floor():
		return
	var x := sera.position.x
	if checkpoint < 2 and x >= 1959.0 and sera.position.y <= 604.0:
		_reach_checkpoint(2, ARENA_CHECKPOINT)
		deck_art.queue_redraw()
	elif checkpoint == 0 and x >= 1022.0 and x < 1695.0 and sera.position.y <= 690.0:
		_reach_checkpoint(1, UPPER_CHECKPOINT)
		deck_art.queue_redraw()


func _exit_spot() -> Vector2:
	return Vector2(EXIT_X, 600.0)


func _exit_ready() -> bool:
	return exit_gate.unlocked


func _reset_room() -> void:
	lift.park(checkpoint > 0)
	lower_valve.reset_valve()
	upper_valve.reset_valve()


func _saved_spawn(index: int) -> Vector2:
	if index == 2:
		return ARENA_CHECKPOINT
	return UPPER_CHECKPOINT if index == 1 else checkpoint_position


func _restore_room_progress() -> void:
	if checkpoint > 0:
		lift_relay.energize(true)
	if lift_relay.powered:
		lift.power_on()
		lift.park(checkpoint > 0)
	if sentinel.knocked_out:
		shield_relay.energize(true)
		exit_gate.unlock(true)
	sentinel.shielded = not shield_relay.powered
	deck_art.queue_redraw()


func _update_progress() -> void:
	if lift.motion == Lift.Motion.UP:
		learn(&"lift")
	_update_floor_progress()


func _on_lift_activated() -> void:
	lift.power_on()
	_relay_feedback(lift_relay, Texts.TOWER_NOTE_LIFT_POWER)


func _on_shield_deactivated() -> void:
	learn(&"shield")
	sentinel.shielded = false
	sentinel.queue_redraw()
	_relay_feedback(shield_relay, Texts.TOWER_NOTE_SHIELD_CUT)


func _relay_feedback(relay: Relay, message: String) -> void:
	deck_art.queue_redraw()
	effects.catch_shot(relay.global_position, true)
	_show_feedback(message, POWER)
	_play(Audio.RELAY, -3.0)
	_hitstop(0.063, 4.0, 0.07, ICE)


func _on_guard_hit(guard: Guard) -> void:
	if guard.knocked_out:
		exit_gate.unlock()
		_show_feedback(Texts.TOWER_NOTE_EXIT_OPEN, ICE)
	else:
		_show_feedback(Texts.NOTE_ARMOR_BROKEN, HEAT)


func aim_target() -> Relay:
	var x := sera.position.x
	if not lift_relay.powered and absf(x - LIFT_AIM_X) < 146.0 and sera.position.y > 895.0:
		return lift_relay
	if not shield_relay.powered and absf(x - SHIELD_AIM_X) < 153.0 and sera.position.y < 650.0:
		return shield_relay
	return null


func hud_section() -> String:
	if sera.position.x >= 1940.0 and sera.position.y < 700.0:
		return stage_label(2)
	if sera.position.y < 830.0:
		return stage_label(1)
	return stage_label(0)


func stage_hints() -> Array:
	var hints := []
	var lower := sera.position.y > 895.0
	if lower and not lift_relay.powered:
		if sera.energy < Sera.RELEASE_COST and not knows(&"absorb_shot"):
			hints.append(hint(&"absorb_shot", lower_valve.global_position + Vector2(0.0, -150.0),
				spoken(Texts.TOWER_HINT_VALVE, [["LMB"]])))
		elif sera.energy >= Sera.RELEASE_COST and not knows(&"release_up"):
			hints.append(hint(&"release_up", lift_relay.global_position,
				spoken(Texts.TOWER_HINT_LIFT_RELAY, [["W", "+", "RMB"]]), POWER))
	if lower and lift_relay.powered and lift.motion == Lift.Motion.BOTTOM and not knows(&"lift"):
		hints.append(hint(&"lift", lift.global_position + Vector2(0.0, -40.0), spoken(Texts.TOWER_HINT_LIFT), POWER))
	if not lower and sera.position.x > 994.0 and sera.position.x < 1695.0 and sera.energy >= Sera.BOOST_COST and not knows(&"boost_up"):
		hints.append(hint(&"boost_up", Vector2(1653.0, 600.0),
			spoken(Texts.TOWER_HINT_LEAP, [["W", "+", "Shift"]]), POWER))
	if sera.position.x >= 1940.0 and sera.position.y < 718.0 and sentinel.shielded and sera.energy >= Sera.RELEASE_COST and not knows(&"shield"):
		hints.append(hint(&"shield", shield_relay.global_position,
			spoken(Texts.TOWER_HINT_SHIELD, [["W", "+", "RMB"]]), HEAT))
	return hints


func hud_marker() -> Array:
	if sera.position.x >= 1940.0 and sera.position.y < 715.0:
		if exit_gate.unlocked:
			return [Vector2(EXIT_X, 385.0), Texts.MARK_EXIT, POWER]
		if not shield_relay.powered:
			return [shield_relay.position + Vector2(0, -43), Texts.MARK_SHIELD_RELAY, HEAT]
	elif sera.position.y < 692.0 and sera.position.x > 994.0:
		if sera.energy < Sera.BOOST_COST:
			return [upper_valve.position + Vector2(0, -135), Texts.MARK_VALVE, ICE]
		return [Vector2(1653, 622), Texts.MARK_LEAP, POWER]
	elif lift_relay.powered:
		return [lift.position + Vector2(0, -152), Texts.MARK_LIFT, POWER]
	elif sera.energy >= Sera.RELEASE_COST or (sera.state == Sera.State.RELEASE and sera.release_up):
		return [lift_relay.position + Vector2(0, -44), Texts.MARK_LIFT_RELAY, HEAT]
	else:
		return [lower_valve.position + Vector2(0, -135), Texts.MARK_VALVE, ICE]
	return []
