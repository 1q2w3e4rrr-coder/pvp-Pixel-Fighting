extends Control

var bg_rect: TextureRect
var prompt_label: Label
var menu_box: VBoxContainer

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

var menu_items := [
	"TEAM PLAY",
	"SINGLE PLAY",
	"MUSOU PLAY",
	"SETTINGS",
	"TRAINING",
	"CREDITS"
]


func _ready() -> void:
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
	add_child(bg_rect)

	prompt_label = Label.new()
	prompt_label.text = "PRESS ENTER"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 28)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.15, 1.0))
	prompt_label.position = Vector2(0, screen_size.y - 86)
	prompt_label.size = Vector2(screen_size.x, 40)
	add_child(prompt_label)

	create_menu()


func create_menu() -> void:
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(245, 135)
	menu_box.size = Vector2(430, 430)
	menu_box.add_theme_constant_override("separation", 8)
	menu_box.visible = true
	menu_box.modulate.a = 0.0
	add_child(menu_box)

	for i in range(menu_items.size()):
		var index: int = i

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(388, 72)

		# 原版逻辑：
		# 默认只有黄字，不显示底图
		# 鼠标悬停 / 键盘选中：黄底
		# 鼠标点击 / Enter 确认：蓝底
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


func start_intro() -> void:
	state = "intro"
	frame_index = INTRO_START_FRAME - 1
	frame_timer = 0.0
	loop_dir = 1
	menu_index = 0

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
		handle_enter_to_menu()

	elif state == "transition":
		update_transition(delta)

	elif state == "menu":
		handle_menu_input()


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


func handle_enter_to_menu() -> void:
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

	# 后半段逐渐出现，更接近原版按钮进入效果
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


func refresh_menu() -> void:
	if menu_box == null:
		return

	for i in range(menu_box.get_child_count()):
		var btn := menu_box.get_child(i) as TextureButton
		var label := btn.get_node("Text") as Label

		if i == menu_index:
			# 鼠标悬停 / 键盘选中：黄底
			btn.texture_normal = load("res://assets/ui/common/menu_btn_normal.png")
			label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.12, 1.0))
			label.modulate = Color(1.15, 1.15, 1.15, 1.0)
		else:
			# 默认：无底图，只有黄字
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
			# 确认瞬间：蓝底
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

	match item:
		"TEAM PLAY":
			get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")
		"SINGLE PLAY":
			get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")
		"TRAINING":
			get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")
		_:
			print("Menu item not implemented yet: ", item)
