extends "res://scripts/sector.gd"

## Stage 2-4 · 조차장. The marshalling yard, walled in by containers. From here
## Sera can fire at her own feet: the blast throws her over walls a leap cannot
## top and breaks cracked hatches. The upper route ends at a stack; the way on is
## down through a hatch, along the corridor underneath and back up the steps.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down(exit_gate, [$World/Warden])
	say(200.0, &"rail_yard_0", story(0))
	say(2100.0, &"rail_yard_1", story(1))
	say(4530.0, &"rail_yard_2", story(2))
