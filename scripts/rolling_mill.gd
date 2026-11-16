extends "res://scripts/sector.gd"

## Stage 4 · 압연 라인. The reactor is down but the mill still turns on the
## great wheel's stored momentum. Belts lend (or steal) speed, stamping presses
## set a rhythm, and the first 돌격 기체 teaches standing your ground.


func _wire() -> void:
	exit_gate = $World/ExitGate
	open_when_down($World/RamGate, [$World/RamA])
	open_when_down(exit_gate, [$World/Warden])
	say(230.0, &"mill_start", story(0))
	say(2700.0, &"mill_press", story(1))
	say(4760.0, &"mill_exit", story(2))


func hud_marker() -> Array:
	var gate: Bulkhead = $World/RamGate
	if checkpoint == 1 and sera.position.x > 3870.0 and not gate.unlocked:
		var ram: Ram = $World/RamA
		if ram.is_stunned():
			return [ram.hit_point() + Vector2(0.0, -70.0), Texts.MILL_MARK_STRIKE, ICE]
	return super.hud_marker()
