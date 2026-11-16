extends "res://scripts/stage.gd"

## Stage 9 · 대관성륜. The last fight, against the Foreman, in front of the
## great wheel. When the Foreman falls the wheel's momentum pours into the
## suit, and the stage ends when Sera sends it up the stack with one upward
## release: what she takes, she gives back.

const Boss = preload("res://scripts/foreman_boss.gd")
const SAFE_START := Vector2(240.0, 519.0)
const WAKE_X := 330.0
## Standing here lines the diagonal shot up with the shield relay.
const RELAY_AIM_X := 492.0
const ALERT := Color("#ffa583")

var boss_name: String = Texts.BOSS_FOREMAN
var finale := false

@onready var boss: Boss = $World/ForemanBoss
@onready var relay: Relay = $World/ShieldRelay
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	relays = [relay]
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		backdrop.modulate = Color(0.92, 0.93, 0.95)
	super._ready()
	sera.forward_brace = true
	boss.player = sera
	_bind_weapon(boss)
	boss.charge_prepared.connect(_play.bind(Audio.CHARGE_CUE, -4.0, 0.89))
	boss.charge_caught.connect(_on_charge_caught)
	boss.braked.connect(_on_boss_braked)
	boss.load_caught.connect(_on_load_caught)
	boss.load_crashed.connect(_on_load_crashed)
	relay.activated.connect(_on_shield_cut)
	boss.go_dormant()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.WHEEL_NOTE_WAKE, ALERT)
		_play(Audio.WAKE, -4.0)
		shake = maxf(shake, 5.0)
	# Loads from the wheel come from overhead; everything else comes from the front.
	sera.forward_brace = not boss.threatens_from_above()
	if finale:
		sera.energy = Sera.CAPACITY
		sera.invulnerable_left = maxf(sera.invulnerable_left, 0.5)
		shake = maxf(shake, 1.6)


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
	if checkpoint > 0:
		relay.energize(true)
	boss.shield_cut = relay.powered
	boss.reset_attempt()


func _on_shield_cut() -> void:
	learn(&"foreman_shield")
	boss.cut_shield()
	effects.catch_shot(relay.global_position, true)
	_show_feedback(Texts.WHEEL_NOTE_SHIELD_CUT, ICE)
	_play(Audio.RELAY, -3.0)
	_hitstop(0.063, 4.0, 0.07, ICE)


func _on_charge_caught(origin: Vector2, charge: int, precise: bool) -> void:
	learn(&"foreman_catch")
	caught_shots += 1
	if precise:
		perfect_shots += 1
	var message: String = Texts.WHEEL_NOTE_CHARGE_CAUGHT_PRECISE if precise else Texts.WHEEL_NOTE_CHARGE_CAUGHT
	if charge > 0:
		message += "  +%d" % charge
	_show_feedback(message, ICE)
	effects.catch_energy(origin)
	_play(Audio.PRECISE_CATCH if precise else Audio.HEAVY_CATCH, -1.5, 0.88)
	_hitstop(0.12, 11.0, 0.14, ICE)


func _on_boss_braked(origin: Vector2) -> void:
	effects.impact(origin, true)
	_play(Audio.IMPACT, -7.0, 0.82)
	shake = maxf(shake, 6.0)


func _on_load_caught(origin: Vector2, charge: int) -> void:
	learn(&"wheel_catch")
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0)
	_hitstop(0.076, 8.0, 0.12, ICE)
	_show_feedback(Texts.WHEEL_NOTE_LOAD_CAUGHT + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_load_crashed(point: Vector2, hit_player: bool) -> void:
	effects.impact(point, true)
	_play(Audio.IMPACT, -4.0, 0.90)
	shake = maxf(shake, 9.0)
	if boss.heavy and not hit_player:
		learn(&"wheel_dodge")


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
		_show_feedback(Texts.NOTE_SHIELDED if boss.is_shielded() else Texts.WHEEL_NOTE_CORE_SHUT, HEAT)
		return
	learn(&"foreman_core")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.115, 12.0, 0.15, ICE)
	if boss.health == 0:
		_begin_finale()
	else:
		_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


## The Foreman is down. The wheel empties into the suit until Sera releases it upward.
func _begin_finale() -> void:
	finale = true
	for shot in shots.get_children():
		shot.queue_free()
	sera.energy = Sera.CAPACITY
	_show_feedback(Texts.WHEEL_NOTE_FINALE, ICE)
	create_tween().tween_property(room_tone, "pitch_scale", 1.22, 0.34)
	shake = maxf(shake, 12.0)


func _on_release(origin: Vector2, direction: Vector2) -> void:
	super._on_release(origin, direction)
	if not finale or complete:
		return
	if direction.y < 0.0:
		effects.catch_energy(origin)
		_hitstop(0.16, 14.0, 0.3, ICE)
		create_tween().tween_property(room_tone, "pitch_scale", 0.74, 0.59)
		_finish_stage(Audio.WHEEL_RELEASE)
		_show_feedback(Texts.WHEEL_NOTE_RELEASED, ICE)
	else:
		_show_feedback(Texts.WHEEL_NOTE_WRONG_WAY, HEAT)


func aim_marks() -> Array:
	if boss.is_shielded():
		return [Vector2(RELAY_AIM_X, 520.0)]
	if boss.state == Boss.State.OPEN:
		return [Vector2(Boss.PERCH_AIM_X, 520.0)]
	return []


func aim_target() -> Vector2:
	if boss.is_shielded():
		return relay.position
	if boss.state == Boss.State.OPEN:
		return boss.core_point()
	return Vector2.INF


func aim_width() -> float:
	return relay.HIT_RADIUS if boss.is_shielded() else Boss.CORE_WIDTH


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if finale:
		hints.append(hint(&"finale", Vector2.INF, spoken(Texts.WHEEL_HINT_FINALE, [["W", "+", "RMB"]])))
		return hints
	if boss.dormant:
		if not knows(&"wheel_start"):
			hints.append(hint(&"wheel_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"wheel_start")
	match boss.health:
		3:
			if boss.is_shielded() and sera.energy >= Sera.RELEASE_COST and not knows(&"foreman_shield"):
				hints.append(hint(&"foreman_shield", relay.global_position,
					spoken(Texts.WHEEL_HINT_SHIELD, [["W", "+", "RMB"]]), HEAT))
			elif not boss.is_shielded() and sera.energy >= Sera.RELEASE_COST and not knows(&"foreman_core"):
				hints.append(hint(&"foreman_core", boss.core_point(), spoken(Texts.WHEEL_HINT_CORE, [["RMB"]])))
		2:
			if boss.is_charging() and not knows(&"foreman_catch"):
				hints.append(hint(&"foreman_catch", Vector2(boss.x, 300.0),
					spoken(Texts.WHEEL_HINT_CATCH, [["LMB"]]), HEAT))
			elif boss.state == Boss.State.STUN and sera.energy >= Sera.RELEASE_COST:
				hints.append(hint(&"foreman_stun", boss.core_point(), spoken(Texts.WHEEL_HINT_STUN, [["RMB"]])))
		1:
			var column := Vector2(boss.drop_x, 330.0)
			if boss.threatens_from_above() and boss.heavy and not knows(&"wheel_dodge"):
				hints.append(hint(&"wheel_dodge", column, spoken(Texts.WHEEL_HINT_DODGE), HEAT))
			elif boss.threatens_from_above() and not boss.heavy and not knows(&"wheel_catch"):
				hints.append(hint(&"wheel_catch", column, spoken(Texts.WHEEL_HINT_LOAD, [["LMB"]])))
			elif boss.state == Boss.State.OPEN:
				hints.append(hint(&"wheel_core", boss.core_point(),
					spoken(Texts.WHEEL_HINT_PERCH_CORE, [["W", "+", "RMB"]])))
	return hints


func hud_marker() -> Array:
	if finale:
		return []
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_shielded() and sera.energy >= Sera.RELEASE_COST:
		return [relay.position + Vector2(0.0, -44.0), Texts.MARK_SHIELD_RELAY, HEAT]
	if boss.state == Boss.State.OPEN:
		return [Vector2(Boss.PERCH_AIM_X, 490.0), Texts.MARK_AIM, ICE]
	if boss.health == 3 and boss.is_open():
		return [boss.core_point() + Vector2(0.0, -45.0), Texts.MARK_OPEN_CORE, ICE]
	return []
