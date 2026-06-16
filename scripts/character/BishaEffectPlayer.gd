extends Control

const EffectPlayer = preload("res://scripts/character/EffectPlayer.gd")

# 已确认的原版依据：
# 1. BishaFaceEffectView.as 会把必杀脸图强制设为 254 x 180。
# 2. BlackBackView.as 会把 bisha_face_mc 放到 y = 100 + 100 / zoom；当前 800x600 demo 先按 zoom=1，即 y≈200。
# 3. effect.xfl 中 XG_bs = mc_020，XG_cbs = mc_021，两者都是 17 帧，XG_cbs 是 XG_bs 的约 1.2 倍版本。
# 4. EffectCtrler.bisha() 的通用必杀光效位置是 target.x, target.y - 50。
const BISHA_FACE_SIZE := Vector2(254.0, 180.0)
const BISHA_FACE_LEFT_POS := Vector2(-18.0, 200.0)
const BISHA_FACE_RIGHT_POS := Vector2(562.0, 199.0)

var dark_layer: ColorRect
var face_rect: TextureRect
var xg_effect: EffectPlayer

var is_active: bool = false


func _ready() -> void:
	create_nodes()


func create_nodes() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100

	dark_layer = ColorRect.new()
	# 原版黑背景实际在场景底层，并且地图会隐藏；当前 demo 还没做“地图隐藏 + 只渲染必杀对象”，
	# 所以先保留半透明黑层，避免把角色完全盖死。后续再把这个结构改成原版层级。
	dark_layer.color = Color(0, 0, 0, 0.70)
	dark_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_layer.z_index = 0
	add_child(dark_layer)

	xg_effect = EffectPlayer.new()
	xg_effect.z_index = 5
	add_child(xg_effect)
	xg_effect.setup("res://assets/characters/aizen/aizen_effect_manifest.json")

	face_rect = TextureRect.new()
	face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 原版 AS 是 face.width = 254; face.height = 180，属于强制尺寸，不是等比例居中。
	face_rect.stretch_mode = TextureRect.STRETCH_SCALE
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_rect.z_index = 10
	face_rect.size = BISHA_FACE_SIZE
	add_child(face_rect)


func play_bisha(is_super: bool, face_id: String, target_pos: Vector2, facing: int, current_target_pos: Variant = null, xg_effect_pos: Variant = null) -> void:
	visible = true
	is_active = true

	var effect_key: String = "xg_cbs" if is_super else "xg_bs"
	var face_path: String = "res://assets/characters/aizen/face/" + face_id + ".png"

	print("Bisha face path:", face_path, " effect_key=", effect_key)

	var face_tex: Texture2D = load(face_path)

	if face_tex == null:
		push_warning("Bisha face not found: " + face_path)
		face_rect.texture = null
	else:
		face_rect.texture = face_tex

	# 原版 EffectCtrler.showFace():
	# faceId 默认 1；如果 currentTarget 存在，并且 target.getDisplay().x > currentTarget.getDisplay().x，则 faceId = 2。
	# 也就是：发动者在目标右侧时使用 facemc2；否则使用 facemc1。
	# 这里不再用 facing 近似，优先使用 BattlePlaceholder 传入的 current_target_pos。
	var original_face_slot: int = 1
	if typeof(current_target_pos) == TYPE_VECTOR2:
		var target_vec: Vector2 = current_target_pos
		original_face_slot = 2 if target_pos.x > target_vec.x else 1
	else:
		# 兼容旧调用；没有 currentTarget 时才退回原版默认 faceId=1。
		original_face_slot = 1

	var face_on_right: bool = original_face_slot == 2
	face_rect.size = BISHA_FACE_SIZE
	face_rect.position = BISHA_FACE_RIGHT_POS if face_on_right else BISHA_FACE_LEFT_POS
	face_rect.flip_h = face_on_right

	# 原版 EffectCtrler.bisha(target.x, target.y - 50)。
	# BishaEffectPlayer 位于屏幕 HUD 层，因此调用方应先用 world_to_screen(target + Vector2(0,-50))
	# 传入 xg_effect_pos。这样 camera zoom != 1 时，光效与人物的世界相对高度仍和原版一致。
	var effect_pos: Vector2 = target_pos + Vector2(0, -50)
	if typeof(xg_effect_pos) == TYPE_VECTOR2:
		effect_pos = xg_effect_pos
	xg_effect.play_effect(effect_key, effect_pos, facing, 1.0, true)
	AudioManager.play_effect_sfx("snd_cbs" if is_super else "snd_bs")

	print("Bisha face size=", BISHA_FACE_SIZE, " slot=", original_face_slot, " pos=", face_rect.position, " flip_h=", face_rect.flip_h)


func end_bisha() -> void:
	is_active = false
	visible = false

	if xg_effect != null:
		xg_effect.stop_effect()

	if face_rect != null:
		face_rect.texture = null
		face_rect.flip_h = false
