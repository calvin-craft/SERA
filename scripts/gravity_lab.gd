extends "res://scripts/sector.gd"

## Stage 3-7 · 중력 시험동. The test halls where the suits were tried, their
## gravity rigs still running. In a field Sera falls slowly and shots crawl:
## the first room is climbed by jumping, the corridor's gaps can only be
## jumped while its field is on, and the last room ends with an absorber and
## a target behind the isolation door.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down(exit_gate, [$World/AbsorberE, $World/TargetE])
	say(200.0, &"gravity_lab_0", story(0))
	say(2250.0, &"gravity_lab_1", story(1))
	say(4780.0, &"gravity_lab_2", story(2))
