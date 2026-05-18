extends Control

var characters := [
	{"id": "aizen", "name": "Aizen", "face": "res://assets/face/aizen.png"},
	{"id": "naruto", "name": "Naruto", "face": "res://assets/face/naruto.png"},
	{"id": "sasuke", "name": "Sasuke", "face": "res://assets/face/sasuke.png"},
	{"id": "ichigo", "name": "Ichigo", "face": "res://assets/face/ichigo.png"},
	{"id": "pain", "name": "Pain", "face": "res://assets/face/pain.png"}
]

var cursor_index: int = 0
var p1_selected: int = -1
var p2_selected: int = -1
var selecting_player: int = 1

var info_label: Label
var item_nodes: Array = []


func _ready() -> void:
	print("CharacterSelect ready")
	AudioManager.play_music("res://assets/bgm/select.mp3")
	create_ui()
	refresh_ui()


func create_ui() -> void:
	var screen_size: Vector2 = get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 1.0)
	bg.position = Vector2.ZERO
	bg.size = screen_size
	add_child(bg)

	var title := Label.new()
	title.text = "SELECT FIGHTER"
	title.position = Vector2(0, 34)
	title.size = Vector2(screen_size.x, 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(title)

	info_label = Label.new()
	info_label.position = Vector2(0, 92)
	info_label.size = Vector2(screen_size.x, 36)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(info_label)

	var start_x: int = 80
	var start_y: int = 215
	var gap_x: int = 140

	for i in range(characters.size()):
		var index: int = i

		var panel := PanelContainer.new()
		panel.position = Vector2(start_x + i * gap_x, start_y)
		panel.size = Vector2(110, 140)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)

		panel.mouse_entered.connect(func():
			if cursor_index != index:
				cursor_index = index
				AudioManager.snd_select()
				refresh_ui()
		)

		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mouse_event := event as InputEventMouseButton
				if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
					cursor_index = index
					AudioManager.snd_confirm()
					refresh_ui()
					confirm_selection()
		)

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)

		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(82, 82)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var tex = load(String(characters[i]["face"]))
		if tex != null:
			face.texture = tex
		else:
			print("Missing face: ", characters[i]["face"])

		box.add_child(face)

		var name_label := Label.new()
		name_label.text = String(characters[i]["name"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		box.add_child(name_label)

		item_nodes.append(panel)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_right"):
		cursor_index = (cursor_index + 1) % characters.size()
		AudioManager.snd_select()
		refresh_ui()

	if Input.is_action_just_pressed("ui_left"):
		cursor_index -= 1
		if cursor_index < 0:
			cursor_index = characters.size() - 1

		AudioManager.snd_select()
		refresh_ui()

	if Input.is_action_just_pressed("ui_down"):
		cursor_index = (cursor_index + 5) % characters.size()
		AudioManager.snd_select()
		refresh_ui()

	if Input.is_action_just_pressed("ui_up"):
		cursor_index -= 5
		while cursor_index < 0:
			cursor_index += characters.size()

		AudioManager.snd_select()
		refresh_ui()

	if Input.is_action_just_pressed("ui_accept"):
		AudioManager.snd_confirm()
		confirm_selection()


func confirm_selection() -> void:
	if selecting_player == 1:
		p1_selected = cursor_index
		selecting_player = 2
		refresh_ui()
		return

	if selecting_player == 2:
		p2_selected = cursor_index

		GameData.p1_character = String(characters[p1_selected]["id"])
		GameData.p2_character = String(characters[p2_selected]["id"])

		get_tree().change_scene_to_file("res://scenes/ui/LoadingScene.tscn")


func refresh_ui() -> void:
	for i in range(item_nodes.size()):
		var panel: PanelContainer = item_nodes[i]

		if i == cursor_index:
			panel.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			panel.modulate = Color(0.55, 0.55, 0.55, 1.0)

		if i == p1_selected:
			panel.modulate = Color(1.0, 0.35, 0.35, 1.0)

		if i == p2_selected:
			panel.modulate = Color(0.35, 0.85, 1.0, 1.0)

	var player_text: String = "P1 SELECTING" if selecting_player == 1 else "P2 SELECTING"
	var current_name: String = String(characters[cursor_index]["name"])

	info_label.text = player_text + "    Current: " + current_name
