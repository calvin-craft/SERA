extends SceneTree

const Pilot = preload("res://tests/pilot.gd")

## Checks that texts.gd still has the shape the game expects after it has been
## edited by hand, and that the stages really show its words.

const Texts = preload("res://texts.gd")
const Store = preload("res://scripts/campaign.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_shape()
	_check_particles()
	await _check_stage_uses_it()
	paused = false
	if failures.is_empty():
		print("PASS: every stage has its words, particles follow the name, and stages show what texts.gd says")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)


func _check_shape() -> void:
	_check(Texts.STAGES.size() == Store.SCENES.size(), "texts.gd의 STAGES 묶음 수가 스테이지 수(%d)와 같아야 합니다" % Store.SCENES.size())
	_check(Texts.ACTS.size() * 3 >= Store.SCENES.size(), "ACTS에 막 이름이 모자랍니다")
	for index in Texts.STAGES.size():
		var entry: Dictionary = Texts.STAGES[index]
		var label := "STAGES의 %d번째 묶음" % (index + 1)
		for key in ["name", "card", "sections", "clear_title", "clear_note", "says"]:
			_check(entry.has(key), "%s에 \"%s\" 줄이 없습니다" % [label, key])
		if entry.has("name"):
			_check(not String(entry["name"]).is_empty() and not String(entry["name"]).contains("/"), "%s의 name은 비어 있거나 / 를 포함하면 안 됩니다" % label)
		if entry.has("sections"):
			_check(entry["sections"] is Array and entry["sections"].size() == 3, "%s의 sections에는 구간 이름이 세 개 있어야 합니다" % label)
			for part: String in entry["sections"]:
				_check(not part.contains("/"), "%s의 구간 이름에는 / 를 쓸 수 없습니다" % label)
	_check(Texts.CONTROLS.size() == 9, "CONTROLS에는 조작 설명이 아홉 줄 있어야 합니다")
	# The story lines the stages ask for by position.
	for needed: Array in [[3, 3], [4, 3], [5, 1], [6, 3], [7, 3], [8, 1]]:
		_check(Texts.stage(needed[0])["says"].size() >= needed[1], "STAGES의 %d번째 묶음 says에는 대사가 %d줄 필요합니다" % [needed[0] + 1, needed[1]])


func _check_particles() -> void:
	for pair: Array in [["냉각탑", "냉각탑으로"], ["동력로", "동력로로"], ["압연 라인", "압연 라인으로"], ["출하 야드", "출하 야드로"],
			["서울", "서울로"], ["Yard", "Yard(으)로"]]:
		_check(Texts.toward(pair[0]) == pair[1], "\"%s\" 뒤의 조사는 \"%s\"여야 합니다" % [pair[0], pair[1]])


func _check_stage_uses_it() -> void:
	for index in Store.SCENES.size():
		change_scene_to_file(Store.SCENES[index])
		await scene_changed
		await physics_frame
		var stage := current_scene
		var entry: Dictionary = Texts.STAGES[index]
		_check(stage.clear_title == entry["clear_title"] and stage.clear_note == entry["clear_note"], "%s: 클리어 문구가 texts.gd에서 옵니다" % entry["name"])
		_check(String(stage.hud_section()).begins_with(entry["name"] + "  /  "), "%s: 왼쪽 위 표시가 스테이지 이름으로 시작합니다" % entry["name"])
		var following := Store.SCENES.find(stage.next_scene)
		_check(following >= 0 and stage.result_action_label() == Texts.toward(Texts.stage_name(following)), "%s: 다음 스테이지 버튼이 이름에서 만들어집니다" % entry["name"])
		for hint: Dictionary in stage.hud_hints():
			for row: Array in hint["rows"]:
				_check(row.size() == 2 and row[0] is Array and row[1] is String, "%s: 말풍선 줄의 모양이 맞습니다" % entry["name"])
	var rows: Array = current_scene.spoken(["말", "안내 하나", "안내 둘"], [["A"], ["B"]])
	_check(rows == [[[], "말"], [["A"], "안내 하나"], [["B"], "안내 둘"]], "말풍선의 첫 줄은 말, 나머지는 키 옆 안내입니다")
	await Pilot.close_scene(self)


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
	return condition
