extends "res://scripts/stage.gd"

## Stage 3-9 · 에코. Chapter three's last fight, in the lab's control hall:
## Echo catches every shockwave and gives it back, so the way in is through
## his own shots: reflect one into him, then strike while he is off balance.
## In the last phase the hall's gravity field switches on and off.

const Boss = preload("res://scripts/echo_boss.gd")
const LowGravity = preload("res://scripts/low_gravity.gd")
const SAFE_START := Vector2(150.0, 519.0)
const WAKE_X := 250.0
const ALERT := Color("#ffa583")
const GOLD := Color("#ffe09a")

var boss_name: String = Texts.BOSS_ECHO

@onready var boss: Boss = $World/EchoBoss
@onready var field: LowGravity = $World/Field
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		$FarBackground/Skyline.hide()
	super._ready()
	boss.player = sera
	boss.field = field
	field.target = sera
	_bind_weapon(boss)
	boss.echo_fired.connect(_on_echo_fired)
	boss.drank.connect(_on_drank)
	boss.staggered.connect(_on_staggered)
	boss.stomped.connect(_on_stomped)
	sera.forward_brace = true
	boss.go_dormant()
	_match_phase()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.ECHO_NOTE_WAKE, ALERT)
		_play(Audio.WAKE, -4.0)
		shake = maxf(shake, 5.0)
	if boss.slide_coming() and not sera.is_on_floor() and absf(boss.position.x - sera.position.x) < 70.0:
		learn(&"echo_slide")
	var returning := 0
	for shot in shots.get_children():
		if shot.get("returned") and signf(shot.velocity.x) == signf(boss.position.x - shot.global_position.x):
			returning += 1
	boss.returns_in_flight = returning


func _camera_goal(_point: Vector2) -> Vector2:
	return Vector2(576.0, 342.0)


func _update_backdrop() -> void:
	art.queue_redraw()


func _reset_room() -> void:
	boss.reset_attempt()
	boss.go_dormant()
	field.restart()
	_match_phase()


func _restore_room_progress() -> void:
	boss.health = Boss.HITS - checkpoint
	boss.reset_attempt()
	_match_phase()


## The gravity field only runs in the last phase.
func _match_phase() -> void:
	field.enabled = boss.health == 1
	field.visible = field.enabled
	if not field.enabled:
		sera.gravity_scale = 1.0


func _on_shot_absorbed(origin: Vector2, charge: int, precise: bool) -> void:
	super._on_shot_absorbed(origin, charge, precise)
	learn(&"echo_energy")


func _on_echo_fired(origin: Vector2, direction: float, heavy: bool) -> void:
	var shot := fire_shot(origin, direction, false, heavy, boss)
	shot.echo = true
	_play(Audio.SHOT, -4.0, 0.7 if heavy else 0.9)


func _on_drank(origin: Vector2) -> void:
	effects.catch_shot(origin, false)
	_play(Audio.HEAVY_CATCH, -4.0, 1.25)
	_show_feedback(Texts.ECHO_NOTE_ABSORBED, HEAT)


func _on_staggered(origin: Vector2) -> void:
	learn(&"echo_reflect")
	effects.impact(origin, true)
	effects.catch_shot(origin, true)
	_play(Audio.ARMOR, -2.0, 0.8)
	_show_feedback(Texts.ECHO_NOTE_STAGGER, GOLD)
	_hitstop(0.1, 10.0, 0.14, GOLD)


func _on_stomped(origin: Vector2, _hit_player: bool) -> void:
	effects.impact(origin, true)
	_play(Audio.IMPACT, -3.0, 0.8)
	shake = maxf(shake, 10.0)


func _resolve_stage_wave(next_distance: float) -> void:
	if boss.health <= 0 or boss in wave_hits or boss.dormant:
		return
	if not _wave_reaches(boss.chest_point(), 64.0, next_distance):
		return
	wave_hits.append(boss)
	if boss.take_wave():
		_strike()


func returned_hit(from: Vector2, to: Vector2, shot: Node2D) -> bool:
	if boss.health <= 0 or boss.dormant or not crosses(from, to, boss.chest_point(), Boss.HIT_RADIUS):
		return false
	match boss.take_returned(shot.heavy):
		"rally":
			effects.impact(to, false, false)
			_play(Audio.PRECISE_CATCH, -3.0, 0.8)
			_show_feedback(Texts.ECHO_NOTE_RALLY, HEAT)
		"absorb":
			effects.catch_shot(to, false)
			_play(Audio.HEAVY_CATCH, -5.0, 1.3)
	return true


func _strike() -> void:
	var point := boss.chest_point()
	learn(&"echo_strike")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.14, 13.0, 0.18, GOLD)
	for shot in shots.get_children():
		shot.queue_free()
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.ECHO_NOTE_STOPPED, ICE)
		field.enabled = false
		sera.gravity_scale = 1.0
		return
	_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
	_match_phase()
	var taunts: Array = Texts.ECHO_TAUNTS
	var line := Boss.HITS - boss.health - 1
	if line >= 0 and line < taunts.size():
		_show_feedback(taunts[line], ALERT)
		feedback_left = 3.4
	else:
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


func aim_marks() -> Array:
	return []


func aim_target() -> Vector2:
	return Vector2.INF


func aim_width() -> float:
	return Boss.HIT_RADIUS


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		if not knows(&"echo_start"):
			hints.append(hint(&"echo_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"echo_start")
	var chest := boss.chest_point() + Vector2(0.0, -70.0)
	if boss.is_open() and not knows(&"echo_strike"):
		if sera.energy >= Sera.RELEASE_COST:
			hints.append(hint(&"echo_strike", chest, spoken(Texts.ECHO_HINT_STRIKE, [["RMB"]]), GOLD))
		else:
			hints.append(hint(&"echo_energy", chest, spoken(Texts.ECHO_HINT_ENERGY, [["LMB"]])))
	elif boss.slide_coming() and not knows(&"echo_slide"):
		hints.append(hint(&"echo_slide", chest, spoken(Texts.ECHO_HINT_DASH), HEAT))
	elif boss.shot_coming() and sera.energy < Sera.RELEASE_COST and knows(&"echo_reflect") and not knows(&"echo_energy"):
		hints.append(hint(&"echo_energy", chest, spoken(Texts.ECHO_HINT_ENERGY, [["LMB"]])))
	elif boss.shot_coming() and not knows(&"echo_reflect"):
		hints.append(hint(&"echo_reflect", chest, spoken(Texts.ECHO_HINT_REFLECT, [["LMB", "+", "RMB"]]), GOLD))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_open():
		return [boss.chest_point() + Vector2(0.0, -60.0), Texts.MARK_OPEN_CORE, ICE]
	return []
