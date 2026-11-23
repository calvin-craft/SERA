extends "res://scripts/sector.gd"

## Stage 2-8 · 항만 관제탑. The climb to the Dispatcher: the hold, the signal
## floor with its train trench, and the control bridge. Everything chapter two
## taught, on three floors.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down(exit_gate, [$World/Keeper, $World/BridgeTurret])
	say(200.0, &"harbor_tower_0", story(0))
	say(1650.0, &"harbor_tower_1", story(1))
	say(3050.0, &"harbor_tower_2", story(2))
