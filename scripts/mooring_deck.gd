extends "res://scripts/sector.gd"

## Stage 3-4 · 계류 데크. The ship has run aground on the Kelder platform. Its
## mooring decks are guarded by missile launchers: armour turns shockwaves,
## so each missile has to be caught or reflected home. A bollard wall leads to
## the upper deck.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/GateA, [$World/LauncherA])
	open_when_down(exit_gate, [$World/LauncherD, $World/MirrorE])
	say(200.0, &"mooring_deck_0", story(0))
	say(3580.0, &"mooring_deck_1", story(1))
	say(5750.0, &"mooring_deck_2", story(2))
