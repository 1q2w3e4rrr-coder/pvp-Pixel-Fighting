extends Node2D

# 原版 EffectCtrler / EffectModel 的 Godot 侧最小复刻层：
# - doHitEffect(hitvo, hitRect)：按 hitType 查 hit_X 特效
# - doDefenseEffect(hitvo, hitRect)：按 hitType 查 defense_X 特效
# - break_def：破防特效
# 资源来自 OpenBleachVsNaruto/swf_source/assets/effect/effect.xfl。

const MANIFEST_PATH: String = "res://assets/effects/common/common_effect_manifest.json"
const FRAME_BASE: String = "res://assets/effects/common/"

const HIT_EFFECT_BY_TYPE := {
	1: "hit_1", # KAN -> XG_kan
	2: "hit_2", # DA -> XG_qdj
	3: "hit_3", # DA_HEAVY -> XG_qdjx
	4: "hit_4", # MAGIC -> XG_mfdj
	5: "hit_5", # MAGIC_HEAVY -> XG_mfdjx
	6: "hit_6", # KAN_HEAVY -> XG_kanx
	7: "hit_5",
	8: "hit_5",
	9: "electric_hit", # ELECTRIC -> XG_leidian
	11: "catch_hit"
}

const DEFENSE_EFFECT_BY_TYPE := {
	1: "defense_1", # XG_fykan
	2: "defense_2", # XG_fyq
	3: "defense_3", # XG_fyqx
	4: "defense_4", # XG_mffy
	5: "defense_5", # XG_mffyx
	6: "defense_6", # XG_fykanx
	7: "defense_5",
	8: "defense_5",
	9: "defense_5",
	11: "defense_2"
}

# 原版 EffectCtrler.doSteelHitEffect：钢体命中特效不是新贴图，
# 而是 EffectModel.initSteelHitEffect 中复用 XG_kan / XG_qdj / XG_mfdj 三个 linkage，
# 但声音、freeze、shine、randRotate 与普通 hit effect 不同。
const STEEL_EFFECT_BY_TYPE := {
	1: "steel_hit_kan",
	6: "steel_hit_kan",
	2: "steel_hit_qdj",
	3: "steel_hit_qdj"
}

const HIT_SOUND_BY_TYPE := {
	1: "snd_kan1",
	2: "snd_hit2",
	3: "snd_hit_heavy",
	4: "snd_hit2",
	5: "snd_mfdjx",
	6: "snd_kan2",
	7: "snd_hit_fire",
	8: "snd_hit_ice",
	9: "snd_hit_dian",
	11: "snd_hit_cache"
}

const DEF_SOUND_BY_TYPE := {
	1: "snd_fykan",
	2: "snd_def",
	3: "snd_defx",
	4: "snd_def",
	5: "snd_defx",
	6: "snd_fykanx",
	7: "snd_defx",
	8: "snd_defx",
	9: "snd_defx",
	11: "snd_def"
}

var manifest: Dictionary = {}
var active_items: Array[Dictionary] = []
var original_time_scale: float = 1.0
var additive_material: Material
var frame_effect_count: Dictionary = {}
var frame_effect_count_reset_queued: bool = false


func _ready() -> void:
	z_index = 80
	additive_material = _create_original_flash_add_material()
	load_manifest()


func _create_original_flash_add_material() -> ShaderMaterial:
	# 原版依据：EffectView.as 使用 Bitmap.display.blendMode = EffectVO.blendMode；
	# EffectModel.as 中 KAN / KAN_HEAVY / MAGIC 等 common hit 均为 BlendMode.ADD。
	# 当前 Godot 不能直接复刻 Flash 的 BitmapData + ADD 透明合成；CanvasItemMaterial.ADD
	# 会把预渲染 PNG 边缘低 alpha 像素放大成“电视雪花/白色马赛克”。
	# 这里用 shader 先按 alpha 预乘再做 add，并丢弃极低 alpha 边缘，保留原版声音、freeze、shake、shine。
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float alpha_cutoff = 0.012;

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
	mat.set_shader_parameter("alpha_cutoff", 0.012)
	return mat


func set_original_time_scale(value: float) -> void:
	original_time_scale = clampf(value, 0.01, 4.0)


func load_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Common effect manifest not found: " + MANIFEST_PATH)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		manifest = data
	else:
		push_warning("Common effect manifest parse failed: " + MANIFEST_PATH)


func play_hit_effect(hit_vo: Dictionary, hit_rect: Rect2, facing: int = 1) -> void:
	var hit_type: int = int(hit_vo.get("hitType", 0))
	var effect_id: String = str(HIT_EFFECT_BY_TYPE.get(hit_type, "hit_4"))
	var sound_id: String = str(HIT_SOUND_BY_TYPE.get(hit_type, "snd_hit2"))
	# Step49：hitType=9 原版为 XG_leidian，EffectModel.as 指定 blendMode=HARDLIGHT。
	# Godot 当前不使用占位 hit_5；电属性使用从 effect.xfl/mc_029 渲染出的 electric_hit。
	# HARDLIGHT 在当前 CanvasItemMaterial 里没有 1:1 等价项，这里先不套 ADD，保留原始 PNG 透明度；
	# 后续 Step51 的 FlashMovieClipPlayer / shader 再补真正 hardlight 混合。
	var additive: bool = hit_type != 9
	# 原版 EffectModel.as: KAN/KAN_HEAVY/DA/DA_HEAVY/MAGIC/MAGIC_HEAVY 的 common hit 都 randRotate=true。
	# 旧 Godot manifest 部分条目缺失 randRotate，这会让连续 J 的 KAN/KAN_HEAVY 视觉叠在同一角度，
	# 更容易形成“雪花/马赛克”感；这里按原版 HitType 补回。
	var original_rand_rotate: bool = hit_type in [1, 2, 3, 4, 5, 6]
	play_effect(effect_id, hit_rect.get_center(), facing, 1.0, additive, original_rand_rotate)
	AudioManager.play_effect_sfx(sound_id)


func play_defense_effect(hit_vo: Dictionary, hit_rect: Rect2, facing: int = 1) -> void:
	var hit_type: int = int(hit_vo.get("hitType", 0))
	# 原版 HAND 防御遇到 KAN/KAN_HEAVY 会转成 DA/DA_HEAVY；当前蓝染是刀系，先按 SWOARD 处理。
	var effect_id: String = str(DEFENSE_EFFECT_BY_TYPE.get(hit_type, "defense_5"))
	var sound_id: String = str(DEF_SOUND_BY_TYPE.get(hit_type, "snd_def"))
	play_effect(effect_id, hit_rect.get_center(), facing, 1.0, true)
	AudioManager.play_effect_sfx(sound_id)


func play_steel_hit_effect(hit_vo: Dictionary, hit_rect: Rect2, facing: int = 1) -> void:
	# 对照 EffectCtrler.doSteelHitEffect + EffectModel.initSteelHitEffect。
	# hitType=0 原版直接 return，不播放特效。
	var hit_type: int = int(hit_vo.get("hitType", 0))
	if hit_type == 0:
		return
	var effect_id: String = str(STEEL_EFFECT_BY_TYPE.get(hit_type, "steel_hit_mfdj"))
	play_effect(effect_id, hit_rect.get_center(), facing, 1.0, true, true)
	AudioManager.play_effect_sfx("snd_hit_steel")


func play_dash_effect(pos: Vector2, facing: int = 1, is_air: bool = false) -> void:
	# 原版 EffectModel.as:
	#   dash     -> EffectVO("XG_rush",     {sound:"snd_dash_air"})
	#   dash_air -> EffectVO("XG_rush_air", {sound:"snd_dash_air"})
	# 原版 FighterEffectCtrler.dash():
	#   空中 doEffectById("dash_air", x, y, direct)
	#   地面 doEffectById("dash",     x, y, direct)
	var effect_id: String = "dash_air" if is_air else "dash"
	play_effect(effect_id, pos, facing, 1.0, false, false)
	AudioManager.play_effect_sfx("snd_dash_air")


func play_break_defense(hit_rect: Rect2, facing: int = 1) -> void:
	play_effect("break_def", hit_rect.get_center(), facing, 1.0, true)
	AudioManager.play_effect_sfx("snd_mfdjx")


func play_ko_hit_end(pos: Vector2, facing: int = 1) -> void:
	# FightUI.playKO: EffectCtrler.doEffectById("hit_end", loser.x, loser.y).
	# 如果当前资源包尚未导出 xg_hitover/hit_end，则使用已存在的重击魔法效果作为安全 fallback，避免 KO 流程报错。
	var effects: Dictionary = manifest.get("effects", {}) as Dictionary
	if effects.has("hit_end"):
		play_effect("hit_end", pos, facing, 1.0, true)
	elif effects.has("hit_5"):
		play_effect("hit_5", pos, facing, 1.0, true)
	else:
		print("KO hit_end effect missing; skipped")


func _reset_frame_effect_count() -> void:
	# 原版 EffectCtrl.doEffectVO 每个 render 帧同一种 EffectVO 最多保留 3 个，
	# 防止同帧多段命中把 ADD 光效叠成噪点。这里按 effect_id 复刻这个上限。
	frame_effect_count.clear()
	frame_effect_count_reset_queued = false


func play_effect(effect_id: String, pos: Vector2, facing: int = 1, effect_scale: float = 1.0, additive: bool = true, rand_rotate: bool = false) -> void:
	if not manifest.has("effects"):
		return
	var effects: Dictionary = manifest.get("effects", {}) as Dictionary
	if not effects.has(effect_id):
		print("Common effect not found:", effect_id)
		return
	var data: Dictionary = effects[effect_id] as Dictionary
	var frames: Array = data.get("frames", [])
	if frames.is_empty():
		return

	if not frame_effect_count_reset_queued:
		frame_effect_count_reset_queued = true
		call_deferred("_reset_frame_effect_count")
	var effect_count: int = int(frame_effect_count.get(effect_id, 0)) + 1
	frame_effect_count[effect_id] = effect_count
	if effect_count > 3:
		print("原版 EffectCtrl.doEffectVO 同帧同特效上限：skip visual effect_id=", effect_id, " count=", effect_count)
		return

	var sprite := Sprite2D.new()
	sprite.centered = true
	# 原版 common hit effect 来自 Flash/XFL 光效位图，带抗锯齿和 ADD/HARDLIGHT 混合。
	# 使用 LINEAR 避免命中光效边缘出现方块状“白色马赛克”；角色本体仍由 ManifestFighter 保持 NEAREST。
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = pos
	sprite.scale = Vector2(effect_scale, effect_scale)
	sprite.flip_h = facing < 0
	if rand_rotate or bool(data.get("rand_rotate", false)) or bool(data.get("randRotate", false)):
		sprite.rotation = randf_range(-PI, PI)
	if additive or bool(data.get("additive", true)):
		sprite.material = additive_material
	add_child(sprite)

	var item: Dictionary = {
		"sprite": sprite,
		"effect_id": effect_id,
		"frames": frames,
		"fps": float(data.get("fps", 30.0)),
		"timer": 0.0,
		"index": 0
	}
	active_items.append(item)
	_update_item_frame(active_items.size() - 1)


func _process(delta: float) -> void:
	var i: int = active_items.size() - 1
	while i >= 0:
		var item: Dictionary = active_items[i]
		var fps: float = float(item.get("fps", 30.0))
		var timer: float = float(item.get("timer", 0.0)) + delta * original_time_scale
		var frame_time: float = 1.0 / maxf(1.0, fps)
		var idx: int = int(item.get("index", 0))
		while timer >= frame_time:
			timer -= frame_time
			idx += 1
		item["timer"] = timer
		item["index"] = idx
		active_items[i] = item
		var frames: Array = item.get("frames", [])
		if idx >= frames.size():
			var sp: Sprite2D = item.get("sprite") as Sprite2D
			if sp != null and is_instance_valid(sp):
				sp.queue_free()
			active_items.remove_at(i)
		else:
			_update_item_frame(i)
		i -= 1


func _update_item_frame(item_index: int) -> void:
	if item_index < 0 or item_index >= active_items.size():
		return
	var item: Dictionary = active_items[item_index]
	var sprite: Sprite2D = item.get("sprite") as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var frames: Array = item.get("frames", [])
	var idx: int = int(item.get("index", 0))
	if idx < 0 or idx >= frames.size():
		return
	var frame_path: String = FRAME_BASE + str(frames[idx])
	var tex: Texture2D = load(frame_path)
	if tex != null:
		sprite.texture = tex
