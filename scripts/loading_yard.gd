extends "res://scripts/stage.gd"

## Stage 6 · 출하 야드. The boss of act two: the yard crane 갠트리 guards the
## freight lift down to the wheel. Catch what it drops, step out from under it
## and answer with a diagonal shockwave.

const Boss = preload("res://scripts/gantry_boss.gd")
const SAFE_START := Vector2(240.0, 519.0)
const WAKE_X := 330.0
const ALERT := Color("#ffa583")

var boss_name: String = Texts.BOSS_GANTRY

@onready var boss: Boss = $World/GantryBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		backdrop.modulate = Color(0.92, 0.93, 0.95)
	super._ready()
	# Loads come from overhead, so Sera braces with her hands up as in the foundry.
	sera.forward_brace = false
	boss.player = sera
	_bind_weapon(boss)
	boss.load_caught.connect(_on_load_caught)
	boss.load_crashed.connect(_on_load_crashed)
	boss.go_dormant()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.YARD_NOTE_WAKE, ALERT)
		_play(Audio.WAKE, -4.0)
		shake = maxf(shake, 5.0)


func _camera_goal(_point: Vector2) -> Vector2:
	return Vector2(576.0, 342.0)


func _update_backdrop() -> void:
	backdrop.position.x = -58.0 - (sera.position.x - 556.0) * 0.032
	if complete:
		backdrop.modulate = backdrop.modulate.lerp(Color("#9ba7ad"), minf(1.0, 1.9 * get_process_delta_time()))
	art.queue_redraw()


func _reset_room() -> void:
	boss.reset_attempt()
	boss.go_dormant()


func _restore_room_progress() -> void:
	boss.health = Boss.HITS - checkpoint
	boss.reset_attempt()


func _on_load_caught(origin: Vector2, charge: int) -> void:
	learn(&"gantry_catch")
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0)
	_hitstop(0.076, 8.0, 0.12, ICE)
	_show_feedback(Texts.YARD_NOTE_CAUGHT + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_load_crashed(point: Vector2, hit_player: bool) -> void:
	effects.impact(point, true)
	_play(Audio.IMPACT, -4.0, 0.90)
	shake = maxf(shake, 9.0)
	if boss.heavy and not hit_player:
		learn(&"gantry_dodge")
		_show_feedback(Texts.YARD_NOTE_SLAB_EVADED, ICE)


func _resolve_stage_wave(next_distance: float) -> void:
	if boss.health <= 0 or boss in wave_hits:
		return
	var point := boss.core_point()
	if not _wave_reaches(point, Boss.CORE_WIDTH, next_distance):
		return
	wave_hits.append(boss)
	if not boss.hit_core():
		effects.impact(point, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.YARD_NOTE_CORE_SHUT, HEAT)
		return
	learn(&"gantry_core")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.115, 12.0, 0.15, ICE)
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.YARD_NOTE_STOPPED, ICE)
	else:
		_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


func aim_marks() -> Array:
	return boss.aim_marks() if boss.is_open() else []


func aim_target() -> Vector2:
	return boss.core_point() if boss.is_open() else Vector2.INF


func aim_width() -> float:
	return Boss.CORE_WIDTH


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		if not knows(&"yard_start"):
			hints.append(hint(&"yard_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"yard_start")
	var column := Vector2(boss.trolley_x, 330.0)
	if boss.threatens_from_above() and boss.heavy and not knows(&"gantry_dodge"):
		hints.append(hint(&"gantry_dodge", column, spoken(Texts.YARD_HINT_DODGE), HEAT))
	elif boss.threatens_from_above() and not boss.heavy and not knows(&"gantry_catch"):
		hints.append(hint(&"gantry_catch", column, spoken(Texts.YARD_HINT_CATCH, [["LMB"]])))
	elif boss.is_open() and not knows(&"gantry_core"):
		hints.append(hint(&"gantry_core", boss.core_point(),
			spoken(Texts.YARD_HINT_CORE, [["W", "+", "RMB"]])))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_open():
		var marks := boss.aim_marks()
		var nearest: Vector2 = marks[0] if absf(marks[0].x - sera.position.x) < absf(marks[1].x - sera.position.x) else marks[1]
		return [nearest + Vector2(0.0, -30.0), Texts.MARK_AIM, ICE]
	return []
