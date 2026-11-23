extends "res://scripts/stage.gd"

## Stage 3-6 · 시추 리그. The platform's drilling rig blocks the bridge to the
## lab. Its pod takes missiles reflected home, its dish drinks shockwaves and
## takes back the heavy shell it returns, and its drill slams the deck.

const Boss = preload("res://scripts/rig_boss.gd")
const Homing = preload("res://scripts/homing.gd")
const SAFE_START := Vector2(150.0, 519.0)
const WAKE_X := 250.0
const ALERT := Color("#ffa583")
const GOLD := Color("#ffe09a")

var boss_name: String = Texts.BOSS_RIG

@onready var boss: Boss = $World/RigBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		$FarBackground/Skyline.hide()
	super._ready()
	boss.player = sera
	_bind_weapon(boss)
	boss.missile_launched.connect(_on_missile_launched)
	boss.echo_fired.connect(_on_echo_fired)
	boss.drank.connect(_on_drank)
	boss.drill_struck.connect(_on_drill_struck)
	sera.forward_brace = true
	boss.go_dormant()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.RIG_NOTE_WAKE, ALERT)
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


func _on_missile_launched(origin: Vector2, pod: Node2D) -> void:
	var missile := Homing.new()
	missile.position = origin
	missile.player = sera
	missile.level = self
	missile.source = pod
	missile.velocity = Vector2(-0.5, -1.0).normalized() * Homing.SPEED
	missile.direction = -1.0
	missile.absorbed.connect(_on_missile_caught)
	missile.reflected.connect(_on_shot_reflected)
	missile.burst.connect(func(point: Vector2, _hit: bool): effects.impact(point, true))
	missile.tree_exited.connect(_on_missile_gone)
	boss.missiles_out += 1
	shots.add_child(missile)
	_play(Audio.LIFT, -6.0, 0.7)


func _on_missile_gone() -> void:
	if is_instance_valid(boss) and not boss.is_queued_for_deletion():
		boss.missiles_out = maxi(0, boss.missiles_out - 1)


func _on_missile_caught(origin: Vector2, charge: int, precise: bool) -> void:
	learn(&"rig_catch")
	caught_shots += 1
	if precise:
		perfect_shots += 1
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.5, 1.15)
	_hitstop(0.08, 7.0, 0.11, ICE)
	_show_feedback(Texts.SECTOR_NOTE_MISSILE + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_echo_fired(origin: Vector2, direction: float) -> void:
	var shot := fire_shot(origin, direction, false, true, boss)
	shot.echo = true
	_play(Audio.SHOT, -4.0, 0.7)


func _on_drank(origin: Vector2) -> void:
	learn(&"rig_drank")
	effects.catch_shot(origin, false)
	_play(Audio.HEAVY_CATCH, -4.0, 1.3)
	_show_feedback(Texts.RIG_NOTE_DRANK, HEAT)


func _on_drill_struck(x: float, hit_player: bool) -> void:
	effects.impact(Vector2(x, Boss.FLOOR_Y), true)
	_play(Audio.IMPACT, -3.0, 0.7)
	shake = maxf(shake, 10.0)
	if not hit_player:
		learn(&"rig_drill")


func _resolve_stage_wave(next_distance: float) -> void:
	if boss.health <= 0 or boss in wave_hits:
		return
	if _wave_reaches(Boss.DISH, 70.0, next_distance):
		wave_hits.append(boss)
		if not boss.drink():
			effects.impact(Boss.DISH, false)
			_play(Audio.ARMOR, -4.0)
			_show_feedback(Texts.SECTOR_NOTE_LAUNCHER_ARMOR, HEAT)
	elif _wave_reaches(Boss.POD, 60.0, next_distance):
		wave_hits.append(boss)
		boss.flash = 0.3
		effects.impact(Boss.POD, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.SECTOR_NOTE_LAUNCHER_ARMOR, HEAT)


## A missile reflected home can only find the pod; a heavy shell meets the dish
## first. Anything else that reaches the derrick sparks off it.
func returned_hit(from: Vector2, to: Vector2, shot: Node2D) -> bool:
	if boss.health <= 0:
		return false
	if not shot is Homing and crosses(from, to, Boss.DISH, Boss.DISH_RADIUS):
		_strike("dish", Boss.DISH)
		return true
	if crosses(from, to, Boss.POD, Boss.POD_RADIUS):
		_strike("pod", Boss.POD)
		return true
	if maxf(from.x, to.x) >= Boss.FACE_X + 40.0 and to.y > 40.0:
		effects.impact(to, false)
		_play(Audio.ARMOR, -5.0)
		return true
	return false


func _strike(part: String, point: Vector2) -> void:
	if not boss.hit(part):
		effects.impact(point, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.RIG_NOTE_POD_SHUT if part == "pod" else Texts.SECTOR_NOTE_LAUNCHER_ARMOR, HEAT)
		return
	learn(&"rig_pod" if part == "pod" else &"rig_dish")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.12, 12.0, 0.16, GOLD)
	for shot in shots.get_children():
		if shot is Homing:
			shot.queue_free()
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.RIG_NOTE_STOPPED, ICE)
	else:
		_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


func _nearest_missile() -> Homing:
	for shot in shots.get_children():
		if shot is Homing and not shot.returned:
			return shot
	return null


func aim_marks() -> Array:
	return []


func aim_target() -> Vector2:
	return Vector2.INF


func aim_width() -> float:
	return Boss.POD_RADIUS


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		if not knows(&"rig_start"):
			hints.append(hint(&"rig_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"rig_start")
	if boss.drill_threat() and not knows(&"rig_drill"):
		hints.append(hint(&"rig_drill", Vector2(boss.drill_x, Boss.FLOOR_Y - 60.0), spoken(Texts.RIG_HINT_DRILL), HEAT))
	var missile := _nearest_missile()
	if boss.pod_open() and missile != null and not knows(&"rig_pod"):
		hints.append(hint(&"rig_pod", missile.global_position, spoken(Texts.RIG_HINT_MISSILE, [["LMB", "+", "RMB"]]), GOLD))
	elif not boss.pod_open() and boss.dish_open() and not knows(&"rig_dish"):
		hints.append(hint(&"rig_dish", Boss.DISH, spoken(Texts.RIG_HINT_DISH, [["RMB"]]), GOLD))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	return []
