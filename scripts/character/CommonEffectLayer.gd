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
	9: "hit_5",
	11: "hit_2"
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
var additive_material: CanvasItemMaterial


func _ready() -> void:
	z_index = 80
	additive_material = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	load_manifest()


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
	var effect_id: String = String(HIT_EFFECT_BY_TYPE.get(hit_type, "hit_4"))
	var sound_id: String = String(HIT_SOUND_BY_TYPE.get(hit_type, "snd_hit2"))
	play_effect(effect_id, hit_rect.get_center(), facing, 1.0, true)
	AudioManager.play_effect_sfx(sound_id)


func play_defense_effect(hit_vo: Dictionary, hit_rect: Rect2, facing: int = 1) -> void:
	var hit_type: int = int(hit_vo.get("hitType", 0))
	# 原版 HAND 防御遇到 KAN/KAN_HEAVY 会转成 DA/DA_HEAVY；当前蓝染是刀系，先按 SWOARD 处理。
	var effect_id: String = String(DEFENSE_EFFECT_BY_TYPE.get(hit_type, "defense_5"))
	var sound_id: String = String(DEF_SOUND_BY_TYPE.get(hit_type, "snd_def"))
	play_effect(effect_id, hit_rect.get_center(), facing, 1.0, true)
	AudioManager.play_effect_sfx(sound_id)


func play_break_defense(hit_rect: Rect2, facing: int = 1) -> void:
	play_effect("break_def", hit_rect.get_center(), facing, 1.0, true)
	AudioManager.play_effect_sfx("snd_mfdjx")


func play_effect(effect_id: String, pos: Vector2, facing: int = 1, effect_scale: float = 1.0, additive: bool = true) -> void:
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

	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = pos
	sprite.scale = Vector2(effect_scale, effect_scale)
	sprite.flip_h = facing < 0
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
		var timer: float = float(item.get("timer", 0.0)) + delta
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
	var frame_path: String = FRAME_BASE + String(frames[idx])
	var tex: Texture2D = load(frame_path)
	if tex != null:
		sprite.texture = tex
