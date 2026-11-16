extends Control

const CampaignStore = preload("res://scripts/campaign.gd")
const MenuTheme = preload("res://scripts/menu_theme.gd")
const MenuItem = preload("res://scripts/menu_item.gd")
const StageCard = preload("res://scripts/stage_card.gd")
const Texts = preload("res://texts.gd")
const Audio = preload("res://scripts/game_audio.gd")
const LOGO := preload("res://assets/environment/sera_logo.png")
const LOGO_FINISH := preload("res://assets/environment/sera_logo.gdshader")
const LOGO_REGION := Rect2(9, 160, 2137, 451)
const STAGE_TINT := [
	Color("#87e7f5"), Color("#8fd9ff"), Color("#ff9e6e"),
	Color("#ffb46e"), Color("#9fe6d8"), Color("#ffc27b"),
	Color("#b9a6ff"), Color("#8fd9ff"), Color("#ff8a70"),
]
const CARD_SIZE := Vector2(286, 330)

var main_page: Control
var practice_page: ColorRect
var continue_button: Button
var new_button: Button
var practice_button: Button
var stage_buttons: Array[Button] = []
var status: Label
var confirm_new: ConfirmationDialog
var loading := false

var decor: Control
var curtain: ColorRect
var menu_items: Array[MenuItem] = []
var practice_header: Control
var practice_back: MenuItem
var ui_voices: Array[AudioStreamPlayer]
var clock := 0.0
var sound_ready := false


@onready var campaign: CampaignStore = get_node("/root/Campaign")


func _ready() -> void:
	campaign.reload_profile()
	theme = MenuTheme.create()
	_add_shade()
	_add_particles()

	decor = Control.new()
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(decor)
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.draw.connect(_draw_decor)

	var ui_sound := AudioStreamPlayer.new()
	ui_sound.name = "UiSound"
	add_child(ui_sound)
	ui_voices = Audio.prepare(ui_sound, &"Menus", 5)
	Audio.start_room(self, Audio.FOUNDRY_ROOM, -11.0)

	_build_main()
	_build_practice()
	confirm_new = ConfirmationDialog.new()
	confirm_new.title = Texts.CONFIRM_TITLE
	confirm_new.dialog_text = Texts.CONFIRM_TEXT.format({"스테이지": Texts.stage_name(0)})
	confirm_new.ok_button_text = Texts.CONFIRM_OK
	confirm_new.cancel_button_text = Texts.CONFIRM_CANCEL
	confirm_new.theme = theme
	add_child(confirm_new)
	confirm_new.confirmed.connect(_new_game)

	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_tween().tween_property(curtain, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)

	_show_main()
	_play_intro(menu_items, 0.35)
	_enable_sound.call_deferred()


func _exit_tree() -> void:
	Audio.stop_players(self)


func _enable_sound() -> void:
	await get_tree().process_frame
	sound_ready = true


func _process(delta: float) -> void:
	clock += delta
	decor.queue_redraw()


func _add_shade() -> void:
	var left := Gradient.new()
	left.offsets = PackedFloat32Array([0.0, 0.34, 0.66])
	left.colors = PackedColorArray([Color(0.008, 0.02, 0.03, 0.95), Color(0.008, 0.02, 0.03, 0.72), Color(0.008, 0.02, 0.03, 0.0)])
	var side := TextureRect.new()
	side.texture = GradientTexture2D.new()
	side.texture.gradient = left
	side.texture.width = 256
	side.texture.height = 4
	_fill(side)

	var low := Gradient.new()
	low.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	low.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.005, 0.015, 0.02, 0.85)])
	var bottom := TextureRect.new()
	bottom.texture = GradientTexture2D.new()
	bottom.texture.gradient = low
	bottom.texture.fill_from = Vector2(0, 0)
	bottom.texture.fill_to = Vector2(0, 1)
	bottom.texture.width = 4
	bottom.texture.height = 256
	_fill(bottom)


func _fill(node: TextureRect) -> void:
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _add_particles() -> void:
	var embers := CPUParticles2D.new()
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.position = Vector2(760, 690)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(560, 20)
	embers.direction = Vector2(0.15, -1.0)
	embers.spread = 18.0
	embers.gravity = Vector2(8.0, -10.0)
	embers.initial_velocity_min = 22.0
	embers.initial_velocity_max = 64.0
	embers.scale_amount_min = 1.2
	embers.scale_amount_max = 3.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.75, 0.4, 0.0), Color(1.0, 0.68, 0.32, 0.9), Color(1.0, 0.45, 0.2, 0.55), Color(1.0, 0.3, 0.1, 0.0)])
	embers.color_ramp = ramp
	add_child(embers)

	var dust := CPUParticles2D.new()
	dust.amount = 26
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.position = Vector2(576, 324)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(600, 330)
	dust.direction = Vector2(1, -0.2)
	dust.spread = 40.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	var haze := Gradient.new()
	haze.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	haze.colors = PackedColorArray([Color(0.6, 0.9, 1.0, 0.0), Color(0.6, 0.9, 1.0, 0.45), Color(0.6, 0.9, 1.0, 0.0)])
	dust.color_ramp = haze
	add_child(dust)


func _build_main() -> void:
	main_page = Control.new()
	main_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_page)
	main_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var artwork := AtlasTexture.new()
	artwork.atlas = LOGO
	artwork.region = LOGO_REGION
	artwork.filter_clip = true
	var logo := TextureRect.new()
	logo.name = "TitleLogo"
	logo.texture = artwork
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_page.add_child(logo)
	logo.anchor_left = 0.055
	logo.anchor_right = 0.41
	logo.offset_top = 76
	logo.offset_bottom = 209
	var metal := ShaderMaterial.new()
	metal.shader = LOGO_FINISH
	logo.material = metal
	var reflection := logo.create_tween().set_loops()
	reflection.tween_interval(1.25)
	reflection.tween_method(
		func(position: float) -> void: metal.set_shader_parameter(&"reflection_position", position),
		-0.22, 1.22, 1.8
	)
	reflection.tween_interval(4.5)

	var column := VBoxContainer.new()
	main_page.add_child(column)
	column.anchor_left = 0.055
	column.anchor_right = 0.41
	column.anchor_top = 0.0
	column.offset_top = 250
	column.add_theme_constant_override(&"separation", 7)

	continue_button = _menu_item(Texts.TITLE_CONTINUE, "01", 48)
	new_button = _menu_item(Texts.TITLE_NEW_GAME, "02", 48)
	practice_button = _menu_item(Texts.TITLE_PRACTICE, "03", 48)
	var quit := _menu_item(Texts.TITLE_QUIT, "", 38)
	quit.font_size = 17
	for item in [continue_button, new_button, practice_button, quit]:
		column.add_child(item)
	continue_button.pressed.connect(_continue_game)
	new_button.pressed.connect(_confirm_start)
	practice_button.pressed.connect(_show_practice)
	quit.pressed.connect(func(): Audio.quit_game(self))

	status = MenuTheme.label("", 14, MenuTheme.HEAT)
	column.add_child(status)


func _menu_item(text: String, number: String, height: float) -> MenuItem:
	var item := MenuItem.new()
	item.text = text
	item.index_label = number
	item.font_size = 21
	item.compact = true
	item.custom_minimum_size.y = height
	item.focus_entered.connect(_on_menu_focus)
	item.pressed.connect(_on_menu_pick)
	menu_items.append(item)
	return item


func _build_practice() -> void:
	practice_page = ColorRect.new()
	practice_page.color = Color(0.008, 0.02, 0.032, 0.82)
	add_child(practice_page)
	practice_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	practice_header = Control.new()
	practice_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	practice_page.add_child(practice_header)
	practice_header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	practice_header.draw.connect(_draw_practice_header)

	# Nine cards, three on screen at a time: one act per page. The row scrolls to the focused card.
	var scroller := ScrollContainer.new()
	scroller.follow_focus = true
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	practice_page.add_child(scroller)
	scroller.anchor_left = 0.5
	scroller.anchor_right = 0.5
	scroller.offset_left = -(CARD_SIZE.x * 3.0 + 26.0 * 2.0) * 0.5 - 14.0
	scroller.offset_right = -scroller.offset_left
	scroller.offset_top = 166
	scroller.offset_bottom = 184 + CARD_SIZE.y + 22
	var frame := MarginContainer.new()
	for side in [&"margin_left", &"margin_right"]:
		frame.add_theme_constant_override(side, 14)
	frame.add_theme_constant_override(&"margin_top", 18)
	frame.add_theme_constant_override(&"margin_bottom", 18)
	scroller.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 26)
	frame.add_child(row)

	for i in CampaignStore.SCENES.size():
		var best := campaign.best_ms(i)
		var record: String = campaign.time_label(best) if best > 0 else "--:--.-"
		var practice_ms: int = campaign.practice_splits(i)[-1]
		var practice_record := campaign.time_label(practice_ms) if practice_ms > 0 else "--:--.-"
		var card := StageCard.new()
		card.text = "\n".join([Texts.stage_name(i), Texts.stage(i)["card"],
			Texts.CARD_RECORD.format({"기록": record}), Texts.CARD_PRACTICE_RECORD.format({"기록": practice_record})])
		card.art = CampaignStore.stage_art(i)
		card.number = i + 1
		card.stage_name = Texts.stage_name(i)
		card.focus_line = Texts.stage(i)["card"]
		card.record = record
		card.practice_record = practice_record
		card.has_practice_record = practice_ms > 0
		card.cleared = best > 0
		card.tint = STAGE_TINT[i]
		card.custom_minimum_size = CARD_SIZE
		row.add_child(card)
		card.pressed.connect(_start_practice.bind(i))
		card.focus_entered.connect(_on_menu_focus)
		card.focus_entered.connect(practice_header.queue_redraw)
		card.pressed.connect(_on_menu_pick)
		stage_buttons.append(card)

	practice_back = MenuItem.new()
	practice_back.text = Texts.PRACTICE_BACK
	practice_back.caption = "Esc"
	practice_back.font_size = 19
	practice_back.compact = true
	practice_back.custom_minimum_size = Vector2(250, 44)
	practice_page.add_child(practice_back)
	practice_back.anchor_left = 0.5
	practice_back.anchor_right = 0.5
	practice_back.anchor_top = 1.0
	practice_back.anchor_bottom = 1.0
	practice_back.offset_left = -125
	practice_back.offset_right = 125
	practice_back.offset_top = -112
	practice_back.offset_bottom = -68
	practice_back.pressed.connect(_close_practice)
	practice_back.focus_entered.connect(_on_menu_focus)

	# Cards sit in a row; up/down also step through them so lists and pads both work.
	for i in stage_buttons.size():
		var card := stage_buttons[i]
		var previous := stage_buttons[maxi(i - 1, 0)]
		var next: Control = stage_buttons[i + 1] if i + 1 < stage_buttons.size() else practice_back
		card.focus_neighbor_left = card.get_path_to(previous)
		card.focus_neighbor_top = card.get_path_to(previous)
		card.focus_neighbor_right = card.get_path_to(stage_buttons[mini(i + 1, stage_buttons.size() - 1)])
		card.focus_neighbor_bottom = card.get_path_to(next)
		card.focus_next = card.get_path_to(next)
		card.focus_previous = card.get_path_to(previous)
	var last := stage_buttons[stage_buttons.size() - 1]
	practice_back.focus_neighbor_top = practice_back.get_path_to(last)
	practice_back.focus_neighbor_left = practice_back.get_path_to(last)
	practice_back.focus_neighbor_bottom = practice_back.get_path_to(practice_back)
	practice_back.focus_neighbor_right = practice_back.get_path_to(practice_back)
	practice_back.focus_previous = practice_back.get_path_to(last)
	practice_back.focus_next = practice_back.get_path_to(stage_buttons[0])


func _unhandled_input(event: InputEvent) -> void:
	if practice_page.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_practice()


func _show_main() -> void:
	practice_page.hide()
	main_page.show()
	var summary := campaign.resume_label()
	continue_button.disabled = summary.is_empty()
	continue_button.caption = summary.replace("  ·  ", " · ") if not summary.is_empty() else Texts.TITLE_NO_SAVE
	status.text = Texts.TITLE_SAVE_UNREADABLE if campaign.read_failed else ""
	(continue_button if not continue_button.disabled else new_button).grab_focus()


func _show_practice() -> void:
	main_page.hide()
	practice_page.show()
	var items: Array = stage_buttons.duplicate()
	items.append(practice_back)
	_play_intro(items, 0.0)
	practice_page.modulate.a = 0.0
	create_tween().tween_property(practice_page, "modulate:a", 1.0, 0.18)
	stage_buttons[0].grab_focus()


func _close_practice() -> void:
	_show_main()
	_play_intro(menu_items, 0.0)
	practice_button.grab_focus()


func _play_intro(items: Array, delay: float) -> void:
	var tween := create_tween().set_parallel(true)
	for i in items.size():
		items[i].reveal = 0.0
		tween.tween_property(items[i], "reveal", 1.0, 0.42).set_delay(delay + i * 0.07) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_menu_focus() -> void:
	if sound_ready and not loading:
		Audio.play_cue(ui_voices, Audio.MENU_MOVE, -7.0)


func _on_menu_pick() -> void:
	Audio.play_cue(ui_voices, Audio.MENU_SELECT, -4.0)


func _draw_decor() -> void:
	if not main_page.visible:
		return
	var eased := ease(clampf((clock - 0.15) / 0.7, 0.0, 1.0), -2.4)
	var hint_y := size.y - 44.0
	var hx := size.x * 0.055
	hx += MenuTheme.keycap(decor, Vector2(hx, hint_y), "↑↓", Texts.KEY_SELECT, eased) + 22.0
	hx += MenuTheme.keycap(decor, Vector2(hx, hint_y), "Enter", Texts.KEY_CONFIRM, eased) + 22.0
	MenuTheme.keycap(decor, Vector2(hx, hint_y), "Esc", Texts.KEY_PAUSE_IN_PLAY, eased)


func _draw_practice_header() -> void:
	var left := 110.0
	MenuTheme.slant(practice_header, Rect2(left, 62, 30, 4), MenuTheme.ACCENT, 3.0)
	MenuTheme.spaced(practice_header, MenuTheme.display_font(600), Vector2(left + 40, 70), Texts.PRACTICE_EYEBROW, 14, MenuTheme.ACCENT, 4.0)
	practice_header.draw_string(MenuTheme.text_font(700), Vector2(left, 116), Texts.PRACTICE_HEADING, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, MenuTheme.TEXT)
	practice_header.draw_string(MenuTheme.text_font(), Vector2(left, 144), Texts.PRACTICE_NOTE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MenuTheme.MUTED)
	# Which act the focused card belongs to, and where it sits among all stages.
	var focused := 0
	for i in stage_buttons.size():
		if stage_buttons[i].has_focus():
			focused = i
	var right := size.x - left
	var act := Texts.act_label(focused)
	var act_width := MenuTheme.spaced_width(MenuTheme.display_font(600), act, 15, 3.0)
	MenuTheme.spaced(practice_header, MenuTheme.display_font(600), Vector2(right - act_width, 116), act, 15, STAGE_TINT[focused], 3.0)
	for i in stage_buttons.size():
		var dot := Rect2(right - (stage_buttons.size() - i) * 17.0 + (4.0 if i % 3 == 0 else 0.0) - 4.0, 132, 11, 5)
		MenuTheme.slant(practice_header, dot, STAGE_TINT[i] if i == focused else Color(MenuTheme.DIM, 0.7), 3.0)
	var y := size.y - 44.0
	var x := left
	x += MenuTheme.keycap(practice_header, Vector2(x, y), "← →", Texts.PRACTICE_KEY_STAGES) + 22.0
	x += MenuTheme.keycap(practice_header, Vector2(x, y), "Enter", Texts.PRACTICE_KEY_START) + 22.0
	MenuTheme.keycap(practice_header, Vector2(x, y), "Esc", Texts.PRACTICE_BACK)


func _confirm_start() -> void:
	if campaign.resume_snapshot().is_empty():
		_new_game()
	else:
		confirm_new.popup_centered(Vector2i(500, 190))
		confirm_new.get_cancel_button().grab_focus()


func _new_game() -> void:
	_queue_launch(0, CampaignStore.Mode.CAMPAIGN, campaign.entry_snapshot(0, 0))


func _continue_game() -> void:
	var snapshot := campaign.resume_snapshot()
	if not snapshot.is_empty():
		_queue_launch(snapshot["stage"], CampaignStore.Mode.CAMPAIGN, snapshot)


func _start_practice(index: int) -> void:
	_queue_launch(index, CampaignStore.Mode.PRACTICE, campaign.entry_snapshot(index, 0))


func _queue_launch(index: int, mode: CampaignStore.Mode, snapshot: Dictionary) -> void:
	if loading:
		return
	loading = true
	_launch.call_deferred(index, mode, snapshot)


func _launch(index: int, mode: CampaignStore.Mode, snapshot: Dictionary) -> void:
	await Audio.drain(self)
	var error := campaign.open_stage(index, mode, snapshot)
	if error != OK:
		loading = false
		Audio.resume_rooms(self)
		_show_main()
		status.text = Texts.TITLE_CANNOT_OPEN
