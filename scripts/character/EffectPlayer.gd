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
var original_time_scale: float = 1.0

var additive_material: Material


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

	additive_material = _create_original_flash_add_material()


func _create_original_flash_add_material() -> ShaderMaterial:
	# 原版 EffectView.as：display.blendMode = data.blendMode，XG_bs / XG_cbs 等使用 BlendMode.ADD。
	# Godot 的普通 ADD 对当前预渲染 PNG 的低 alpha 边缘会过曝；用 alpha 预乘近似 Flash 光效合成。
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float alpha_cutoff = 0.010;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a <= alpha_cutoff) {
		discard;
	}
	tex.rgb *= tex.a;
	COLOR = tex;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("alpha_cutoff", 0.010)
	return mat


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


func _effect_vector2(effect: Dictionary, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = effect.get(key, null)
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func _apply_effect_registration(effect: Dictionary) -> void:
	# 原版 Flash MovieClip 有注册点；FFDec 展平 PNG 只有透明画布。
	# 每个 effect 的 visual_offset 记录“原版 attacker 原点 -> 当前 PNG 画布中心”的补偿，
	# 由 aizen_effect_manifest.json 提供，避免把 bsmc/zh3mc 的视觉修正硬编码在战斗逻辑中。
	ensure_sprite()
	var visual_offset: Vector2 = _effect_vector2(effect, "visual_offset", Vector2.ZERO)
	if bool(effect.get("visual_offset_mirrors_with_facing", false)):
		visual_offset.x *= float(facing)
	sprite.position = visual_offset


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


func set_original_time_scale(value: float) -> void:
	original_time_scale = clampf(value, 0.01, 4.0)


func stop_effect() -> void:
	playing = false
	visible = false
	current_effect = ""
	if sprite != null:
		sprite.texture = null
		sprite.material = null
		sprite.position = Vector2.ZERO


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

	frame_timer += delta * original_time_scale

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


func _use_original_smooth_filter(effect_name: String) -> bool:
	# 原版 Flash 对 XG_bs / XG_cbs 这类位图光效会进行平滑/ADD 混合；Godot NEAREST 会放大白色边缘块。
	# 角色动作仍由 ManifestFighter 保持 NEAREST，这里只影响 EffectPlayer 播放的独立特效。
	return effect_name == "xg_bs" or effect_name == "xg_cbs" or effect_name.begins_with("xg_")


func update_frame() -> void:
	var effect = manifest["effects"][current_effect]
	var frames: Array = effect.get("frames", [])

	if frame_index < 0 or frame_index >= frames.size():
		return

	var rel_path: String = str(frames[frame_index])
	var full_path: String = "res://assets/characters/aizen/" + rel_path

	var tex: Texture2D = load(full_path)

	if tex == null:
		push_warning("Cannot load effect frame: " + full_path)
		return

	ensure_sprite()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _use_original_smooth_filter(current_effect) else CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = tex
	sprite.flip_h = facing < 0
	_apply_effect_registration(effect)
