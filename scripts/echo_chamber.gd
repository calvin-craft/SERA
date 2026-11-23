extends "res://scripts/sector.gd"

## Stage 3-8 · 반향실. The climb to Echo through the lab's test shaft:
## mirrors and an absorber on the bottom floor, a field to rise through, a
## target and a launcher in the middle, and the control floor at the top.
## Everything chapter three taught, on three floors.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/GateA, [$World/MirrorA, $World/AbsorberA])
	open_when_down($World/GateB, [$World/TargetB])
	open_when_down(exit_gate, [$World/Keeper, $World/LauncherC])
	say(200.0, &"echo_chamber_0", story(0))
	say(1870.0, &"echo_chamber_1", story(1))
	say(3270.0, &"echo_chamber_2", story(2))
