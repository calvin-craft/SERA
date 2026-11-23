extends "res://scripts/sector.gd"

## Stage 2-1 · 해안 선로. Chapter two opens on the freight line along the cliffs:
## trains are moving bridges over the trenches, and the signal yard's guns
## introduce turrets. The last trench runs the wrong way and has to be leapt.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/SignalGate, [$World/TurretA])
	open_when_down(exit_gate, [$World/Warden])
	say(200.0, &"coastal_line_0", story(0))
	say(2620.0, &"coastal_line_1", story(1))
	say(5000.0, &"coastal_line_2", story(2))
