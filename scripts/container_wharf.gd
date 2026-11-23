extends "res://scripts/sector.gd"

## Stage 2-5 · 컨테이너 부두. Guards with tower shields turn every shot from the
## front. Over the top with a downward release, or past them and into their backs.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down(exit_gate, [$World/ShieldE])
	say(200.0, &"container_wharf_0", story(0))
	say(2720.0, &"container_wharf_1", story(1))
	say(4420.0, &"container_wharf_2", story(2))
