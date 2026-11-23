extends "res://scripts/stage.gd"

## Stage 2-9 · 디스패처. Chapter two's last boss, on the pier at the top of the
## harbour tower. Its first phase is the train's lesson (catch a heavy shell in
## the air, then a diagonal shot from a floor mark), its second the carrier's
## (catch a blue container, bounce up, strike the roof from above) with the wind
## blowing, and its last alternates the two while the wind keeps changing.

const Boss = preload("res://scripts/dispatcher_boss.gd")
const Gust = preload("res://scripts/gust.gd")
const SAFE_START := Vector2(150.0, 519.0)
const WAKE_X := 250.0
const ALERT := Color("#ffa583")

var boss_name: String = Texts.BOSS_DISPATCHER

@onready var boss: Boss = $World/DispatcherBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop
@onready var wind: Gust = $World/SeaWind


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		$FarBackground/Skyline.hide()
	super._ready()
	boss.player = sera
	_bind_weapon(boss)
	boss.heavy_fired.connect(_on_heavy_fired)
	boss.load_caught.connect(_on_load_caught)
	boss.load_crashed.connect(_on_load_crashed)
	boss.jolted.connect(_on_jolted)
	boss.mode_changed.connect(_on_mode_changed)
	wind.target = sera
	boss.go_dormant()
	_match_mode()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.DISPATCHER_NOTE_WAKE, ALERT)
		_play(Audio.WAKE, -4.0)
		shake = maxf(shake, 5.0)


func _camera_goal(_point: Vector2) -> Vector2:
	return Vector2(576.0, 342.0)


func _update_backdrop() -> void:
	art.queue_redraw()


func _reset_room() -> void:
	boss.reset_attempt()
	boss.go_dormant()
	_match_mode()


func _restore_room_progress() -> void:
	boss.health = Boss.HITS - checkpoint
	boss.reset_attempt()
	_match_mode()


## Sera braces forward for shells and overhead for containers; the wind starts
## in the second phase and turns around with every change in the last.
func _match_mode() -> void:
	sera.forward_brace = boss.mode == Boss.Mode.SIGNAL
	var push := 0.0
	if boss.health == 2:
		push = 200.0
	elif boss.health == 1:
		push = 230.0 if boss.mode == Boss.Mode.SIGNAL else -230.0
	wind.push = push
	wind.visible = push != 0.0
	wind.set_physics_process(push != 0.0)


func _on_mode_changed() -> void:
	_match_mode()
	if boss.health == 1:
		_show_feedback(Texts.DISPATCHER_NOTE_WIND, ALERT)


func _on_heavy_fired(origin: Vector2, direction: float) -> void:
	var shot := Incoming.new()
	shot.position = origin
	shot.player = sera
	shot.direction = direction
	shot.heavy = true
	shot.absorbed.connect(_on_shell_caught)
	shots.add_child(shot)
	_play(Audio.SHOT, -4.0, 0.72)


func _on_shell_caught(origin: Vector2, charge: int, precise: bool) -> void:
	caught_shots += 1
	if precise:
		perfect_shots += 1
	learn(&"air_catch")
	learn(&"dispatcher_shell")
	boss.catch_shell()
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0, 0.9)
	_hitstop(0.11, 9.0, 0.14, ICE)
	_show_feedback(Texts.DISPATCHER_NOTE_SHELL + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_load_caught(origin: Vector2, charge: int) -> void:
	learn(&"dispatcher_catch")
	caught_shots += 1
	sera.energy = Sera.CAPACITY
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0)
	_hitstop(0.076, 8.0, 0.12, ICE)
	_show_feedback(Texts.DISPATCHER_NOTE_CAUGHT + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_load_crashed(point: Vector2, hit_player: bool) -> void:
	effects.impact(point, true)
	_play(Audio.IMPACT, -4.0, 0.88)
	shake = maxf(shake, 9.0)
	if boss.heavy and not hit_player:
		learn(&"dispatcher_dodge")
		_show_feedback(Texts.CARRIER_NOTE_SLAB_EVADED, ICE)


func _on_jolted() -> void:
	_show_feedback(Texts.CARRIER_NOTE_SHAKEN, HEAT)
	_play(Audio.IMPACT, -6.0, 0.7)
	shake = maxf(shake, 7.0)


func _on_release(origin: Vector2, direction: Vector2) -> void:
	super._on_release(origin, direction)
	if direction.y > 0.5 and boss.health > 0 and boss.stomp_reaches(sera):
		_strike(true)


func _resolve_stage_wave(next_distance: float) -> void:
	if boss.health <= 0 or boss.mode != Boss.Mode.SIGNAL or boss in wave_hits:
		return
	if _wave_reaches(boss.core_point(), Boss.CORE_WIDTH, next_distance):
		_strike(false)


func _strike(from_above: bool) -> void:
	if boss in wave_hits:
		return
	wave_hits.append(boss)
	var point := boss.core_point()
	if not boss.hit_core(from_above):
		effects.impact(point, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.DISPATCHER_NOTE_SHIELDED if boss.mode == Boss.Mode.SIGNAL else Texts.DISPATCHER_NOTE_ROOF_SHUT, HEAT)
		return
	learn(&"dispatcher_core")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.12, 12.0, 0.16, ICE)
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.DISPATCHER_NOTE_STOPPED, ICE)
		wind.set_physics_process(false)
	else:
		_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)
		_match_mode()


func aim_marks() -> Array:
	return boss.aim_marks()


func aim_target() -> Vector2:
	return boss.core_point() if boss.is_open() and boss.mode == Boss.Mode.SIGNAL else Vector2.INF


func aim_width() -> float:
	return Boss.CORE_WIDTH


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		if not knows(&"dispatcher_start"):
			hints.append(hint(&"dispatcher_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"dispatcher_start")
	if boss.mode == Boss.Mode.SIGNAL:
		if boss.shell_coming() and not knows(&"dispatcher_shell"):
			hints.append(hint(&"dispatcher_shell", boss.mast_point(boss.mast),
				spoken(Texts.DISPATCHER_HINT_SHELL, [["Space", "+", "LMB"]])))
		elif boss.is_open() and not knows(&"dispatcher_core"):
			hints.append(hint(&"dispatcher_core", boss.core_point(), spoken(Texts.DISPATCHER_HINT_CORE, [["W", "+", "RMB"]])))
	else:
		var under := Vector2(boss.cx, 420.0)
		if boss.threatens_from_above() and boss.heavy and not knows(&"dispatcher_dodge"):
			hints.append(hint(&"dispatcher_dodge", under, spoken(Texts.CARRIER_HINT_DODGE), HEAT))
		elif boss.threatens_from_above() and not boss.heavy and not knows(&"dispatcher_catch"):
			hints.append(hint(&"dispatcher_catch", under, spoken(Texts.DISPATCHER_HINT_CATCH, [["LMB"]])))
		elif boss.is_open() and not knows(&"dispatcher_stomp"):
			hints.append(hint(&"dispatcher_stomp", boss.core_point(), spoken(Texts.DISPATCHER_HINT_STOMP, [["S", "+", "RMB"]])))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.is_open():
		if boss.mode == Boss.Mode.SIGNAL:
			var marks := boss.aim_marks()
			var nearest: Vector2 = marks[0] if absf(marks[0].x - sera.position.x) < absf(marks[1].x - sera.position.x) else marks[1]
			return [nearest + Vector2(0.0, -30.0), Texts.MARK_AIM, ICE]
		return [boss.core_point() + Vector2(0.0, -40.0), Texts.MARK_OPEN_CORE, ICE]
	return []
