extends SceneTree

## Opens every chapter three stage the way F6 would and lets it run for a few
## seconds without input: the scene loads, its machines start, nothing errors,
## and each stage has the abilities and words chapter three expects. It also
## checks the chapter card and that the campaign's last stage leads to the
## epilogue. It does not play the stages through.

const Store = preload("res://scripts/campaign.gd")
const Texts = preload("res://texts.gd")
const Pilot = preload("res://tests/pilot.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var first := Texts.chapter_start(2)
	for index in range(first, first + Texts.chapter_size(2)):
		await _open(index)
	await _chapter_card()
	await _epilogue()
	await Pilot.close_scene(self)
	if failures.is_empty():
		print("PASS: all nine chapter three stages open and run with reflect, their words, the chapter card and the epilogue")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)


func _open(index: int) -> void:
	var path: String = Store.SCENES[index]
	var name := Texts.stage_name(index)
	if not _check(ResourceLoader.exists(path), "%s: %s 파일이 있습니다" % [name, path]):
		return
	change_scene_to_file(path)
	await scene_changed
	for frame in 240:
		await physics_frame
	var stage := current_scene
	if not _check(stage != null and stage.scene_file_path == path, "%s: 스테이지가 열립니다" % name):
		return
	_check(stage.sera != null and stage.sera.integrity > 0, "%s: 세라가 서 있습니다" % name)
	_check(stage.sera.air_absorb and stage.sera.down_release, "%s: 2챕터 능력이 켜져 있습니다" % name)
	_check(stage.sera.reflect == (index >= Store.REFLECT_FROM), "%s: 반사가 맞게 켜집니다" % name)
	_check(String(stage.hud_section()).begins_with(name + "  /  "), "%s: 왼쪽 위 표시" % name)
	_check(Texts.stage(index)["clear_title"] == stage.clear_title, "%s: 클리어 문구" % name)
	_check(not stage.next_scene.is_empty() and Store.SCENES.has(stage.next_scene), "%s: 다음 스테이지가 연결돼 있습니다" % name)
	for hint: Dictionary in stage.hud_hints():
		for row: Array in hint["rows"]:
			_check(row.size() == 2 and row[0] is Array and row[1] is String, "%s: 말풍선 줄의 모양이 맞습니다" % name)


## Arriving at chapter three in the campaign shows its card first.
func _chapter_card() -> void:
	var campaign: Store = root.get_node("Campaign")
	var first := Texts.chapter_start(2)
	if campaign.open_stage(first, Store.Mode.CAMPAIGN, campaign.entry_snapshot(first, 0)) != OK:
		_check(false, "3챕터 첫 스테이지를 캠페인으로 열 수 있습니다")
		return
	await scene_changed
	await physics_frame
	_check(current_scene.card_left > 0.0 and paused, "3챕터 첫 스테이지에서 챕터 카드가 뜹니다")
	await create_timer(current_scene.CHAPTER_CARD_TIME + 0.2).timeout
	_check(current_scene.card_left == 0.0 and not paused, "챕터 카드가 끝나면 스테이지가 시작됩니다")


## The last stage, cleared in the campaign, offers the epilogue and then the title.
func _epilogue() -> void:
	var campaign: Store = root.get_node("Campaign")
	var last := Store.SCENES.size() - 1
	if campaign.open_stage(last, Store.Mode.CAMPAIGN, campaign.entry_snapshot(last, 0)) != OK:
		_check(false, "마지막 스테이지를 캠페인으로 열 수 있습니다")
		return
	await scene_changed
	await physics_frame
	var stage := current_scene
	_check(stage.has_epilogue() and stage.result_action_label() == Texts.CLEAR_TO_EPILOGUE, "마지막 스테이지는 에필로그로 이어집니다")
	stage.complete = true
	Input.action_press(&"continue_stage")
	await physics_frame
	await physics_frame
	Input.action_release(&"continue_stage")
	_check(stage.epilogue_age >= 0.0 and not stage.scene_changing, "E를 누르면 에필로그가 시작됩니다")
	stage.epilogue_age = stage.epilogue_length() + 0.1
	await physics_frame
	# The stage may already be gone two frames after E, so note it first.
	var id := stage.get_instance_id()
	Input.action_press(&"continue_stage")
	await physics_frame
	await physics_frame
	Input.action_release(&"continue_stage")
	for frame in 120:
		if current_scene != null and current_scene.get_instance_id() != id:
			break
		await physics_frame
	_check(current_scene != null and current_scene.scene_file_path == Store.TITLE, "에필로그가 끝난 뒤 E를 누르면 타이틀로 갑니다")


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
