extends "res://scripts/stage.gd"

## Stage 2-3 · 장갑 열차. The boss of chapter two's first act: an armoured
## locomotive across the line. Catch its heavy shells in the air to open the
## shutter over its nose core, then step in and hit the core straight on.

const Boss = preload("res://scripts/train_boss.gd")
const SAFE_START := Vector2(220.0, 519.0)
const WAKE_X := 300.0
const ALERT := Color("#ffa583")
## Close enough to the nose that the shot starts past it still hits the core.
const POINT_BLANK := 130.0

var boss_name: String = Texts.BOSS_TRAIN

@onready var boss: Boss = $World/TrainBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		$FarBackground/Skyline.hide()
	super._ready()
	sera.forward_brace = true
	boss.player = sera
	_bind_weapon(boss)
	boss.heavy_fired.connect(_on_heavy_fired)
	boss.go_dormant()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.TRAIN_NOTE_WAKE, ALERT)
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


func _on_heavy_fired(origin: Vector2) -> void:
	var shot := Incoming.new()
	shot.position = origin
	shot.player = sera
	shot.direction = -1.0
	shot.heavy = true
	shot.absorbed.connect(_on_heavy_absorbed)
	shots.add_child(shot)
	_play(Audio.SHOT, -4.0, 0.72)


func _on_heavy_absorbed(origin: Vector2, charge: int, precise: bool) -> void:
	caught_shots += 1
	if precise:
		perfect_shots += 1
	learn(&"air_catch")
	learn(&"train_shell")
	boss.open_core()
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0, 0.9)
	_hitstop(0.11, 9.0, 0.14, ICE)
	_show_feedback(Texts.TRAIN_NOTE_SHELL_CAUGHT + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_release(origin: Vector2, direction: Vector2) -> void:
	super._on_release(origin, direction)
	# Pressed up against the nose the shot starts inside the hull; count it anyway.
	if not wave_active and direction.y == 0.0 and direction.x > 0.0 \
			and boss.core_point().x - sera.global_position.x < POINT_BLANK:
		_strike_core(boss.core_point())


func _resolve_stage_wave(next_distance: float) -> void:
	if boss.health <= 0 or boss in wave_hits:
		return
	if _wave_reaches(boss.core_point(), Boss.CORE_WIDTH, next_distance):
		_strike_core(boss.core_point())


func _strike_core(point: Vector2) -> void:
	if boss in wave_hits:
		return
	wave_hits.append(boss)
	if not boss.hit_core():
		effects.impact(point, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.TRAIN_NOTE_CORE_SHUT, HEAT)
		return
	learn(&"train_core")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.115, 12.0, 0.15, ICE)
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.TRAIN_NOTE_STOPPED, ICE)
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
		if not knows(&"train_start"):
			hints.append(hint(&"train_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"train_start")
	if boss.heavy_coming() and not knows(&"train_shell"):
		hints.append(hint(&"train_shell", boss.turret_point(), spoken(Texts.TRAIN_HINT_SHELL, [["Space", "+", "LMB"]])))
	elif boss.is_open() and not knows(&"train_core"):
		hints.append(hint(&"train_core", boss.core_point(), spoken(Texts.TRAIN_HINT_CORE, [["RMB"]])))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_open():
		return [boss.core_point() + Vector2(0.0, -60.0), Texts.MARK_OPEN_CORE, ICE]
	return []
