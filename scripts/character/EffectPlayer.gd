extends Node2D

var sprite: Sprite2D

var manifest_path: String = ""
var manifest: Dictionary = {}

var current_effect: String = ""
var frame_index: int = 0
var frame_timer: float = 0.0
var fps: float = 30.0

var playing: bool = false
var facing: int = 1

var additive_material: CanvasItemMaterial


func setup(path: String) -> void:
	manifest_path = path
	ensure_sprite()
	load_manifest()
	visible = false


func ensure_sprite() -> void:
	if sprite != null:
		return

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	additive_material = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func load_manifest() -> void:
	var file := FileAccess.open(manifest_path, FileAccess.READ)

	if file == null:
		push_error("Cannot open effect manifest: " + manifest_path)
		return

	var text: String = file.get_as_text()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("Effect manifest parse failed: " + manifest_path)
		return

	manifest = data
	print("Loaded effect manifest:", manifest_path)


func play_effect(effect_name: String, pos: Vector2, new_facing: int = 1, effect_scale: float = 1.0, additive: bool = false) -> void:
	if not manifest.has("effects"):
		return

	if not manifest["effects"].has(effect_name):
		print("Effect not found:", effect_name)
		return

	current_effect = effect_name
	frame_index = 0
	frame_timer = 0.0
	playing = true
	visible = true
	position = pos
	facing = new_facing
	scale = Vector2(effect_scale, effect_scale)
	apply_blend_mode(additive)

	var effect = manifest["effects"][current_effect]
	fps = float(effect.get("fps", 30))
	var frames: Array = effect.get("frames", [])
	print("Play effect:", current_effect, " frames=", frames.size(), " additive=", additive, " pos=", pos)

	update_frame()


func apply_blend_mode(additive: bool) -> void:
	ensure_sprite()

	if additive:
		sprite.material = additive_material
	else:
		sprite.material = null


func stop_effect() -> void:
	playing = false
	visible = false
	current_effect = ""
	if sprite != null:
		sprite.texture = null
		sprite.material = null


func _process(delta: float) -> void:
	if not playing:
		return

	if not manifest.has("effects"):
		return

	if not manifest["effects"].has(current_effect):
		return

	var effect = manifest["effects"][current_effect]
	var frames: Array = effect.get("frames", [])

	if frames.is_empty():
		stop_effect()
		return

	frame_timer += delta

	var frame_duration: float = 1.0 / fps

	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		frame_index += 1

		if frame_index >= frames.size():
			if bool(effect.get("loop", false)):
				frame_index = 0
			else:
				stop_effect()
				return

		update_frame()


func update_frame() -> void:
	var effect = manifest["effects"][current_effect]
	var frames: Array = effect.get("frames", [])

	if frame_index < 0 or frame_index >= frames.size():
		return

	var rel_path: String = String(frames[frame_index])
	var full_path: String = "res://assets/characters/aizen/" + rel_path

	var tex: Texture2D = load(full_path)

	if tex == null:
		push_warning("Cannot load effect frame: " + full_path)
		return

	ensure_sprite()
	sprite.texture = tex
	sprite.flip_h = facing < 0
