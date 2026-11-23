extends "res://scripts/stage.gd"

## Stage 3-3 · 키잡이. The ship's foredeck in a storm, under the mirrored
## bridge. Shockwaves come back off the glass; the helm core only takes the
## bridge's own bolts, reflected while its port is open. The deck rolls and
## lashed barrels break loose with every lean, as on the deck before.

const Boss = preload("res://scripts/helmsman_boss.gd")
const ShipSway = preload("res://scripts/ship_sway.gd")
const BarrelRack = preload("res://scripts/barrel_rack.gd")
const SAFE_START := Vector2(150.0, 519.0)
const WAKE_X := 250.0
const ALERT := Color("#ffa583")
const GOLD := Color("#ffe09a")

var boss_name: String = Texts.BOSS_HELMSMAN

@onready var boss: Boss = $World/HelmsmanBoss
@onready var art: Node2D = $World/DeckArt
@onready var backdrop: Sprite2D = $FarBackground/Backdrop
@onready var sway: ShipSway = $World/Swell
@onready var rack: BarrelRack = $World/Rack


func _ready() -> void:
	var index := CampaignStore.SCENES.find(scene_file_path)
	if index >= 0 and CampaignStore.has_own_art(index):
		backdrop.texture = CampaignStore.stage_art(index)
		$FarBackground/Skyline.hide()
	super._ready()
	_bind_weapon(boss)
	sway.target = sera
	sway.leaning.connect(_on_ship_leaning)
	sway.warned.connect(func(_side: float): _play(Audio.IMPACT, -12.0, 0.55))
	rack.target = sera
	rack.sway = sway
	rack.caught.connect(_on_barrel_caught)
	rack.smashed.connect(_on_barrel_smashed)
	camera.ignore_rotation = false
	sera.forward_brace = true
	boss.go_dormant()


func _process(delta: float) -> void:
	super._process(delta)
	camera.rotation = sway.roll()


func _update_progress() -> void:
	if boss.dormant and sera.position.x >= WAKE_X and boss.wake():
		_show_feedback(Texts.HELM_NOTE_WAKE, ALERT)
		_play(Audio.WAKE, -4.0)
		shake = maxf(shake, 5.0)


func _camera_goal(_point: Vector2) -> Vector2:
	return Vector2(576.0, 342.0)


func _update_backdrop() -> void:
	art.queue_redraw()


func _reset_room() -> void:
	boss.reset_attempt()
	boss.go_dormant()
	sway.restart()
	rack.restart()


func _restore_room_progress() -> void:
	boss.health = Boss.HITS - checkpoint
	boss.reset_attempt()


## A shockwave that reaches the bridge glass comes straight back at Sera.
func _resolve_stage_wave(next_distance: float) -> void:
	if boss.health <= 0 or boss in wave_hits:
		return
	for point in [Boss.LOW_CORE, Boss.HIGH_CORE]:
		if _wave_reaches(point, 60.0, next_distance):
			wave_hits.append(boss)
			boss.flash_mirror()
			var shot := fire_shot(Vector2(Boss.FACE_X - 40.0, wave_origin.y), -1.0, false, false, boss)
			shot.echo = true
			effects.impact(Vector2(Boss.FACE_X - 30.0, wave_origin.y), false, false)
			_play(Audio.ARMOR, -3.0, 1.35)
			_show_feedback(Texts.HELM_NOTE_MIRROR, HEAT)
			return
	for barrel: Dictionary in rack.barrels.duplicate():
		if barrel["fall"] == 0.0 and _wave_reaches(rack.barrel_point(barrel), 46.0, next_distance):
			rack.smash(barrel)


## Reflected bolts: into the open core they count; anywhere else on the bridge
## face they only spark.
func returned_hit(from: Vector2, to: Vector2, _shot: Node2D) -> bool:
	if boss.health <= 0:
		return false
	if crosses(from, to, boss.core_point(), Boss.CORE_RADIUS):
		_strike()
		return true
	var other := Boss.LOW_CORE if boss.high else Boss.HIGH_CORE
	if crosses(from, to, other, Boss.CORE_RADIUS) or (maxf(from.x, to.x) >= Boss.FACE_X and to.y > 110.0):
		effects.impact(Vector2(minf(to.x, Boss.FACE_X), to.y), false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.HELM_NOTE_ARMOR, HEAT)
		return true
	return false


func _strike() -> void:
	var point := boss.core_point()
	if not boss.hit_core():
		effects.impact(point, false)
		_play(Audio.ARMOR, -4.0)
		_show_feedback(Texts.HELM_NOTE_SHUT, HEAT)
		return
	learn(&"helm_core")
	if boss.health <= 1:
		learn(&"helm_high")
	effects.catch_energy(point)
	effects.impact(point, true)
	_play(Audio.CORE_BREAK, -3.0)
	_hitstop(0.12, 12.0, 0.16, GOLD)
	if boss.health == 0:
		_finish_stage()
		_show_feedback(Texts.HELM_NOTE_STOPPED, ICE)
		sway.set_physics_process(false)
	else:
		_reach_checkpoint(Boss.HITS - boss.health, SAFE_START)
		_show_feedback(Texts.NOTE_CORE_DAMAGED, ICE)


func _on_ship_leaning(side: float) -> void:
	rack.let_go(side)
	shake = maxf(shake, 3.0)


func _on_barrel_caught(origin: Vector2, charge: int, precise: bool) -> void:
	caught_shots += 1
	if precise:
		perfect_shots += 1
	effects.catch_energy(origin)
	_play(Audio.HEAVY_CATCH, -2.0, 0.95)
	_hitstop(0.07, 8.0, 0.12, ICE)
	_show_feedback(Texts.SECTOR_NOTE_BARREL + ("  +%d" % charge if charge > 0 else ""), ICE)


func _on_barrel_smashed(origin: Vector2, _hit_player: bool) -> void:
	effects.impact(origin, true)
	_play(Audio.IMPACT, -6.0, 0.9)


func aim_marks() -> Array:
	return boss.aim_marks()


func aim_target() -> Vector2:
	return boss.core_point() if boss.high and boss.is_open() else Vector2.INF


func aim_width() -> float:
	return Boss.CORE_RADIUS


func hud_section() -> String:
	return boss_label(boss_name)


func stage_hints() -> Array:
	var hints := []
	if boss.dormant:
		if not knows(&"helm_start"):
			hints.append(hint(&"helm_start", Vector2.INF, spoken([story(0)])))
		return hints
	learn(&"helm_start")
	var keys := [["LMB", "+", "RMB"]]
	if boss.high and not knows(&"helm_high"):
		hints.append(hint(&"helm_high", Vector2(Boss.AIM_X, Boss.FLOOR_Y - 20.0),
			spoken(Texts.HELM_HINT_HIGH, [["LMB", "+", "W", "+", "RMB"]]), GOLD))
	elif not boss.high and not knows(&"helm_core"):
		hints.append(hint(&"helm_core", boss.core_point(), spoken(Texts.HELM_HINT_REFLECT, keys), GOLD))
	return hints


func hud_marker() -> Array:
	if boss.dormant:
		return [Vector2(WAKE_X + 40.0, 470.0), Texts.MARK_BOSS_WAKE, ALERT]
	if boss.high and boss.health > 0:
		return [Vector2(Boss.AIM_X, Boss.FLOOR_Y - 30.0), Texts.MARK_AIM, GOLD]
	return []
