extends Node

enum Mode { DIRECT, CAMPAIGN, PRACTICE }

const Texts = preload("res://texts.gd")
const TITLE := "res://scenes/title.tscn"
const SAVE_PATH := "user://sera_campaign.json"
const PRACTICE_SAVE_PATH := "user://sera_practice.json"
## Saves written while the project was called MOMENTUM, in the sibling
## app_userdata folder. Copied once into the new folder when it has none.
const LEGACY_USER_DIR := "MOMENTUM"
const LEGACY_SAVES := {
	"momentum_campaign.json": SAVE_PATH,
	"momentum_practice.json": PRACTICE_SAVE_PATH,
}
const SAVE_VERSION := 1
const PRACTICE_SAVE_VERSION := 1
const MAX_RECORD_MS := 86400000
## Cumulative times at the two checkpoints and the finish. Zero marks a skipped split.
const EMPTY_PRACTICE_SPLITS: Array[int] = [0, 0, 0]
const SCENES := [
	"res://scenes/foundry.tscn",
	"res://scenes/cooling_tower.tscn",
	"res://scenes/reactor.tscn",
	"res://scenes/rolling_mill.tscn",
	"res://scenes/steam_works.tscn",
	"res://scenes/loading_yard.tscn",
	"res://scenes/outer_ring.tscn",
	"res://scenes/control_spine.tscn",
	"res://scenes/great_wheel.tscn",
]
## Key art per stage: the preferred painting, then the stand-in used until it exists.
const ART := [
	["res://assets/environment/foundry.jpg", ""],
	["res://assets/environment/cooling_tower.jpg", ""],
	["res://assets/environment/reactor.jpg", ""],
	["res://assets/environment/rolling_mill.jpg", "res://assets/environment/furnace.jpg"],
	["res://assets/environment/steam_works.jpg", "res://assets/environment/cooling_tower.jpg"],
	["res://assets/environment/loading_yard.jpg", "res://assets/environment/foundry.jpg"],
	["res://assets/environment/outer_ring.jpg", "res://assets/environment/reactor.jpg"],
	["res://assets/environment/control_spine.jpg", "res://assets/environment/cooling_tower.jpg"],
	["res://assets/environment/great_wheel.jpg", "res://assets/environment/reactor.jpg"],
]

var _profile: Dictionary = _blank_profile()
var _practice_records: Dictionary = {}
var read_failed := false
## Controls the player has already performed this session. In-world hints for
## them stop appearing. Kept in memory so practice never touches the save file.
var learned: Dictionary = {}


func _ready() -> void:
	migrate_legacy_saves()
	reload_profile()
	reload_practice_records()


## Copies saves from the old MOMENTUM folder. Old files are left in place, and
## a save that already exists under the new name is never overwritten.
static func migrate_legacy_saves() -> void:
	var legacy_dir := OS.get_user_data_dir().get_base_dir().path_join(LEGACY_USER_DIR)
	for old_name: String in LEGACY_SAVES:
		var target: String = LEGACY_SAVES[old_name]
		var source := legacy_dir.path_join(old_name)
		if FileAccess.file_exists(target) or not FileAccess.file_exists(source):
			continue
		var error := DirAccess.copy_absolute(source, ProjectSettings.globalize_path(target))
		if error != OK:
			push_warning("Could not copy %s from the MOMENTUM save folder (%s)" % [old_name, error_string(error)])


static func _blank_profile() -> Dictionary:
	var records := []
	records.resize(SCENES.size())
	records.fill(0)
	return {"version": SAVE_VERSION, "resume": {}, "best_ms": records}


## True when the stage's own painting has been added to the project.
static func has_own_art(index: int) -> bool:
	return ResourceLoader.exists(ART[index][0])


static func stage_art(index: int) -> Texture2D:
	return load(ART[index][0] if has_own_art(index) else ART[index][1])


func reload_profile() -> void:
	_profile = _blank_profile()
	read_failed = false
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed := _read_json(SAVE_PATH, SAVE_VERSION)
	if parsed.is_empty():
		read_failed = true
		return
	var resume: Variant = parsed.get("resume", {})
	if resume is Dictionary:
		_profile["resume"] = _clean_snapshot(resume)
	var records: Variant = parsed.get("best_ms")
	if records is Array:
		for i in mini(records.size(), SCENES.size()):
			_profile["best_ms"][i] = _integer(records[i], 0, MAX_RECORD_MS, 0)


func reload_practice_records() -> void:
	_practice_records.clear()
	if not FileAccess.file_exists(PRACTICE_SAVE_PATH):
		return
	var records: Variant = _read_json(PRACTICE_SAVE_PATH, PRACTICE_SAVE_VERSION).get("records")
	if records is Dictionary:
		for path: String in SCENES:
			var splits := _clean_practice_splits(records.get(path))
			if splits[-1] > 0:
				_practice_records[path] = splits


func practice_splits(index: int) -> Array[int]:
	var splits: Array[int] = _practice_records.get(SCENES[index], EMPTY_PRACTICE_SPLITS)
	return splits.duplicate()


func finish_practice(index: int, splits: Array[int]) -> Error:
	if index < 0 or index >= SCENES.size():
		return ERR_INVALID_PARAMETER
	var record := _clean_practice_splits(splits)
	var best: int = practice_splits(index)[-1]
	if record[-1] <= 0:
		return ERR_INVALID_DATA
	if best > 0 and record[-1] >= best:
		return OK
	var candidate := _practice_records.duplicate()
	candidate[SCENES[index]] = record
	var error := _write_json(PRACTICE_SAVE_PATH, {"version": PRACTICE_SAVE_VERSION, "records": candidate})
	if error == OK:
		_practice_records = candidate
	return error


static func practice_segment_ms(splits: Array[int], segment: int) -> int:
	var end := splits[segment]
	var start := 0 if segment == 0 else splits[segment - 1]
	return end - start if end > 0 and (segment == 0 or start > 0) else -1


static func practice_delta_label(milliseconds: int) -> String:
	var seconds := "%+.2f" % (milliseconds / 1000.0) if absi(milliseconds) >= 5 else "0.00"
	return Texts.PRACTICE_DELTA.format({"차이": seconds})


func has_learned(id: StringName) -> bool:
	return learned.has(id)


func learn(id: StringName) -> void:
	learned[id] = true


func resume_snapshot() -> Dictionary:
	return _profile["resume"].duplicate()


func resume_label() -> String:
	var snapshot := resume_snapshot()
	if snapshot.is_empty():
		return ""
	var index: int = snapshot["stage"]
	return Texts.TITLE_RESUME.format({
		"스테이지": Texts.stage_name(index), "구간": Texts.section(index, snapshot["checkpoint"]), "운동량": snapshot["charge"]})


func best_ms(index: int) -> int:
	return _profile["best_ms"][index]


func stage_index(scene_path: String) -> int:
	return SCENES.find(scene_path)


func entry_snapshot(index: int, charge: int) -> Dictionary:
	return {
		"stage": index, "checkpoint": 0, "entry_charge": charge, "charge": charge,
		"guards": 0, "relays": 0, "elapsed_ms": 0, "perfect": 0, "retries": 0,
	}


func save_checkpoint(snapshot: Dictionary) -> Error:
	var candidate := _profile.duplicate(true)
	candidate["resume"] = _clean_snapshot(snapshot)
	return _commit(candidate)


func finish(index: int, elapsed_seconds: float, carry: int) -> Error:
	var candidate := _profile.duplicate(true)
	var time := clampi(roundi(elapsed_seconds * 1000.0), 1, MAX_RECORD_MS)
	var previous := best_ms(index)
	if previous == 0 or time < previous:
		candidate["best_ms"][index] = time
	candidate["resume"] = entry_snapshot(index + 1, carry) if index + 1 < SCENES.size() else {}
	return _commit(candidate)


func open_stage(index: int, mode: Mode, snapshot: Dictionary) -> Error:
	if index < 0 or index >= SCENES.size():
		return ERR_INVALID_PARAMETER
	var packed := ResourceLoader.load(SCENES[index]) as PackedScene
	if packed == null:
		return ERR_CANT_OPEN
	if mode == Mode.PRACTICE:
		snapshot = entry_snapshot(index, 0)
	var stage := packed.instantiate()
	stage.entry_charge = int(snapshot.get("entry_charge", 0))
	stage.play_mode = mode
	stage.initial_checkpoint = snapshot.duplicate()
	var result := get_tree().change_scene_to_node(stage)
	if result != OK:
		stage.free()
	else:
		get_tree().paused = false
	return result


func time_label(milliseconds: int) -> String:
	var tenths := floori(milliseconds / 100.0)
	return "%d:%02d.%d" % [floori(tenths / 600.0), floori(tenths / 10.0) % 60, tenths % 10]


func _clean_practice_splits(value: Variant) -> Array[int]:
	var splits := EMPTY_PRACTICE_SPLITS.duplicate()
	if not value is Array or value.size() != splits.size():
		return splits
	var finish_time := _integer(value[-1], 1, MAX_RECORD_MS, 0)
	if finish_time == 0:
		return splits
	var previous := 1
	for i in splits.size() - 1:
		splits[i] = _integer(value[i], previous, finish_time, 0)
		previous = maxi(previous, splits[i])
	splits[-1] = finish_time
	return splits


func _clean_snapshot(data: Dictionary) -> Dictionary:
	var index := _integer(data.get("stage"), -1, SCENES.size() - 1, -1)
	if index < 0:
		return {}
	return {
		"stage": index,
		"checkpoint": _integer(data.get("checkpoint"), 0, 2, 0),
		"entry_charge": _integer(data.get("entry_charge"), 0, 100, 0),
		"charge": _integer(data.get("charge"), 0, 100, 0),
		"guards": _integer(data.get("guards"), 0, 255, 0),
		"relays": _integer(data.get("relays"), 0, 255, 0),
		"elapsed_ms": _integer(data.get("elapsed_ms"), 0, MAX_RECORD_MS, 0),
		"perfect": _integer(data.get("perfect"), 0, 1000000, 0),
		"retries": _integer(data.get("retries"), 0, 1000000, 0),
	}


func _integer(value: Variant, low: int, high: int, fallback: int) -> int:
	if value is int or value is float:
		var number := float(value)
		if is_finite(number) and number == floorf(number) and number >= low and number <= high:
			return int(number)
	return fallback


func _commit(candidate: Dictionary) -> Error:
	var error := _write_json(SAVE_PATH, candidate)
	if error == OK:
		_profile = candidate
		read_failed = false
	return error


func _read_json(path: String, version: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32768:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _integer(parsed.get("version"), -1, 1000, -1) == version:
		return parsed
	return {}


func _write_json(path: String, candidate: Dictionary) -> Error:
	var temp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(candidate))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temp, path)
	if error != OK and FileAccess.file_exists(temp):
		DirAccess.remove_absolute(temp)
	return error
