extends "res://scripts/sector.gd"

## Stage 7 · 외곽 링. The ring around the great wheel bleeds its speed into the
## belts. An optional maintenance lift leads over the reverse belts and steam.

@onready var maintenance_relay: Relay = $World/MaintenanceRelay
@onready var maintenance_lift: Shuttle = $World/MaintenanceLift
@onready var shield_relay: Relay = $World/ShieldRelay


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/SteamLock, [$World/RamA])
	open_when_down(exit_gate, [$World/Sentinel])
	power(shield_relay, $World/Sentinel)
	power(maintenance_relay, maintenance_lift)
	say(220.0, &"ring_start", story(0))
	say(2440.0, &"ring_bearing", story(1))
	say(3560.0, &"ring_vault", story(2))


func _at_maintenance_entrance() -> bool:
	return checkpoint == 1 and sera.position.x < 2510.0 and sera.position.y > 390.0


func hud_marker() -> Array:
	if _at_maintenance_entrance() and not maintenance_relay.powered:
		return [maintenance_relay.global_position, Texts.RING_MARK_MAINTENANCE, POWER]
	return super.hud_marker()


func stage_hints() -> Array:
	var hints := []
	if _at_maintenance_entrance() and not maintenance_relay.powered and sera.energy >= Sera.RELEASE_COST:
		hints.append(hint(&"ring_maintenance", maintenance_relay.global_position,
			spoken(Texts.RING_HINT_MAINTENANCE, [["W", "+", "RMB"]]), POWER))
	var sentinel: Guard = $World/Sentinel
	if checkpoint == 2 and sera.position.x > 4520.0 and sentinel.shielded and sera.energy >= Sera.RELEASE_COST and not knows(&"shield"):
		hints.append(hint(&"shield", shield_relay.global_position,
			spoken(Texts.RING_HINT_SHIELD, [["W", "+", "RMB"]]), HEAT))
	hints.append_array(super.stage_hints())
	return hints


func _on_relay_activated(relay: Relay) -> void:
	super._on_relay_activated(relay)
	if relay == maintenance_relay:
		learn(&"ring_maintenance")
		_show_feedback(Texts.RING_NOTE_MAINTENANCE, POWER)
	elif relay == shield_relay:
		learn(&"shield")
