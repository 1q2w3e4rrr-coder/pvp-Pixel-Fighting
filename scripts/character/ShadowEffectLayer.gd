extends Node2D

# Runtime implementation of original BVN ShadowEffectView.
# Original references:
# - FighterEffectCtrler.shadow(r,g,b) -> EffectCtrler.startShadow(targetDisplay,r,g,b)
# - FighterEffectCtrler.endShadow() -> EffectCtrler.endShadow(targetDisplay)
# - ShadowEffectView: alphaStart=0.8, alphaLose=0.1 per render, addBpGap=1.
# This layer snapshots the current fighter Sprite2D at runtime; it does not generate or save image assets.

const ORIGINAL_FPS: float = 30.0
const SHADOW_ALPHA_START: float = 0.8
const SHADOW_ALPHA_LOSE_PER_FRAME: float = 0.1
const SHADOW_ADD_GAP_FRAMES: int = 1

var target: Node = null
var stop_shadow: bool = true
var r_offset: float = 0.0
var g_offset: float = 0.0
var b_offset: float = 0.0
var add_frame_counter: int = 0
var frame_accum: float = 0.0
var original_time_scale: float = 1.0
var shadows: Array[Sprite2D] = []
var shadow_shader: Shader


func _ready() -> void:
	set_process(true)


func set_original_time_scale(value: float) -> void:
	original_time_scale = clampf(value, 0.01, 4.0)


func start_shadow(new_target: Node, r: int = 0, g: int = 0, b: int = 0) -> void:
	# EffectCtrler.startShadow(): if an existing ShadowEffectView exists for target,
	# update r/g/b and set stopShadow=false instead of recreating it.
	target = new_target
	r_offset = float(r) / 255.0
	g_offset = float(g) / 255.0
	b_offset = float(b) / 255.0
	stop_shadow = false
	add_frame_counter = 0
	frame_accum = 0.0


func end_shadow() -> void:
	# Original endShadow() only sets stopShadow=true; existing bitmaps continue fading out.
	stop_shadow = true


func force_clear() -> void:
	for shadow: Sprite2D in shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()
	shadows.clear()
	target = null
	stop_shadow = true
	add_frame_counter = 0
	frame_accum = 0.0


func _process(delta: float) -> void:
	frame_accum += delta * ORIGINAL_FPS * original_time_scale
	while frame_accum >= 1.0:
		frame_accum -= 1.0
		_original_render_step()


func _original_render_step() -> void:
	if stop_shadow:
		if shadows.is_empty():
			target = null
	else:
		add_frame_counter += 1
		if add_frame_counter > SHADOW_ADD_GAP_FRAMES:
			_add_shadow_snapshot()
			add_frame_counter = 0

	var alpha_loss: float = SHADOW_ALPHA_LOSE_PER_FRAME
	for i: int in range(shadows.size() - 1, -1, -1):
		var shadow: Sprite2D = shadows[i]
		if not is_instance_valid(shadow):
			shadows.remove_at(i)
			continue
		shadow.modulate.a -= alpha_loss
		if shadow.modulate.a <= 0.0:
			shadows.remove_at(i)
			shadow.queue_free()


func _add_shadow_snapshot() -> void:
	if target == null or not is_instance_valid(target):
		return

	var sprite_value: Variant = target.get("sprite")
	if sprite_value == null or not (sprite_value is Sprite2D):
		return
	var src_sprite: Sprite2D = sprite_value as Sprite2D
	if src_sprite.texture == null:
		return

	var ghost := Sprite2D.new()
	ghost.name = "OriginalShadowSnapshot"
	ghost.texture = src_sprite.texture
	ghost.centered = src_sprite.centered
	ghost.offset = src_sprite.offset
	ghost.flip_h = src_sprite.flip_h
	ghost.flip_v = src_sprite.flip_v
	ghost.scale = target.scale * src_sprite.scale
	ghost.rotation = target.rotation + src_sprite.rotation
	ghost.position = target.position + src_sprite.position * target.scale
	ghost.z_index = -1
	ghost.texture_filter = src_sprite.texture_filter
	ghost.modulate = Color(1.0, 1.0, 1.0, SHADOW_ALPHA_START)
	ghost.material = _make_shadow_material()
	add_child(ghost)
	shadows.append(ghost)


func _make_shadow_material() -> ShaderMaterial:
	if shadow_shader == null:
		shadow_shader = Shader.new()
		shadow_shader.code = """
shader_type canvas_item;
uniform vec3 add_color = vec3(0.0, 0.0, 0.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	tex.rgb = clamp(tex.rgb + add_color * tex.a, vec3(0.0), vec3(1.0));
	tex.a *= COLOR.a;
	COLOR = tex;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shadow_shader
	mat.set_shader_parameter("add_color", Vector3(r_offset, g_offset, b_offset))
	return mat
