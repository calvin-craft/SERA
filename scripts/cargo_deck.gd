extends "res://scripts/sector.gd"

## Stage 3-1 · 화물선 갑판. Chapter three opens on the cargo ship's deck at
## sea. The deck rolls, lashed barrels break loose with every lean, and the
## suit can now turn a bolt back with a reflect: the first gun guards a gate.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/GateA, [$World/TurretA])
	open_when_down(exit_gate, [$World/Keeper, $World/TurretC])
	say(200.0, &"cargo_deck_0", story(0))
	say(1720.0, &"cargo_deck_1", story(1))
	say(5220.0, &"cargo_deck_2", story(2))
