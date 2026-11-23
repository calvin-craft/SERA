extends "res://scripts/sector.gd"

## Stage 2-7 · 방파제. Out along the breakwater in the waves. Bombers cruise over
## Sera dropping canisters: catch the blue ones, step away from the red ones, and
## shoot each bomber when it drifts aside.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down(exit_gate, [$World/Keeper])
	say(200.0, &"breakwater_0", story(0))
	say(2220.0, &"breakwater_1", story(1))
	say(4950.0, &"breakwater_2", story(2))
