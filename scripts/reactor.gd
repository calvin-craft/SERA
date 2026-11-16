extends "res://scripts/stage.gd"

const Boss = preload("res://scripts/reactor_boss.gd")
const AIM_X := 745.0
const SAFE_START := Vector2(600.0, 519.0)
const ALERT := Color("#ffa583")

@onready var boss: Boss = $World/ReactorBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


const WAKE_X := 680.0


func _ready() -> void:
	super._ready()
	sera.forward_brace = true
	boss.player = sera
	_bind_weapon(boss)
	boss.press_impact.connect(_on_press_impact)
	# Every visit starts with the guardian idle; it only powers up once Sera steps forward.
	boss.go_dormant()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.REACTOR_NOTE_WAKE, ALERT)
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


func _restore_room_progress() -> void:
	boss.health = Boss.CORE_HITS - checkpoint
	boss.reset_attempt()


func _on_shot_absorbed(origin: Vector2, charge: int, precise: bool) -> void:
	super._on_shot_absorbed(origin, charge, precise)
	if boss.open_from_catch():
		learn(&"core_open")
		var message: String = Texts.REACTOR_NOTE_CORE_OPEN_PRECISE if precise else Texts.REACTOR_NOTE_CORE_OPEN
		if charge > 0:
			message += "  +%d" % charge
		_show_feedback(message, ICE)
		effects.catch_shot(boss.core_point(), precise)


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
		_show_feedback(Texts.REACTOR_NOTE_CORE_SHUT, HEAT)
		return

	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.115, 12.0, 0.15, ICE)
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.REACTOR_NOTE_STOPPED, ICE)
	else:
		_reach_checkpoint(Boss.CORE_HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


func _on_press_impact(point: Vector2, hit_player: bool) -> void:
	effects.impact(point, true)
	_play(Audio.IMPACT, -4.0, 0.85)
	shake = maxf(shake, 10.0)
	if not hit_player:
		_show_feedback(Texts.REACTOR_NOTE_PRESS_EVADED, ICE)


func hud_section() -> String:
	return boss_label(Texts.BOSS_REACTOR)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		return hints
	if not boss.is_open() and not knows(&"core_open"):
		hints.append(hint(&"core_open", boss.core_point(),
			spoken(Texts.REACTOR_HINT_OPEN_CORE, [["LMB"]])))
	elif boss.is_open() and boss.needs_aim_up() and not knows(&"release_up"):
		hints.append(hint(&"release_up", boss.core_point(),
			spoken(Texts.REACTOR_HINT_AIM_UP, [["W", "+", "RMB"]])))
	elif boss.is_open() and not boss.needs_aim_up() and not knows(&"release"):
		hints.append(hint(&"release", boss.core_point(),
			spoken(Texts.REACTOR_HINT_STRIKE, [["RMB"]])))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_open():
		return [boss.core_point() + Vector2(0.0, -45.0), Texts.MARK_OPEN_CORE, ICE]
	return []
