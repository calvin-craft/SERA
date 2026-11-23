extends "res://scripts/sector.gd"

## Stage 3-5 · 파이프 랙. Walkways through the platform's pipework, guarded by
## absorber suits: they drink shockwaves and fire them back as heavy shells,
## and only those shells reflected into them bring them down.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/GateA, [$World/AbsorberA])
	open_when_down($World/GateC, [$World/AbsorberC, $World/AbsorberD])
	open_when_down(exit_gate, [$World/Keeper, $World/LauncherE])
	say(200.0, &"pipe_rack_0", story(0))
	say(3870.0, &"pipe_rack_1", story(1))
	say(5650.0, &"pipe_rack_2", story(2))
