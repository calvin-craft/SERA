extends "res://scripts/sector.gd"

## Stage 5 · 증기 배관로. With the cooling gone the pipes are bursting. Timed
## jets are waited out, the ones that never stop are dashed through, and the
## Foreman's first hover drones come looking.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/DroneGate, [$World/DroneA])
	open_when_down(exit_gate, [$World/DroneC])
	power($World/TimedRelay, $World/Shutter)
	say(220.0, &"steam_start", story(0))
	say(1830.0, &"steam_drone", story(1))
	say(3250.0, &"steam_exit", story(2))
