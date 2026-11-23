extends "res://scripts/sector.gd"

## Stage 3-2 · 선창. Down in the ship's hold. Mirror turrets turn shockwaves
## back, so their own bolts have to be reflected into them, and the hold's
## doors answer only to ringed targets hit by a bolt reflected upward from a
## floor mark. A refrigerated container wall is climbed with a downward release.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/GateA, [$World/MirrorA])
	open_when_down($World/GateB, [$World/TargetA])
	open_when_down($World/GateC, [$World/TargetB])
	open_when_down(exit_gate, [$World/Keeper])
	say(200.0, &"cargo_hold_0", story(0))
	say(3470.0, &"cargo_hold_1", story(1))
	say(4870.0, &"cargo_hold_2", story(2))
