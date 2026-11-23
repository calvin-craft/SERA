extends "res://scripts/stage.gd"

## Stage 2-6 · 스트래들 캐리어. The boss of chapter two's second act. Catch a blue
## container from under the carrier, fire at your own feet to bounce up through
## its roof, then fire down onto the core plate while it is unlocked.

const Boss = preload("res://scripts/carrier_boss.gd")
const SAFE_START := Vector2(150.0, 519.0)
const WAKE_X := 250.0
const ALERT := Color("#ffa583")

var boss_name: String = Texts.BOSS_CARRIER

@onready var boss: Boss = $World/CarrierBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		$FarBackground/Skyline.hide()
	super._ready()
	# Containers come from overhead, so Sera braces with her hands up.
	sera.forward_brace = false
	boss.player = sera
	_bind_weapon(boss)
	boss.load_caught.connect(_on_load_caught)
	boss.load_crashed.connect(_on_load_crashed)
	boss.jolted.connect(_on_jolted)
	boss.go_dormant()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.CARRIER_NOTE_WAKE, ALERT)
		_play(Audio.WAKE, -4.0)
		shake = maxf(shake, 5.0)


func _camera_goal(_point: Vector2) -> Vector2:
	return Vector2(576.0, 342.0)


func _update_backdrop() -> void:
	art.queue_redraw()


func _reset_room() -> void:
	boss.reset_attempt()
	boss.go_dormant()


func _restore_room_progress() -> void:
	boss.health = Boss.HITS - checkpoint
	boss.reset_attempt()


func _on_load_caught(origin: Vector2, charge: int) -> void:
	learn(&"carrier_catch")
	caught_shots += 1
	# The carrier's containers hold a full charge: one bounce up, one strike down.
	sera.energy = Sera.CAPACITY
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0)
	_hitstop(0.076, 8.0, 0.12, ICE)
	_show_feedback(Texts.CARRIER_NOTE_CAUGHT + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_load_crashed(point: Vector2, hit_player: bool) -> void:
	effects.impact(point, true)
	_play(Audio.IMPACT, -4.0, 0.88)
	shake = maxf(shake, 9.0)
	if boss.heavy and not hit_player:
		learn(&"carrier_dodge")
		_show_feedback(Texts.CARRIER_NOTE_SLAB_EVADED, ICE)


func _on_jolted() -> void:
	_show_feedback(Texts.CARRIER_NOTE_SHAKEN, HEAT)
	_play(Audio.IMPACT, -6.0, 0.7)
	shake = maxf(shake, 7.0)


func _on_release(origin: Vector2, direction: Vector2) -> void:
	super._on_release(origin, direction)
	if direction.y > 0.5 and boss.health > 0 and boss.stomp_reaches(sera):
		_strike_core()


func _strike_core() -> void:
	var point := boss.core_point()
	if not boss.hit_core():
		effects.impact(point, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.CARRIER_NOTE_CORE_SHUT, HEAT)
		return
	learn(&"carrier_core")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.115, 12.0, 0.15, ICE)
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.CARRIER_NOTE_STOPPED, ICE)
	else:
		_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


func aim_marks() -> Array:
	return []


func aim_target() -> Vector2:
	return Vector2.INF


func aim_width() -> float:
	return Boss.CORE_WIDTH


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		if not knows(&"carrier_start"):
			hints.append(hint(&"carrier_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"carrier_start")
	var under := Vector2(boss.cx, 400.0)
	if boss.threatens_from_above() and boss.heavy and not knows(&"carrier_dodge"):
		hints.append(hint(&"carrier_dodge", under, spoken(Texts.CARRIER_HINT_DODGE), HEAT))
	elif boss.threatens_from_above() and not boss.heavy and not knows(&"carrier_catch"):
		hints.append(hint(&"carrier_catch", under, spoken(Texts.CARRIER_HINT_CATCH, [["LMB"]])))
	elif boss.is_open() and not knows(&"carrier_core"):
		if boss.on_roof(sera):
			hints.append(hint(&"carrier_stomp", boss.core_point(), spoken(Texts.CARRIER_HINT_STOMP, [["S", "+", "RMB"]])))
		else:
			hints.append(hint(&"carrier_climb", boss.core_point(), spoken(Texts.CARRIER_HINT_CLIMB, [["S", "+", "RMB"]])))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_open():
		return [boss.core_point() + Vector2(0.0, -40.0), Texts.MARK_OPEN_CORE, ICE]
	return []
