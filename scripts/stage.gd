extends Node2D

const CampaignStore = preload("res://scripts/campaign.gd")
const Texts = preload("res://texts.gd")
const Sera = preload("res://scripts/sera.gd")
const Guard = preload("res://scripts/warden.gd")
const Incoming = preload("res://scripts/incoming.gd")
const Bulkhead = preload("res://scripts/bulkhead.gd")
const Relay = preload("res://scripts/kinetic_relay.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const ExitPortal = preload("res://scripts/exit_portal.gd")
const Audio = preload("res://scripts/game_audio.gd")
const EXIT_REACH := 64.0
const WAVE_RANGE := 326.0
const WAVE_SPEED := 1520.0
const ICE := Color("#76e4ff")
const HEAT := Color("#ffa475")

@export_file("*.tscn") var next_scene := ""
## Words for the result screen. A stage in the campaign list takes these from
## texts.gd; the exported values only matter for a scene outside that list.
@export var continue_caption := ""
@export var clear_title := ""
## One line of story shown under the clear title on the result screen.
@export var clear_note := ""
@export var carry_charge := false
@export var horizontal_bounds := Vector2(-70.0, 4360.0)
@export var fall_limit := 813.0

var guards: Array[Guard] = []
var relays: Array[Relay] = []
var complete := false
var entry_charge := 0
var play_mode: CampaignStore.Mode = CampaignStore.Mode.DIRECT
var initial_checkpoint: Dictionary = {}
var clear_charge := 0
var new_record := false
var checkpoint := 0
var checkpoint_position := Vector2.ZERO
var checkpoint_charge := 0
var retries := 0
var caught_shots := 0
var perfect_shots := 0
var elapsed := 0.0
var practice_splits_ms := CampaignStore.EMPTY_PRACTICE_SPLITS.duplicate()
var practice_previous_ms := CampaignStore.EMPTY_PRACTICE_SPLITS.duplicate()
var evade_count := 0
var flash := 0.0
var flash_tint := ICE
var feedback := ""
var feedback_tint := ICE
var feedback_left := 0.0

var freeze_left := 0.0
var shake := 0.0
var clock := 0.0
var ghost_left := 0.0
var retry_left := 0.0
var scene_changing := false
var player_paused := false
var ignore_resume_input := false
var pause_menu: PauseMenu
var spawn_point := Vector2.ZERO
var exit_portal: ExitPortal
var exiting := false
var room_tone: AudioStreamPlayer
var sound_voices: Array[AudioStreamPlayer]

var wave_origin := Vector2.ZERO
var wave_direction := Vector2.RIGHT
var wave_distance := 0.0
var wave_limit := WAVE_RANGE
var wave_active := false
var wave_hits: Array[Node2D] = []

@onready var campaign: CampaignStore = get_node("/root/Campaign")
@onready var sera: Sera = $World/Sera
@onready var effects = $World/Effects
@onready var shots: Node2D = $World/Projectiles
@onready var camera: Camera2D = $Camera2D
@onready var sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	_use_campaign_text()
	sound_voices = Audio.prepare(sound, &"Effects", 12)
	room_tone = Audio.start_room(self, Audio.stage_room(stage_number()), -3.5)
	checkpoint_position = sera.global_position
	checkpoint_charge = entry_charge
	sera.energy = entry_charge
	if play_mode == CampaignStore.Mode.PRACTICE and stage_number() >= 0:
		practice_previous_ms = campaign.practice_splits(stage_number())
	for guard in guards:
		guard.target = sera
		_bind_weapon(guard)
		guard.crashed.connect(_on_warden_crash)
	sera.boost_started.connect(_on_boost)
	sera.shockwave.connect(_on_release)
	sera.landed.connect(_on_land)
	sera.injured.connect(_on_player_hit)
	sera.action_denied.connect(_play.bind(Audio.EMPTY, -8.0))
	camera.make_current()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resumed.connect(_set_player_pause.bind(false))
	pause_menu.retried.connect(_retry_from_menu)
	pause_menu.title_requested.connect(_leave_stage)
	if not initial_checkpoint.is_empty():
		_restore_checkpoint(initial_checkpoint)
	spawn_point = sera.global_position
	var exit_spot := _exit_spot()
	if exit_spot.is_finite():
		exit_portal = ExitPortal.new()
		exit_portal.position = exit_spot
		sera.get_parent().add_child(exit_portal)
		sera.get_parent().move_child(exit_portal, sera.get_index())
	_save_progress()


func _exit_tree() -> void:
	Audio.stop_players(self)


## This stage's place in the campaign list, or -1 for a scene outside it.
func stage_number() -> int:
	return CampaignStore.SCENES.find(scene_file_path)


func _use_campaign_text() -> void:
	var index := stage_number()
	if index >= 0:
		var words := Texts.stage(index)
		clear_title = words["clear_title"]
		clear_note = words["clear_note"]
	var following := CampaignStore.SCENES.find(next_scene)
	if following >= 0:
		continue_caption = Texts.toward(Texts.stage_name(following))


## "스테이지  /  구간" for the top-left plate.
func stage_label(part: int) -> String:
	return "%s  /  %s" % [Texts.stage_name(stage_number()), Texts.section(stage_number(), part)]


## "스테이지  /  보스" for a boss stage.
func boss_label(boss: String) -> String:
	return "%s  /  %s" % [Texts.stage_name(stage_number()), boss]


## One of this stage's story lines from texts.gd.
func story(line: int) -> String:
	return Texts.say(stage_number(), line)


## Rows for hint(): the first of `words` is what Sera says; each later line
## follows the input tokens given for it in `keys`.
func spoken(words: Array, keys: Array = []) -> Array:
	var rows := []
	for i in words.size():
		rows.append([keys[i - 1] if i > 0 and i - 1 < keys.size() else [], words[i]])
	return rows


func _bind_weapon(weapon) -> void:
	weapon.attack_prepared.connect(_on_enemy_warning)
	weapon.attack_fired.connect(_on_enemy_fire)


func _process(delta: float) -> void:
	if player_paused:
		return
	clock += delta
	if not complete:
		elapsed += delta
	feedback_left = maxf(0.0, feedback_left - delta)
	if freeze_left > 0.0:
		freeze_left = maxf(0.0, freeze_left - delta)
		if freeze_left == 0.0:
			get_tree().paused = false
	else:
		flash = move_toward(flash, 0.0, 2.25 * delta)
	shake = move_toward(shake, 0.0, delta * 29.0)
	var target := _camera_goal(sera.position)
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 5.6))
	camera.offset = Vector2(sin(clock * 109.0), cos(clock * 142.0) * 0.57) * shake
	_update_backdrop()


func _physics_process(delta: float) -> void:
	if scene_changing or player_paused:
		return
	if ignore_resume_input:
		ignore_resume_input = false
		return
	if Input.is_action_just_pressed(&"restart"):
		var mode := CampaignStore.Mode.PRACTICE if complete and play_mode == CampaignStore.Mode.CAMPAIGN else play_mode
		_queue_stage(scene_file_path, entry_charge, mode)
		return
	if complete and not next_scene.is_empty() and Input.is_action_just_pressed(&"continue_stage"):
		if play_mode == CampaignStore.Mode.PRACTICE or (play_mode == CampaignStore.Mode.CAMPAIGN and campaign.stage_index(scene_file_path) == CampaignStore.SCENES.size() - 1):
			_leave_stage()
		else:
			_queue_stage(next_scene, clear_charge, play_mode)
		return
	if exiting:
		return
	sera.read_input()
	if freeze_left > 0.0:
		return
	if sera.position.y > fall_limit:
		_respawn()
		return
	if sera.integrity <= 0:
		retry_left -= delta
		if retry_left <= 0.0:
			_respawn()
		return

	sera.position.x = clampf(sera.position.x, horizontal_bounds.x, horizontal_bounds.y)
	if not knows(&"move") and sera.global_position.distance_to(spawn_point) > 90.0:
		learn(&"move")
	_update_progress()
	if exit_portal:
		exit_portal.open = _exit_ready()
		exit_portal.near = exit_portal.open and near_exit()
		if exit_portal.near and Input.is_action_just_pressed(&"interact"):
			_enter_exit()
			return
	if wave_active:
		_advance_wave(delta)
	ghost_left -= delta
	if sera.state == Sera.State.BOOST and ghost_left <= 0.0:
		ghost_left = 0.035
		var sprite := sera.sprite
		effects.afterimage(sera.global_position, sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame), sera.facing)


## Where this stage's exit portal stands, or a non-finite vector for none.
func _exit_spot() -> Vector2:
	return Vector2.INF


func _exit_ready() -> bool:
	return false


func near_exit() -> bool:
	if exit_portal == null or not sera.is_on_floor():
		return false
	var gap := sera.global_position - exit_portal.global_position
	return absf(gap.x) < EXIT_REACH and absf(gap.y) < 40.0


func _enter_exit() -> void:
	exiting = true
	sera.invulnerable_left = 10.0
	sera.velocity = Vector2.ZERO
	sera.set_physics_process(false)
	_play(Audio.RELAY, -6.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sera, "global_position:x", exit_portal.global_position.x, 0.32).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sera, "modulate", Color(2.2, 2.6, 2.8, 0.0), 0.5).set_delay(0.12)
	tween.tween_property(exit_portal, "swallow", 1.0, 0.2).set_delay(0.3)
	tween.chain().tween_property(exit_portal, "swallow", 0.0, 0.3)
	tween.chain().tween_callback(_finish_stage)


func _queue_stage(scene_path: String, charge: int, mode: CampaignStore.Mode) -> void:
	scene_changing = true
	_switch_stage.call_deferred(scene_path, charge, mode)


func _switch_stage(scene_path: String, charge: int, mode: CampaignStore.Mode) -> void:
	var index := campaign.stage_index(scene_path)
	await Audio.drain(self)
	var result := campaign.open_stage(index, mode, campaign.entry_snapshot(index, charge))
	if result != OK:
		scene_changing = false
		if not complete:
			Audio.resume_rooms(self, player_paused)
		push_error("Could not switch stage: " + error_string(result))


func _input(event: InputEvent) -> void:
	if not scene_changing and event.is_action_pressed(&"pause_menu") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_set_player_pause(not player_paused)


func _set_player_pause(value: bool) -> void:
	player_paused = value
	get_tree().paused = value or freeze_left > 0.0
	for voice in sound_voices:
		voice.stream_paused = value
	room_tone.stream_paused = value
	if value:
		var heading: String = call(&"hud_section") if has_method(&"hud_section") else ""
		var detail := Texts.PAUSE_DETAIL.format({"시간": campaign.time_label(roundi(elapsed * 1000.0)), "정밀": perfect_shots, "재시도": retries})
		pause_menu.open_menu(not complete, play_mode == CampaignStore.Mode.CAMPAIGN, heading, detail)
	else:
		ignore_resume_input = true
		pause_menu.close_menu()


func _retry_from_menu() -> void:
	if not complete:
		_set_player_pause(false)
		_respawn()


func _leave_stage() -> void:
	if scene_changing:
		return
	_save_progress()
	scene_changing = true
	_switch_to_title.call_deferred()


func _switch_to_title() -> void:
	var tree := get_tree()
	await Audio.drain(self)
	var result := tree.change_scene_to_file(CampaignStore.TITLE)
	if result == OK:
		tree.paused = false
	else:
		scene_changing = false
		if not complete:
			Audio.resume_rooms(self, player_paused)
		push_error("Could not load the title screen: " + error_string(result))


func result_action_label() -> String:
	if play_mode == CampaignStore.Mode.PRACTICE or (play_mode == CampaignStore.Mode.CAMPAIGN and campaign.stage_index(scene_file_path) == CampaignStore.SCENES.size() - 1):
		return Texts.CLEAR_TO_TITLE
	return continue_caption


func _save_progress() -> void:
	if play_mode != CampaignStore.Mode.CAMPAIGN or complete:
		return
	var progress := campaign.entry_snapshot(campaign.stage_index(scene_file_path), entry_charge)
	progress["checkpoint"] = checkpoint
	progress["charge"] = checkpoint_charge
	progress["elapsed_ms"] = roundi(elapsed * 1000.0)
	progress["perfect"] = perfect_shots
	progress["retries"] = retries
	for i in guards.size():
		if guards[i].knocked_out:
			progress["guards"] |= 1 << i
	for i in relays.size():
		if relays[i].powered:
			progress["relays"] |= 1 << i
	if campaign.save_checkpoint(progress) != OK:
		_show_feedback(Texts.NOTE_SAVE_FAILED, HEAT)


func _restore_checkpoint(progress: Dictionary) -> void:
	checkpoint = progress["checkpoint"]
	checkpoint_position = _saved_spawn(checkpoint)
	checkpoint_charge = progress["charge"]
	sera.energy = checkpoint_charge
	elapsed = progress["elapsed_ms"] / 1000.0
	perfect_shots = progress["perfect"]
	retries = progress["retries"]
	for i in guards.size():
		if int(progress["guards"]) & (1 << i):
			guards[i].restore_defeated()
	for i in relays.size():
		if int(progress["relays"]) & (1 << i):
			relays[i].energize(true)
	_restore_room_progress()
	if checkpoint > 0 or progress["guards"] > 0 or progress["relays"] > 0:
		sera.reset_at(checkpoint_position, checkpoint_charge)
		camera.position = _camera_goal(sera.position)


func _saved_spawn(_index: int) -> Vector2:
	return checkpoint_position


func _restore_room_progress() -> void:
	pass


func _reach_checkpoint(index: int, point: Vector2) -> void:
	checkpoint = index
	checkpoint_position = point
	checkpoint_charge = sera.energy
	sera.integrity = Sera.MAX_INTEGRITY
	_show_feedback(Texts.NOTE_CHECKPOINT, ICE)
	if play_mode == CampaignStore.Mode.PRACTICE and index > 0 and index < practice_splits_ms.size():
		var segment := index - 1
		if practice_splits_ms[segment] == 0:
			practice_splits_ms[segment] = clampi(roundi(elapsed * 1000.0), 1, CampaignStore.MAX_RECORD_MS)
			var time := CampaignStore.practice_segment_ms(practice_splits_ms, segment)
			var best := CampaignStore.practice_segment_ms(practice_previous_ms, segment)
			if time >= 0 and best >= 0:
				_show_feedback(Texts.NOTE_PRACTICE_SPLIT.format({"구간": index,
					"차이": CampaignStore.practice_delta_label(time - best)}), ICE if time <= best else HEAT)
	_play(Audio.CHECKPOINT, -5.0)
	_save_progress()


func _finish_stage(cue: AudioStream = Audio.CLEAR) -> void:
	if complete:
		return
	complete = true
	clear_charge = sera.energy if carry_charge else 0
	Audio.play_cue(sound_voices, cue, -3.0)
	var fade := create_tween()
	fade.tween_property(room_tone, "volume_db", -50.0, 0.60)
	fade.tween_callback(room_tone.stop)
	var index := stage_number()
	if index < 0:
		return
	var time_ms := clampi(roundi(elapsed * 1000.0), 1, CampaignStore.MAX_RECORD_MS)
	if play_mode == CampaignStore.Mode.CAMPAIGN:
		var previous := campaign.best_ms(index)
		new_record = previous > 0 and time_ms < previous
		if campaign.finish(index, elapsed, clear_charge) != OK:
			_show_feedback(Texts.NOTE_RECORD_FAILED, HEAT)
	elif play_mode == CampaignStore.Mode.PRACTICE:
		practice_splits_ms[-1] = time_ms
		if practice_previous_ms[-1] == 0 or time_ms < practice_previous_ms[-1]:
			new_record = campaign.finish_practice(index, practice_splits_ms) == OK
			if not new_record:
				_show_feedback(Texts.NOTE_RECORD_FAILED, HEAT)


func _respawn() -> void:
	retries += 1
	retry_left = 0.0
	freeze_left = 0.0
	get_tree().paused = false
	flash = 0.0
	shake = 0.0
	wave_active = false
	wave_hits.clear()
	for voice in sound_voices:
		voice.stop()
	_play(Audio.CHECKPOINT, -10.0, 0.78)
	for shot in shots.get_children():
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		shot.queue_free()
	for guard in guards:
		if not guard.knocked_out:
			guard.reset_guard()
	_reset_room()
	effects.clear()
	sera.reset_at(checkpoint_position, checkpoint_charge)
	camera.position = _camera_goal(sera.position)
	camera.offset = Vector2.ZERO
	_show_feedback(Texts.NOTE_RESTART_CHECKPOINT if checkpoint > 0 else Texts.NOTE_RESTART_ENTRANCE, ICE)
	_save_progress()


func _advance_wave(delta: float) -> void:
	var next_distance := minf(wave_limit, wave_distance + WAVE_SPEED * delta)
	_resolve_stage_wave(next_distance)
	for relay in relays:
		if not relay.powered and _wave_reaches(relay.global_position, relay.HIT_RADIUS, next_distance):
			relay.energize()
			_save_progress()
	for guard in guards:
		if guard.knocked_out or guard in wave_hits:
			continue
		var lateral := 62.0 if wave_direction.y < 0.0 else 102.0
		if not _wave_reaches(guard.global_position + Vector2(0.0, -75.0), lateral, next_distance):
			continue
		wave_hits.append(guard)
		var hit_point := guard.global_position + Vector2(0.0, -68.0)
		if guard.shielded:
			guard.flash_shield()
			effects.impact(hit_point, false)
			_show_feedback(Texts.NOTE_SHIELDED, HEAT)
			_play(Audio.ARMOR, -4.0)
			continue
		guard.knockback(signf(wave_direction.x))
		effects.impact(hit_point, true)
		_on_guard_hit(guard)
		if guard.knocked_out:
			_save_progress()
		_hitstop(0.086, 10.5, 0.13, ICE)
	wave_distance = next_distance
	wave_active = wave_distance < wave_limit


func _wave_reaches(point: Vector2, width: float, next_distance: float) -> bool:
	var offset := point - wave_origin
	var ahead := offset.dot(wave_direction)
	if ahead < -20.0 or ahead > next_distance + 28.0 or ahead < wave_distance - 28.0 or absf(offset.cross(wave_direction)) > width:
		return false
	return ahead < wave_limit or is_equal_approx(wave_limit, WAVE_RANGE)


func _resolve_stage_wave(_next_distance: float) -> void:
	pass


func _on_release(origin: Vector2, direction: Vector2) -> void:
	learn(&"release_up" if direction.y < 0.0 else &"release")
	wave_origin = origin
	wave_direction = direction
	wave_distance = 0.0
	wave_hits.clear()
	var chest := Vector2(sera.global_position.x, origin.y)
	var space := get_world_2d().direct_space_state
	var obstruction := PhysicsRayQueryParameters2D.create(chest, origin, 1)
	var ray := PhysicsRayQueryParameters2D.create(origin, origin + direction * WAVE_RANGE, 1)
	wave_limit = WAVE_RANGE
	if not space.intersect_ray(obstruction).is_empty():
		wave_limit = 0.0
	else:
		var wall := space.intersect_ray(ray)
		if not wall.is_empty():
			var point: Vector2 = wall["position"]
			wave_limit = maxf(0.0, (point - origin).dot(direction))
	wave_active = wave_limit > 0.0
	if wave_active:
		effects.release(origin, direction, WAVE_SPEED, wave_limit)
	else:
		effects.impact(chest + Vector2(direction.x * 22.0, 0.0), false)
	_play(Audio.WAVE, -3.0, 1.05 if direction.y < 0.0 else 1.0)
	shake = maxf(shake, 6.0)


func _camera_goal(_point: Vector2) -> Vector2:
	return camera.position


func _update_backdrop() -> void:
	pass


func _update_progress() -> void:
	pass


func _reset_room() -> void:
	pass


func _on_guard_hit(_guard: Guard) -> void:
	pass


## In-world control hints. Each entry is shown above a point in the world until
## the player has used that control once this session. Stages add their own
## object-specific hints in `stage_hints`; these generic ones cover the rest.
func hud_hints() -> Array:
	var hints := []
	if not knows(&"evade") and _incoming(true):
		hints.append(hint(&"evade", Vector2.INF, spoken(Texts.HINT_EVADE, [["Space"]]), HEAT))
	if not knows(&"absorb_shot") and _incoming(false):
		hints.append(hint(&"absorb_shot", Vector2.INF, spoken(Texts.HINT_ABSORB_SHOT, [["LMB"]])))
	if exit_portal and exit_portal.near:
		hints.append(hint(&"exit", exit_portal.global_position + Vector2(0.0, -200.0), spoken(Texts.HINT_EXIT, [["E"]])))
	if not knows(&"move") and checkpoint == 0:
		hints.append(hint(&"move", Vector2.INF, spoken(Texts.HINT_MOVE, [["A", "D"], ["Space"]])))
	hints.append_array(stage_hints())
	if not knows(&"release") and sera.energy >= Sera.RELEASE_COST:
		for guard in guards:
			var gap := guard.global_position.x - sera.global_position.x
			if not guard.knocked_out and not guard.shielded and absf(gap) < 460.0 and absf(guard.global_position.y - sera.global_position.y) < 170.0:
				hints.append(hint(&"release", guard.global_position + Vector2(0.0, -205.0),
					spoken(Texts.HINT_RELEASE, [["RMB"]])))
				break
	return hints


func stage_hints() -> Array:
	return []


## A line Sera says to the player. `at` is the object she is talking about
## (Vector2.INF when she means herself); each row is [input tokens, words].
func hint(id: StringName, at: Vector2, rows: Array, tint: Color = ICE) -> Dictionary:
	return {"id": id, "at": at, "rows": rows, "tint": tint}


func knows(id: StringName) -> bool:
	return campaign.has_learned(id)


func learn(id: StringName) -> void:
	campaign.learn(id)


func _incoming(sweep: bool) -> bool:
	for shot in shots.get_children():
		var gap: float = shot.global_position.x - sera.global_position.x
		if shot.sweep == sweep and shot.direction * gap < 0.0 and absf(gap) < 560.0:
			return true
	return false


func _on_boost(origin: Vector2, direction: float, upward: bool) -> void:
	learn(&"boost_up" if upward else &"dash")
	effects.boost(origin, direction, upward)
	_play(Audio.LIFT if upward else Audio.DASH, -3.0)
	shake = maxf(shake, 4.0)


func _on_enemy_warning(sweep: bool) -> void:
	_play(Audio.SWEEP_CUE if sweep else Audio.SHOT_CUE, -4.0)


func _on_enemy_fire(origin: Vector2, direction: float, sweep: bool) -> void:
	var shot := Incoming.new()
	shot.position = origin
	shot.player = sera
	shot.direction = direction
	shot.sweep = sweep
	shot.absorbed.connect(_on_shot_absorbed)
	shot.evaded.connect(_on_sweep_evaded)
	shots.add_child(shot)
	_play(Audio.SWEEP if sweep else Audio.SHOT, -8.0)
	if sweep:
		effects.impact(origin, false)


func _on_shot_absorbed(origin: Vector2, charge: int, precise: bool) -> void:
	caught_shots += 1
	learn(&"absorb_shot")
	var message: String = Texts.NOTE_ABSORB_PRECISE if precise else Texts.NOTE_ABSORB
	if precise:
		perfect_shots += 1
	if charge > 0:
		message += "  +%d" % charge
	_show_feedback(message, ICE)
	effects.catch_shot(origin, precise)
	_play(Audio.PRECISE_CATCH if precise else Audio.CATCH, -1.0 if precise else -2.0)
	_hitstop(0.105 if precise else 0.057, 6.5 if precise else 3.5, 0.13 if precise else 0.07, ICE)


func _on_sweep_evaded(_origin: Vector2) -> void:
	evade_count += 1
	learn(&"evade")
	_show_feedback(Texts.NOTE_SWEEP_EVADED, ICE)


func _on_player_hit(origin: Vector2, remaining: int) -> void:
	effects.impact(origin, false)
	_play(Audio.DAMAGE, -3.0 if remaining == 0 else -5.0, 0.86 if remaining == 0 else 1.0)
	_hitstop(0.068, 8.0, 0.12, HEAT)
	if remaining == 0:
		retry_left = 0.64
		_show_feedback(Texts.NOTE_SUIT_DOWN, HEAT)
	else:
		_show_feedback(Texts.NOTE_SUIT_DAMAGED, HEAT)


func _on_land(origin: Vector2, speed: float) -> void:
	effects.impact(origin, false, false)
	var force := clampf((speed - 230.0) / 450.0, 0.0, 1.0)
	_play(Audio.LAND, lerpf(-19.0, -9.0, force))
	if speed > 485.0:
		shake = maxf(shake, 2.8)


func _on_warden_crash(origin: Vector2) -> void:
	effects.impact(origin, true)
	_play(Audio.IMPACT, -5.5)
	shake = maxf(shake, 6.0)


func _show_feedback(message: String, tint: Color) -> void:
	feedback = message
	feedback_tint = tint
	feedback_left = 1.50


func _hitstop(seconds: float, amplitude: float, light: float, tint: Color) -> void:
	freeze_left = maxf(freeze_left, seconds)
	shake = maxf(shake, amplitude)
	flash = maxf(flash, light)
	flash_tint = tint
	get_tree().paused = true


func _play(clip: AudioStream, volume: float, pitch := 1.0) -> AudioStreamPlayer:
	if complete or scene_changing:
		return null
	return Audio.play_cue(sound_voices, clip, volume, pitch)
