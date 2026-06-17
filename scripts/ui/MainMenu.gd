extends Control

var bg_rect: TextureRect
var prompt_label: Label
var menu_box: VBoxContainer

var overlay_root: Control
var volume_panel: Panel
var combo_panel: Panel
var volume_slider: HSlider
var volume_percent_label: Label

var title_frames: Array = []
var frame_index: int = 0
var frame_timer: float = 0.0
var fps: float = 30.0

var state: String = "intro"
var menu_index: int = 0
var loop_dir: int = -1

const TITLE_DIR: String = "res://assets/ui/title/stg_title_game/"

const INTRO_START_FRAME: int = 1
const INTRO_END_FRAME: int = 60

const HOLD_LOOP_MIN_FRAME: int = 45
const HOLD_LOOP_MAX_FRAME: int = 60

const MENU_TRANS_START_FRAME: int = 60
const MENU_TRANS_END_FRAME: int = 90

const MENU_ITEM_CLASSIC_2P: String = "经典2p对战"
const MENU_ITEM_VOLUME: String = "音量"
const MENU_ITEM_COMBOS: String = "技能连招表"

var menu_items := [
	MENU_ITEM_CLASSIC_2P,
	MENU_ITEM_VOLUME,
	MENU_ITEM_COMBOS
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioManager.play_music("res://assets/bgm/op.mp3")
	load_title_frames()
	create_ui()
	start_intro()


func load_title_frames() -> void:
	title_frames.clear()

	var dir := DirAccess.open(TITLE_DIR)

	if dir == null:
		push_error("找不到主菜单动画文件夹: " + TITLE_DIR)
		return

	var files: Array = []

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.to_lower().ends_with(".png"):
				files.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	files.sort_custom(func(a, b):
		return extract_number(String(a)) < extract_number(String(b))
	)

	for f in files:
		var path: String = TITLE_DIR + String(f)
		var tex: Texture2D = load(path)

		if tex != null:
			title_frames.append(tex)
		else:
			push_warning("无法加载主菜单帧: " + path)

	print("Loaded title frames: ", title_frames.size())


func extract_number(file_name: String) -> int:
	var text: String = file_name.get_basename()
	var num: String = ""

	for c in text:
		if c >= "0" and c <= "9":
			num += c

	if num == "":
		return 0

	return int(num)


func create_ui() -> void:
	for child in get_children():
		child.queue_free()

	var screen_size: Vector2 = get_viewport_rect().size

	position = Vector2.ZERO
	size = screen_size
	set_anchors_preset(Control.PRESET_FULL_RECT)

	bg_rect = TextureRect.new()
	bg_rect.position = Vector2.ZERO
	bg_rect.size = screen_size
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	prompt_label = Label.new()
	prompt_label.text = "点击屏幕任意处开始"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 28)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.15, 1.0))
	prompt_label.position = Vector2(0, screen_size.y - 88)
	prompt_label.size = Vector2(screen_size.x, 42)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_label)

	create_menu()
	create_menu_overlay()


func create_menu() -> void:
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(206, 212)
	menu_box.size = Vector2(430, 255)
	menu_box.add_theme_constant_override("separation", 14)
	menu_box.visible = true
	menu_box.modulate.a = 0.0
	add_child(menu_box)

	for i in range(menu_items.size()):
		var index: int = i

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(388, 72)
		btn.focus_mode = Control.FOCUS_ALL

		# 原版逻辑：
		# 默认只有黄字，不显示底图；鼠标悬停/键盘选中：黄底；确认：蓝底。
		btn.texture_normal = null
		btn.texture_hover = load("res://assets/ui/common/menu_btn_normal.png")
		btn.texture_pressed = load("res://assets/ui/common/menu_btn_selected.png")
		btn.texture_focused = load("res://assets/ui/common/menu_btn_normal.png")
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		btn.mouse_entered.connect(func():
			if state == "menu":
				if menu_index != index:
					menu_index = index
					AudioManager.snd_select()
					refresh_menu()
		)

		btn.pressed.connect(func():
			if state == "menu":
				menu_index = index
				AudioManager.snd_confirm()
				refresh_menu_pressed(index)
				call_deferred("activate_menu_item")
		)

		var label := Label.new()
		label.name = "Text"
		label.text = String(menu_items[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(0, 6)
		label.size = Vector2(388, 55)
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.12, 1.0))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		btn.add_child(label)
		menu_box.add_child(btn)

	refresh_menu()


func create_menu_overlay() -> void:
	overlay_root = Control.new()
	overlay_root.name = "MainMenuOverlayRoot"
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.z_index = 900
	overlay_root.visible = false
	add_child(overlay_root)

	var dim := ColorRect.new()
	dim.name = "MainMenuOverlayDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.50)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(dim)

	volume_panel = create_volume_panel()
	volume_panel.visible = false
	overlay_root.add_child(volume_panel)

	combo_panel = create_combo_panel()
	combo_panel.visible = false
	overlay_root.add_child(combo_panel)


func create_panel(panel_name: String, panel_position: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.015, 0.02, 0.84)
	style.border_color = Color(1.0, 0.88, 0.28, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func create_volume_panel() -> Panel:
	var panel := create_panel("MainMenuVolumePanel", Vector2(145, 128), Vector2(510, 260))
	var back := create_back_button()
	back.pressed.connect(Callable(self, "_on_overlay_back_pressed"))
	panel.add_child(back)

	var title := Label.new()
	title.position = Vector2(64, 20)
	title.size = Vector2(382, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.36, 1.0))
	title.text = "音量"
	panel.add_child(title)

	var speaker := Label.new()
	speaker.name = "SpeakerIcon"
	speaker.position = Vector2(64, 112)
	speaker.size = Vector2(56, 48)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker.add_theme_font_size_override("font_size", 32)
	speaker.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	speaker.text = "🔊"
	panel.add_child(speaker)

	volume_slider = HSlider.new()
	volume_slider.name = "MasterVolumeSlider"
	volume_slider.position = Vector2(132, 122)
	volume_slider.size = Vector2(250, 32)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = get_master_volume_percent()
	volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	volume_slider.value_changed.connect(Callable(self, "_on_volume_value_changed"))
	panel.add_child(volume_slider)

	volume_percent_label = Label.new()
	volume_percent_label.name = "MasterVolumePercent"
	volume_percent_label.position = Vector2(392, 119)
	volume_percent_label.size = Vector2(68, 34)
	volume_percent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	volume_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	volume_percent_label.add_theme_font_size_override("font_size", 20)
	volume_percent_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	panel.add_child(volume_percent_label)
	update_volume_label()

	var hint := Label.new()
	hint.position = Vector2(76, 176)
	hint.size = Vector2(360, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0, 0.95))
	hint.text = "拖动滑块调整整体音乐和音效音量"
	panel.add_child(hint)
	return panel


func create_combo_panel() -> Panel:
	var panel := create_panel("MainMenuComboPanel", Vector2(42, 42), Vector2(716, 516))
	var back := create_back_button()
	back.pressed.connect(Callable(self, "_on_overlay_back_pressed"))
	panel.add_child(back)

	var title := Label.new()
	title.position = Vector2(70, 18)
	title.size = Vector2(576, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.36, 1.0))
	title.text = "技能连招表"
	panel.add_child(title)

	var split := ColorRect.new()
	split.position = Vector2(357, 72)
	split.size = Vector2(2, 405)
	split.color = Color(1.0, 0.9, 0.35, 0.35)
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(split)

	var p1_head := create_combo_header("P1", Vector2(68, 70), Vector2(260, 28))
	panel.add_child(p1_head)
	var p2_head := create_combo_header("P2", Vector2(388, 70), Vector2(260, 28))
	panel.add_child(p2_head)

	var p1_text := Label.new()
	p1_text.position = Vector2(70, 106)
	p1_text.size = Vector2(272, 380)
	p1_text.add_theme_font_size_override("font_size", 15)
	p1_text.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	p1_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p1_text.text = get_combo_text_p1()
	panel.add_child(p1_text)

	var p2_text := Label.new()
	p2_text.position = Vector2(390, 106)
	p2_text.size = Vector2(272, 380)
	p2_text.add_theme_font_size_override("font_size", 15)
	p2_text.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	p2_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p2_text.text = get_combo_text_p2()
	panel.add_child(p2_text)
	return panel


func create_combo_header(text_value: String, pos: Vector2, size_value: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.36, 1.0))
	label.text = text_value
	return label


func create_overlay_button(text_value: String, pos: Vector2, size_value: Vector2) -> Button:
	var btn := Button.new()
	btn.name = "MainMenuOverlayButton_" + text_value
	btn.text = text_value
	btn.position = pos
	btn.size = size_value
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.36, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.65, 0.9, 1.0, 1.0))
	btn.add_theme_constant_override("h_separation", 10)
	btn.add_theme_stylebox_override("normal", make_overlay_button_style(Color(0.07, 0.08, 0.10, 0.70), Color(0.55, 0.55, 0.60, 0.70)))
	btn.add_theme_stylebox_override("hover", make_overlay_button_style(Color(0.12, 0.12, 0.14, 0.88), Color(1.0, 0.95, 0.65, 0.95)))
	btn.add_theme_stylebox_override("pressed", make_overlay_button_style(Color(0.08, 0.16, 0.24, 0.92), Color(0.65, 0.9, 1.0, 1.0)))
	btn.mouse_entered.connect(Callable(self, "_play_menu_hover_sfx"))
	btn.focus_entered.connect(Callable(self, "_play_menu_hover_sfx"))
	return btn


func create_back_button() -> Button:
	var btn := create_overlay_button("←", Vector2(18, 16), Vector2(42, 34))
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 24)
	return btn


func make_overlay_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 8.0
	return style


func start_intro() -> void:
	state = "intro"
	frame_index = INTRO_START_FRAME - 1
	frame_timer = 0.0
	loop_dir = 1
	menu_index = 0

	if overlay_root != null:
		overlay_root.visible = false
	if volume_panel != null:
		volume_panel.visible = false
	if combo_panel != null:
		combo_panel.visible = false

	if not title_frames.is_empty():
		bg_rect.texture = title_frames[frame_index]

	if prompt_label != null:
		prompt_label.visible = true
		prompt_label.modulate.a = 0.0

	if menu_box != null:
		menu_box.modulate.a = 0.0

	refresh_menu()


func _process(delta: float) -> void:
	if state == "intro":
		update_intro(delta)

	elif state == "hold_loop":
		update_hold_loop(delta)
		update_prompt()
		handle_start_input()

	elif state == "transition":
		update_transition(delta)

	elif state == "menu":
		handle_menu_input()

	elif state == "volume" or state == "combos":
		handle_overlay_input()


func _input(event: InputEvent) -> void:
	# 兜底监听标题页全屏鼠标左键点击。
	# 原来的 _gui_input 在大多数情况下能收到 Control 点击，
	# 这里再加 _input，避免点击落到子节点/窗口焦点导致标题页无法响应。
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if try_start_from_title_click():
				get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	# 保留 Control GUI 输入入口，鼠标左键点击标题页任意位置也能开始。
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if try_start_from_title_click():
				accept_event()


func try_start_from_title_click() -> bool:
	if state == "intro" or state == "hold_loop":
		start_menu_transition()
		return true
	return false


func update_intro(delta: float) -> void:
	if title_frames.is_empty():
		return

	frame_timer += delta
	var frame_duration: float = 1.0 / fps

	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		frame_index += 1

		if frame_index >= INTRO_END_FRAME - 1:
			frame_index = INTRO_END_FRAME - 1
			state = "hold_loop"
			loop_dir = -1
			break

	bg_rect.texture = title_frames[frame_index]


func update_hold_loop(delta: float) -> void:
	if title_frames.is_empty():
		return

	frame_timer += delta
	var frame_duration: float = 1.0 / fps

	while frame_timer >= frame_duration:
		frame_timer -= frame_duration

		frame_index += loop_dir

		if frame_index <= HOLD_LOOP_MIN_FRAME - 1:
			frame_index = HOLD_LOOP_MIN_FRAME - 1
			loop_dir = 1

		elif frame_index >= HOLD_LOOP_MAX_FRAME - 1:
			frame_index = HOLD_LOOP_MAX_FRAME - 1
			loop_dir = -1

	bg_rect.texture = title_frames[frame_index]


func update_prompt() -> void:
	if prompt_label == null:
		return

	var t: float = Time.get_ticks_msec() / 1000.0
	prompt_label.modulate.a = 0.35 + 0.65 * abs(sin(t * 3.0))


func handle_start_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		start_menu_transition()


func start_menu_transition() -> void:
	AudioManager.snd_menu_open()

	state = "transition"
	frame_index = MENU_TRANS_START_FRAME - 1
	frame_timer = 0.0

	if prompt_label != null:
		prompt_label.visible = false

	if menu_box != null:
		menu_box.visible = true
		menu_box.modulate.a = 0.0

	if overlay_root != null:
		overlay_root.visible = false

	if not title_frames.is_empty():
		bg_rect.texture = title_frames[frame_index]

	refresh_menu()


func update_transition(delta: float) -> void:
	if title_frames.is_empty():
		return

	frame_timer += delta
	var frame_duration: float = 1.0 / fps

	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		frame_index += 1

		if frame_index >= MENU_TRANS_END_FRAME - 1:
			frame_index = MENU_TRANS_END_FRAME - 1
			state = "menu"

		bg_rect.texture = title_frames[frame_index]

	update_menu_fade()


func update_menu_fade() -> void:
	if menu_box == null:
		return

	var start_index: int = MENU_TRANS_START_FRAME - 1
	var end_index: int = MENU_TRANS_END_FRAME - 1
	var progress: float = float(frame_index - start_index) / float(end_index - start_index)

	progress = clamp(progress, 0.0, 1.0)

	# 后半段逐渐出现，更接近原版按钮进入效果。
	menu_box.modulate.a = clamp((progress - 0.35) / 0.65, 0.0, 1.0)


func handle_menu_input() -> void:
	if Input.is_action_just_pressed("ui_down"):
		menu_index += 1
		if menu_index >= menu_items.size():
			menu_index = 0

		AudioManager.snd_select()
		refresh_menu()

	if Input.is_action_just_pressed("ui_up"):
		menu_index -= 1
		if menu_index < 0:
			menu_index = menu_items.size() - 1

		AudioManager.snd_select()
		refresh_menu()

	if Input.is_action_just_pressed("ui_accept"):
		AudioManager.snd_confirm()
		refresh_menu_pressed(menu_index)
		activate_menu_item()

	if Input.is_action_just_pressed("ui_cancel"):
		AudioManager.snd_confirm()
		start_intro()


func handle_overlay_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_overlay_back_pressed()


func refresh_menu() -> void:
	if menu_box == null:
		return

	for i in range(menu_box.get_child_count()):
		var btn := menu_box.get_child(i) as TextureButton
		var label := btn.get_node("Text") as Label

		if i == menu_index:
			# 鼠标悬停 / 键盘选中：黄底。
			btn.texture_normal = load("res://assets/ui/common/menu_btn_normal.png")
			label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.12, 1.0))
			label.modulate = Color(1.15, 1.15, 1.15, 1.0)
		else:
			# 默认：无底图，只有黄字。
			btn.texture_normal = null
			label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.12, 1.0))
			label.modulate = Color(0.9, 0.9, 0.9, 1.0)


func refresh_menu_pressed(index: int) -> void:
	if menu_box == null:
		return

	for i in range(menu_box.get_child_count()):
		var btn := menu_box.get_child(i) as TextureButton
		var label := btn.get_node("Text") as Label

		if i == index:
			# 确认瞬间：蓝底。
			btn.texture_normal = load("res://assets/ui/common/menu_btn_selected.png")
			label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			label.modulate = Color(1.25, 1.25, 1.25, 1.0)
		elif i == menu_index:
			btn.texture_normal = load("res://assets/ui/common/menu_btn_normal.png")
			label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.12, 1.0))
			label.modulate = Color(1.15, 1.15, 1.15, 1.0)
		else:
			btn.texture_normal = null
			label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.12, 1.0))
			label.modulate = Color(0.9, 0.9, 0.9, 1.0)


func activate_menu_item() -> void:
	var item: String = String(menu_items[menu_index])

	if item == MENU_ITEM_CLASSIC_2P:
		get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")
	elif item == MENU_ITEM_VOLUME:
		show_volume_panel()
	elif item == MENU_ITEM_COMBOS:
		show_combo_panel()
	else:
		print("Menu item not implemented yet: ", item)


func show_volume_panel() -> void:
	state = "volume"
	if overlay_root != null:
		overlay_root.visible = true
	if volume_panel != null:
		volume_panel.visible = true
	if combo_panel != null:
		combo_panel.visible = false
	if volume_slider != null:
		volume_slider.value = get_master_volume_percent()
	update_volume_label()


func show_combo_panel() -> void:
	state = "combos"
	if overlay_root != null:
		overlay_root.visible = true
	if volume_panel != null:
		volume_panel.visible = false
	if combo_panel != null:
		combo_panel.visible = true


func return_to_main_menu_options() -> void:
	state = "menu"
	if overlay_root != null:
		overlay_root.visible = false
	if volume_panel != null:
		volume_panel.visible = false
	if combo_panel != null:
		combo_panel.visible = false
	refresh_menu()


func _on_overlay_back_pressed() -> void:
	_play_menu_confirm_sfx()
	return_to_main_menu_options()


func _on_volume_value_changed(value: float) -> void:
	if AudioManager != null and AudioManager.has_method("set_master_volume_percent"):
		AudioManager.call("set_master_volume_percent", value)
	else:
		apply_master_volume_percent(value)
	update_volume_label()


func get_master_volume_percent() -> float:
	if AudioManager != null and AudioManager.has_method("get_master_volume_percent"):
		return float(AudioManager.call("get_master_volume_percent"))
	return 100.0


func apply_master_volume_percent(value: float) -> void:
	var v: float = clampf(value, 0.0, 100.0)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		bus_idx = 0
	if v <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v / 100.0))


func update_volume_label() -> void:
	if volume_percent_label == null:
		return
	var value: float = get_master_volume_percent()
	if volume_slider != null:
		value = float(volume_slider.value)
	volume_percent_label.text = str(int(round(value))) + "%"


func _play_menu_hover_sfx() -> void:
	if AudioManager != null and AudioManager.has_method("snd_select"):
		AudioManager.call("snd_select")


func _play_menu_confirm_sfx() -> void:
	if AudioManager != null and AudioManager.has_method("snd_confirm"):
		AudioManager.call("snd_confirm")


func get_combo_text_p1() -> String:
	return "" + \
		"移动：A / D\n" + \
		"方向：W 上，S 下\n" + \
		"J：普攻，可连续 J 连段\n" + \
		"S + J：砍技1 / 反击准备\n" + \
		"W + J：砍技2\n" + \
		"K：跳跃\n" + \
		"L：瞬步 / dash\n" + \
		"U：招1\n" + \
		"S + U：招2\n" + \
		"W + U：招3\n" + \
		"I：普通必杀，消耗 100 怒气\n" + \
		"W + I：上必杀，消耗 100 怒气\n" + \
		"S + I：超必杀，消耗 300 怒气\n" + \
		"空中 J：跳砍\n" + \
		"空中 U：跳招\n" + \
		"空中 I：空中必杀\n" + \
		"O：支援 / 换人（当前暂未接入）"


func get_combo_text_p2() -> String:
	return "" + \
		"移动：← / →\n" + \
		"方向：↑ 上，↓ 下\n" + \
		"Num1：普攻，可连续 Num1 连段\n" + \
		"↓ + Num1：砍技1 / 反击准备\n" + \
		"↑ + Num1：砍技2\n" + \
		"Num2：跳跃\n" + \
		"Num3：瞬步 / dash\n" + \
		"Num4：招1\n" + \
		"↓ + Num4：招2\n" + \
		"↑ + Num4：招3\n" + \
		"Num5：普通必杀，消耗 100 怒气\n" + \
		"↑ + Num5：上必杀，消耗 100 怒气\n" + \
		"↓ + Num5：超必杀，消耗 300 怒气\n" + \
		"空中 Num1：跳砍\n" + \
		"空中 Num4：跳招\n" + \
		"空中 Num5：空中必杀\n" + \
		"Num6：支援 / 换人（当前暂未接入）"
