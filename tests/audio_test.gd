extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const Pilot = preload("res://tests/pilot.gd")
const Stage = preload("res://scripts/stage.gd")
const Sector = preload("res://scripts/sector.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for room: AudioStreamWAV in [Audio.FOUNDRY_ROOM, Audio.VENT_ROOM, Audio.WHEEL_ROOM, Audio.STEAM_BED]:
		_check(room.loop_mode == AudioStreamWAV.LOOP_FORWARD and room.loop_end > room.loop_begin,
			"the importer keeps the WAV loop: " + room.resource_path)
	for bus: StringName in [&"Effects", &"Ambience", &"Menus"]:
		_check(AudioServer.get_bus_index(bus) > 0, "the mix has a bus for " + String(bus))

	change_scene_to_file("res://scenes/foundry.tscn")
	await scene_changed
	var stage := current_scene as Stage
	_check(not stage.sound.has_stream_playback() and not stage.room_tone.playing,
		"opening and immediately leaving a scene does not allocate audio playback")
	await create_timer(0.20).timeout
	var impact := stage._play(Audio.IMPACT, -4.0)
	var warning := stage._play(Audio.SWEEP_CUE, -4.0)
	_check(stage.room_tone.playing, "the stage starts its room tone")
	var overlap := _check(impact != null and warning != null and impact != warning and impact.playing and warning.playing,
		"an attack cue can sound over an impact")
	stage._set_player_pause(true)
	if overlap:
		_check(impact.stream_paused and warning.stream_paused and stage.room_tone.stream_paused,
			"pause mutes both voices and room tone together")
	stage._set_player_pause(false)
	_check(not stage.sound.stream_paused and not stage.room_tone.stream_paused, "resume restores both audio layers")
	stage._finish_stage()
	await create_timer(0.78).timeout
	_check(not stage.room_tone.playing, "the stage room tone fades and stops on clear")

	change_scene_to_file("res://scenes/steam_works.tscn")
	await scene_changed
	await create_timer(0.56).timeout
	var works := current_scene as Sector
	var near_steam := works.get_node("World/SteamB") as Node2D
	var quiet := works.steam_tone.volume_db
	works.sera.reset_at(near_steam.position + Vector2(-115.0, -1.0), 0)
	await create_timer(0.35).timeout
	_check(works.steam_tone.volume_db > quiet + 12.0, "active steam becomes audible as the player approaches")
	works._set_player_pause(true)
	_check(works.steam_tone.stream_paused, "pause also suspends the local steam loop")
	works._set_player_pause(false)
	await Pilot.close_scene(self)

	if failures.is_empty():
		print("PASS: imported loops, audio buses, overlapping cues, pause, clear fade and distance-based steam")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
