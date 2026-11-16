extends "res://scripts/sector.gd"

## Stage 8 · 관제 중추. Three floors up the Foreman's tower, each one an exam
## on an earlier act: a ram and a drone together, presses on a belt under a
## warden's fire, then a timed door behind steam and a shielded sentinel.


func _wire() -> void:
	exit_gate = $World/ExitGate
	power($World/LiftRelay, $World/LiftA)
	open_when_down($World/MiddleGate, [$World/WardenA])
	power($World/TimedRelay, $World/Shutter)
	power($World/ShieldRelay, $World/Sentinel)
	open_when_down(exit_gate, [$World/Sentinel])
	say(230.0, &"spine_start", story(0))
	say(1590.0, &"spine_past", story(1))
	say(2970.0, &"spine_vow", story(2))


func stage_hints() -> Array:
	var hints := []
	var lift_relay: Relay = $World/LiftRelay
	var sentinel: Guard = $World/Sentinel
	if checkpoint == 0 and not lift_relay.powered and sera.energy >= Sera.RELEASE_COST and sera.position.x > 700.0 and not knows(&"relay"):
		hints.append(hint(&"relay", lift_relay.global_position,
			spoken(Texts.SPINE_HINT_LIFT_RELAY, [["W", "+", "RMB"]]), POWER))
	if checkpoint == 2 and sera.position.x > 3440.0 and sentinel.shielded and sera.energy >= Sera.RELEASE_COST and not knows(&"shield"):
		hints.append(hint(&"shield", $World/ShieldRelay.global_position,
			spoken(Texts.SPINE_HINT_SHIELD, [["W", "+", "RMB"]]), HEAT))
	hints.append_array(super.stage_hints())
	return hints


func hud_marker() -> Array:
	var lift_relay: Relay = $World/LiftRelay
	if checkpoint == 0 and sera.position.x > 700.0:
		if not lift_relay.powered:
			return [lift_relay.position + Vector2(0.0, -44.0), Texts.MARK_LIFT_RELAY, HEAT]
		return [$World/LiftA.position + Vector2(0.0, -120.0), Texts.MARK_LIFT, POWER]
	return super.hud_marker()


func _on_relay_activated(relay: Relay) -> void:
	super._on_relay_activated(relay)
	if relay == $World/ShieldRelay:
		learn(&"shield")
