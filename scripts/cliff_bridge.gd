extends "res://scripts/sector.gd"

## Stage 2-2 · 절벽 철교. Sea wind across a rail bridge: jumps go with the gusts
## or wait them out. From here Sera can catch bolts in the air, and the bridge's
## high guns fire over her head so that is the only way to fill the suit.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down(exit_gate, [$World/Warden])
	say(200.0, &"cliff_bridge_0", story(0))
	say(2560.0, &"cliff_bridge_1", story(1))
	say(5020.0, &"cliff_bridge_2", story(2))
