extends RefCounted

const DASH := preload("res://assets/audio/boost.wav")
const LIFT := preload("res://assets/audio/boost_up.wav")
const WAVE := preload("res://assets/audio/burst.wav")
const CATCH := preload("res://assets/audio/catch.wav")
const PRECISE_CATCH := preload("res://assets/audio/catch_precise.wav")
const HEAVY_CATCH := preload("res://assets/audio/catch_heavy.wav")
const SHOT_CUE := preload("res://assets/audio/warning.wav")
const SWEEP_CUE := preload("res://assets/audio/warning_sweep.wav")
const CHARGE_CUE := preload("res://assets/audio/warning_ram.wav")
const BRACE_CUE := preload("res://assets/audio/timing.wav")
const SHOT := preload("res://assets/audio/bolt.wav")
const SWEEP := preload("res://assets/audio/sweep.wav")
const IMPACT := preload("res://assets/audio/clang.wav")
const ARMOR := preload("res://assets/audio/armor.wav")
const CORE_BREAK := preload("res://assets/audio/core_break.wav")
const DAMAGE := preload("res://assets/audio/damage.wav")
const LAND := preload("res://assets/audio/land.wav")
const EMPTY := preload("res://assets/audio/empty.wav")
const STEAM := preload("res://assets/audio/steam.wav")
const STEAM_CUE := preload("res://assets/audio/steam_warning.wav")
const STEAM_BED := preload("res://assets/audio/steam_loop.wav")
const PRESS_CUE := preload("res://assets/audio/press_warning.wav")
const RELAY := preload("res://assets/audio/relay.wav")
const WAKE := preload("res://assets/audio/wake.wav")
const CHECKPOINT := preload("res://assets/audio/checkpoint.wav")
const CLEAR := preload("res://assets/audio/clear.wav")
const WHEEL_RELEASE := preload("res://assets/audio/wheel_release.wav")
const MENU_MOVE := preload("res://assets/audio/menu_move.wav")
const MENU_SELECT := preload("res://assets/audio/menu_select.wav")

const FOUNDRY_ROOM := preload("res://assets/audio/foundry_loop.wav")
const VENT_ROOM := preload("res://assets/audio/vent_loop.wav")
const WHEEL_ROOM := preload("res://assets/audio/wheel_loop.wav")
const STAGE_ROOMS := [FOUNDRY_ROOM, VENT_ROOM, WHEEL_ROOM, FOUNDRY_ROOM,
	VENT_ROOM, FOUNDRY_ROOM, WHEEL_ROOM, VENT_ROOM, WHEEL_ROOM]
const ROOM_FADE := &"room_fade"
const DRAIN_SECONDS := 0.16


static func prepare(player: AudioStreamPlayer, bus: StringName, voices: int) -> Array[AudioStreamPlayer]:
	player.bus = bus
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var players: Array[AudioStreamPlayer] = [player]
	for index in range(1, voices):
		var voice := AudioStreamPlayer.new()
		voice.name = "%sVoice%d" % [player.name, index + 1]
		voice.bus = bus
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.get_parent().add_child(voice)
		players.append(voice)
	return players


static func play_cue(players: Array[AudioStreamPlayer], clip: AudioStream, volume: float, pitch := 1.0) -> AudioStreamPlayer:
	for voice in players:
		if voice.playing:
			continue
		voice.stream = clip
		voice.volume_db = volume
		voice.pitch_scale = pitch
		voice.play()
		return voice
	return null


static func stage_room(index: int) -> AudioStreamWAV:
	return STAGE_ROOMS[index] if index >= 0 and index < STAGE_ROOMS.size() else FOUNDRY_ROOM


static func start_room(parent: Node, clip: AudioStreamWAV, level_db: float) -> AudioStreamPlayer:
	var room := AudioStreamPlayer.new()
	room.name = "RoomTone"
	room.bus = &"Ambience"
	room.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	room.volume_db = -42.0
	room.stream = clip
	parent.add_child(room)
	# Let the scene settle before starting a loop. Very short scene visits
	# can leave before any audio playback has been allocated.
	var fade := room.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	room.set_meta(ROOM_FADE, fade)
	fade.tween_interval(0.12)
	fade.tween_callback(room.play)
	fade.tween_property(room, "volume_db", level_db, 0.36)
	fade.finished.connect(func(): room.remove_meta(ROOM_FADE))
	return room


static func stop_players(parent: Node, release := true) -> bool:
	var had_playback := false
	for child in parent.get_children():
		if child is AudioStreamPlayer:
			if child.has_meta(ROOM_FADE):
				var fade: Tween = child.get_meta(ROOM_FADE)
				fade.kill()
				child.remove_meta(ROOM_FADE)
			if child.has_stream_playback():
				child.get_stream_playback().stop()
				had_playback = true
			child.stop()
			if release:
				child.stream = null
	return had_playback


static func drain(parent: Node) -> void:
	# The audio server retires stopped playback on its mix thread. Let it
	# finish before freeing the scene, including during a gameplay hitstop.
	if stop_players(parent, false):
		await parent.get_tree().create_timer(DRAIN_SECONDS, true, false, true).timeout


static func resume_rooms(parent: Node, paused: bool = false) -> void:
	for child in parent.get_children():
		if child is AudioStreamPlayer and child.bus == &"Ambience":
			child.play()
			child.stream_paused = paused


static func quit_game(scene: Node) -> void:
	var tree := scene.get_tree()
	tree.paused = true
	await drain(scene)
	tree.quit()
