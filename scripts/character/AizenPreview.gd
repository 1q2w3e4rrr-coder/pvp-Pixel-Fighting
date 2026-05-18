extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

var manifest: Dictionary = {}
var current_action: String = "idle"
var frame_index: int = 0
var frame_timer: float = 0.0
var fps: float = 30.0

var action_keys := [
	"idle",
	"walk",
	"dash",
	"jump_start",
	"jump",
	"fall",
	"land",
	"jump_attack",
	"atk1",
	"atk2",
	"atk3",
	"atk4_extra",
	"atk5",
	"skill1",
	"skill2",
	"skill3",
	"super",
	"super_up",
	"super_air",
	"super_special",
	"defend",
	"hurt",
	"knock_fly",
	"getup",
	"intro",
	"win",
	"lose"
]

var action_pos: int = 0


func _ready() -> void:
	load_manifest()
	play_action("idle")


func load_manifest() -> void:
	var path := "res://assets/characters/aizen/aizen_godot_action_manifest.json"
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Cannot open manifest: " + path)
		return

	var text := file.get_as_text()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("Manifest JSON parse failed.")
		return

	manifest = data
	print("Loaded Aizen manifest.")
	print("Action count: ", manifest["actions"].size())


func play_action(action_name: String) -> void:
	if not manifest.has("actions"):
		return

	if not manifest["actions"].has(action_name):
		print("Action not found: ", action_name)
		return

	current_action = action_name
	frame_index = 0
	frame_timer = 0.0

	var action = manifest["actions"][current_action]
	fps = float(action.get("fps", 30))

	update_sprite_frame()

	print("Now playing: ", current_action)


func _process(delta: float) -> void:
	handle_input()

	if not manifest.has("actions"):
		return

	if not manifest["actions"].has(current_action):
		return

	var action = manifest["actions"][current_action]
	var frames: Array = action.get("frames", [])

	if frames.is_empty():
		return

	frame_timer += delta

	var frame_duration := 1.0 / fps

	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		frame_index += 1

		if frame_index >= frames.size():
			if bool(action.get("loop", false)):
				frame_index = 0
			else:
				play_action("idle")
				return

		update_sprite_frame()


func handle_input() -> void:
	if Input.is_action_just_pressed("ui_right"):
		next_action()

	if Input.is_action_just_pressed("ui_left"):
		previous_action()

	if Input.is_key_pressed(KEY_A):
		sprite.flip_h = true

	if Input.is_key_pressed(KEY_D):
		sprite.flip_h = false


func next_action() -> void:
	action_pos += 1

	if action_pos >= action_keys.size():
		action_pos = 0

	play_action(action_keys[action_pos])


func previous_action() -> void:
	action_pos -= 1

	if action_pos < 0:
		action_pos = action_keys.size() - 1

	play_action(action_keys[action_pos])


func update_sprite_frame() -> void:
	var action = manifest["actions"][current_action]
	var frames: Array = action.get("frames", [])

	if frame_index < 0 or frame_index >= frames.size():
		return

	var rel_path: String = frames[frame_index]
	var full_path := "res://assets/characters/aizen/" + rel_path

	var tex := load(full_path)

	if tex == null:
		push_warning("Cannot load frame: " + full_path)
		return

	sprite.texture = tex
	sprite.centered = true
	sprite.position = Vector2(0, 180)
