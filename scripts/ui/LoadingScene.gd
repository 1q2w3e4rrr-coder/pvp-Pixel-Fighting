extends Control

var timer: float = 0.0
var loading_label: Label
var info_label: Label


func _ready() -> void:
	AudioManager.play_music("res://assets/bgm/loading.mp3")
	create_ui()


func create_ui() -> void:
	var screen_size: Vector2 = get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.01, 1.0)
	bg.position = Vector2.ZERO
	bg.size = screen_size
	add_child(bg)

	loading_label = Label.new()
	loading_label.text = "LOADING..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 42)
	loading_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	loading_label.position = Vector2(0, 220)
	loading_label.size = Vector2(screen_size.x, 60)
	add_child(loading_label)

	info_label = Label.new()
	info_label.text = GameData.p1_character + "  VS  " + GameData.p2_character
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 26)
	info_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	info_label.position = Vector2(0, 285)
	info_label.size = Vector2(screen_size.x, 40)
	add_child(info_label)


func _process(delta: float) -> void:
	timer += delta

	if timer >= 1.5:
		get_tree().change_scene_to_file("res://scenes/battle/BattlePlaceholder.tscn")
