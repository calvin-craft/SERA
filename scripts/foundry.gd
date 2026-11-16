extends "res://scripts/stage.gd"

const CHECKPOINTS := [Vector2(150, 519), Vector2(1290, 519), Vector2(2880, 443)]
const EXIT_X := 4236.0

var caught_beam := false

@onready var warden: Guard = $World/Warden
@onready var furnace_warden: Guard = $World/FurnaceWarden
@onready var security_gate: Bulkhead = $World/SecurityGate
@onready var exit_gate: Bulkhead = $World/ExitGate
@onready var beam = $World/FallingBeam
@onready var recharge_beam = $World/RechargeBeam
@onready var deck: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop
@onready var furnace: Sprite2D = $FarBackground/Furnace


func _ready() -> void:
	guards = [warden, furnace_warden]
	super._ready()
	for source in [beam, recharge_beam]:
		source.warned.connect(_on_warning)
		source.captured.connect(_on_captured)
		source.crashed.connect(_on_beam_crash)


func _update_backdrop() -> void:
	backdrop.position = Vector2(-55.0 - minf((camera.position.x - 576.0) * 0.058, 135.0),
		-48.0 + (342.0 - camera.position.y) * 0.18)
	furnace.position = Vector2(-58.0 - clampf((camera.position.x - 2400.0) * 0.057, 0.0, 118.0), -44.0)
	furnace.modulate.a = smoothstep(2290.0, 3040.0, camera.position.x)


func _update_progress() -> void:
	var x := sera.position.x
	sera.forward_brace = x >= 1236.0 and absf(x - recharge_beam.position.x) > 128.0
	if not sera.is_on_floor():
		return
	if checkpoint < 2 and x >= 2841.0 and sera.position.y <= 447.0:
		_reach_checkpoint(2, CHECKPOINTS[2])
		deck.queue_redraw()
	elif checkpoint == 0 and x >= 1247.0 and x < 2590.0 and sera.position.y <= 523.0:
		_reach_checkpoint(1, CHECKPOINTS[1])
		deck.queue_redraw()


func _exit_spot() -> Vector2:
	return Vector2(EXIT_X, 444.0)


func _exit_ready() -> bool:
	return exit_gate.unlocked


func _reset_room() -> void:
	beam.reset_beam()
	recharge_beam.reset_beam()


func _saved_spawn(index: int) -> Vector2:
	return CHECKPOINTS[index]


func _restore_room_progress() -> void:
	if checkpoint >= 2 and not warden.knocked_out:
		warden.restore_defeated()
	if warden.knocked_out:
		security_gate.unlock(true)
	if furnace_warden.knocked_out:
		exit_gate.unlock(true)
	caught_beam = checkpoint > 0 or checkpoint_charge >= Sera.BOOST_COST
	deck.queue_redraw()


func _on_guard_hit(guard: Guard) -> void:
	if guard.knocked_out:
		var gate := exit_gate if guard == furnace_warden else security_gate
		gate.unlock()
		_show_feedback(Texts.NOTE_EXIT_OPEN if guard == furnace_warden else Texts.FOUNDRY_NOTE_PASSAGE, ICE)
	else:
		_show_feedback(Texts.FOUNDRY_NOTE_HEAVY_ARMOR, HEAT)


func hud_section() -> String:
	if sera.position.x >= 2828.0:
		return stage_label(2)
	if sera.position.x >= 1236.0:
		return stage_label(1)
	return stage_label(0)


func stage_hints() -> Array:
	var hints := []
	var x := sera.position.x
	if x < 1020.0:
		var beam_ready: bool = beam.phase == beam.Phase.WAIT or beam.phase == beam.Phase.WARNING
		if not knows(&"absorb_beam") and sera.energy < Sera.BOOST_COST and beam_ready:
			hints.append(hint(&"absorb_beam", Vector2(beam.position.x, 300.0),
				spoken(Texts.FOUNDRY_HINT_BEAM, [["LMB"]]), HEAT if beam.phase == beam.Phase.WARNING else ICE))
		elif not knows(&"boost_up") and sera.energy >= Sera.BOOST_COST:
			hints.append(hint(&"boost_up", Vector2(990.0, 440.0),
				spoken(Texts.FOUNDRY_HINT_LEAP, [["W", "+", "Shift"]])))
	elif x < 2600.0 and warden.knocked_out and sera.energy < Sera.BOOST_COST and not knows(&"recharge"):
		if recharge_beam.phase == recharge_beam.Phase.WAIT or recharge_beam.phase == recharge_beam.Phase.WARNING:
			hints.append(hint(&"recharge", Vector2(recharge_beam.position.x, 300.0),
				spoken(Texts.FOUNDRY_HINT_RECHARGE, [["LMB"]]), HEAT))
	return hints


func hud_marker() -> Array:
	var x := sera.position.x
	if x < 1236.0:
		if sera.energy >= Sera.BOOST_COST:
			return [Vector2(986, 461), Texts.MARK_LEAP, ICE]
		if beam.phase != beam.Phase.FALL:
			return [Vector2(448, 217), Texts.FOUNDRY_MARK_ABSORB, HEAT]
	elif x < 2828.0 and warden.knocked_out:
		if sera.energy < Sera.BOOST_COST:
			return [Vector2(2200, 220), Texts.FOUNDRY_MARK_RECHARGE, HEAT]
		return [Vector2(2569, 462), Texts.FOUNDRY_MARK_HIGH_DECK, ICE]
	elif exit_gate.unlocked:
		return [Vector2(EXIT_X, 230.0), Texts.MARK_EXIT, ICE]
	return []


func _camera_goal(point: Vector2) -> Vector2:
	var lead := 127.0 + clampf(sera.velocity.x * 0.12, -96.0, 115.0)
	var base_y := lerpf(342.0, 267.0, smoothstep(2480.0, 2970.0, point.x))
	var floor_y := lerpf(520.0, 444.0, smoothstep(2540.0, 2828.0, point.x))
	var upward := clampf((floor_y - point.y) * 0.22, 0.0, 24.0)
	return Vector2(clampf(point.x + lead, 576.0, 4000.0), base_y - upward)


func _on_warning() -> void:
	_play(Audio.SHOT_CUE, -4.0, 0.83)


func _on_captured(origin: Vector2, _charge: int) -> void:
	caught_beam = true
	learn(&"recharge" if origin.x > 1236.0 else &"absorb_beam")
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0)
	_hitstop(0.076, 8.0, 0.12, ICE)


func _on_beam_crash(origin: Vector2) -> void:
	effects.impact(origin, true)
	_play(Audio.IMPACT, -4.0, 0.92)
	shake = maxf(shake, 9.0)
