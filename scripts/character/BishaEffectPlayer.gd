extends Control

const EffectPlayer = preload("res://scripts/character/EffectPlayer.gd")

# Step50 原版依据：
# 1. EffectCtrl.bisha(): justRenderAnimate(target) / GameCtrl.pause() / setRenderHit(false) /
#    _gameStage.addChildAt(_blackBack, 0) / _blackBack.fadIn() / showFace() /
#    doEffectById('bisha' or 'bisha_super', target.x, target.y - 50) /
#    _gameStage.getMap().setVisible(false)。
# 2. BlackBackView.as: 使用全屏黑色 BitmapData；showBishaFace() 中 bisha_face_mc.y = 100 + 100 / zoom。
# 3. BishaFaceEffectView.as: 必杀脸图强制设置 width=254, height=180，并放入 facemc1/facemc2。
# 4. effect.xfl: XG_bs = mc_020，XG_cbs = mc_021。
const BISHA_FACE_SIZE := Vector2(254.0, 180.0)
const BISHA_FACE_LEFT_X: float = -18.0
const BISHA_FACE_RIGHT_X: float = 562.0
const BISHA_FACE_SLIDE_DISTANCE: float = 80.0
const BISHA_FACE_FADE_TIME: float = 0.12
const BISHA_XG_ALPHA: float = 0.88
const BISHA_SUPER_XG_ALPHA: float = 0.86

var dark_layer: ColorRect
var face_rect: TextureRect
var xg_effect: EffectPlayer

var is_active: bool = false
var original_time_scale: float = 1.0

var face_animating: bool = false
var face_anim_timer: float = 0.0
var face_anim_duration: float = BISHA_FACE_FADE_TIME
var face_start_pos: Vector2 = Vector2.ZERO
var face_target_pos: Vector2 = Vector2.ZERO


func set_original_time_scale(value: float) -> void:
	original_time_scale = clampf(value, 0.01, 4.0)
	if xg_effect != null and xg_effect.has_method("set_original_time_scale"):
		xg_effect.set_original_time_scale(original_time_scale)


func _ready() -> void:
	create_nodes()


func create_nodes() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100

	dark_layer = ColorRect.new()
	dark_layer.name = "OriginalBishaBlackBackView"
	# 原版 _blackBack 被 addChildAt 到 GameStage 底层；这里使用相对负 z，确保黑底在必杀脸图/光效下面，
	# BattlePlaceholder 会同时隐藏地图层，因此不会再出现覆盖角色的大黑块问题。
	dark_layer.color = Color(0, 0, 0, 1.0)
	dark_layer.visible = false
	dark_layer.modulate.a = 1.0
	dark_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_layer.z_index = -100
	dark_layer.z_as_relative = true
	dark_layer.show_behind_parent = true
	add_child(dark_layer)

	xg_effect = EffectPlayer.new()
	xg_effect.name = "OriginalBishaXGEffect"
	xg_effect.z_index = 5
	add_child(xg_effect)
	xg_effect.setup("res://assets/characters/aizen/aizen_effect_manifest.json")
	xg_effect.set_original_time_scale(original_time_scale)

	face_rect = TextureRect.new()
	face_rect.name = "OriginalBishaFace"
	face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 原版 AS 是 face.width = 254; face.height = 180，属于强制尺寸，不是等比例居中。
	face_rect.stretch_mode = TextureRect.STRETCH_SCALE
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_rect.z_index = 10
	face_rect.size = BISHA_FACE_SIZE
	face_rect.visible = false
	add_child(face_rect)


func _process(delta: float) -> void:
	if not is_active:
		return
	if not face_animating:
		return
	face_anim_timer += delta * original_time_scale
	var t: float = clampf(face_anim_timer / maxf(0.001, face_anim_duration), 0.0, 1.0)
	# 原版 bisha_face_mc 从第 2 帧开始播放，这里用 ease-out 近似其入场感；后续 Step51/52 再解析 mc_016.xml 精确重建。
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	if face_rect != null:
		face_rect.position = face_start_pos.lerp(face_target_pos, eased)
		face_rect.modulate.a = t
	if t >= 1.0:
		face_animating = false
		if face_rect != null:
			face_rect.position = face_target_pos
			face_rect.modulate.a = 1.0


func play_bisha(is_super: bool, face_id: String, target_pos: Vector2, facing: int, current_target_pos: Variant = null, xg_effect_pos: Variant = null, camera_zoom: float = 1.0, face_slot_override: int = 0) -> void:
	# 原版 EffectCtrl.bisha(isSuper, face)：Aizen_2 只用于超必杀，必须对应 bisha_super / XG_cbs。
	# 这里加一层兜底，避免 manifest 解析或输入分支误传 is_super=false 时，S+I 又播放普通 XG_bs。
	var resolved_is_super: bool = is_super or face_id == "Aizen_2"

	visible = true
	is_active = true
	modulate.a = 1.0

	if dark_layer != null:
		dark_layer.visible = true
		dark_layer.modulate.a = 1.0
		dark_layer.color = Color(0, 0, 0, 1.0)

	if face_rect != null:
		face_rect.visible = true
		face_rect.modulate.a = 0.0

	if xg_effect != null:
		xg_effect.visible = true
		# Step53：XG_bs / XG_cbs 原版是 ADD 混合。当前资源是预渲染 PNG，直接满 alpha 叠加会让白色核心过曝。
		xg_effect.modulate.a = BISHA_SUPER_XG_ALPHA if resolved_is_super else BISHA_XG_ALPHA

	var effect_key: String = "xg_cbs" if resolved_is_super else "xg_bs"
	var face_path: String = "res://assets/characters/aizen/face/" + face_id + ".png"
	var face_tex: Texture2D = load(face_path)

	if face_tex == null:
		push_warning("Bisha face not found: " + face_path)
		face_rect.texture = null
	else:
		face_rect.texture = face_tex

	# 原版 EffectCtrl.showFace():
	#   faceId 默认 1；若 currentTarget 存在且 target.x > display.x，则 faceId = 2。
	# 同一源码中保留了 TeamID.isTeam2(target) 的分支注释。当前课程版已经进入固定 2P 对战，
	# 按用户目标使用“施放者队伍固定侧”：P1 -> 左侧 facemc1，P2 -> 右侧 facemc2；
	# 未传 face_slot_override 时仍保留原版 released source 的相对位置兜底。
	var original_face_slot: int = 1
	if face_slot_override == 1 or face_slot_override == 2:
		original_face_slot = face_slot_override
	elif typeof(current_target_pos) == TYPE_VECTOR2:
		var target_vec: Vector2 = current_target_pos
		original_face_slot = 2 if target_pos.x > target_vec.x else 1
	else:
		original_face_slot = 1

	var face_on_right: bool = original_face_slot == 2
	var safe_zoom: float = maxf(0.01, camera_zoom)
	var face_y: float = 100.0 + (100.0 / safe_zoom)
	face_target_pos = Vector2(BISHA_FACE_RIGHT_X if face_on_right else BISHA_FACE_LEFT_X, face_y)
	var slide_dir: float = 1.0 if face_on_right else -1.0
	face_start_pos = face_target_pos + Vector2(BISHA_FACE_SLIDE_DISTANCE * slide_dir, 0.0)
	face_anim_timer = 0.0
	face_anim_duration = BISHA_FACE_FADE_TIME
	face_animating = true

	face_rect.size = BISHA_FACE_SIZE
	face_rect.position = face_start_pos
	face_rect.flip_h = face_on_right

	# 原版 EffectCtrl.bisha(target.x, target.y - 50)。
	# BishaEffectPlayer 位于屏幕 HUD 层，因此调用方先用 world_to_screen(target + Vector2(0,-50))。
	var effect_pos: Vector2 = target_pos + Vector2(0, -50)
	if typeof(xg_effect_pos) == TYPE_VECTOR2:
		effect_pos = xg_effect_pos
	xg_effect.play_effect(effect_key, effect_pos, facing, 1.0, true)
	if xg_effect != null:
		xg_effect.modulate.a = BISHA_SUPER_XG_ALPHA if resolved_is_super else BISHA_XG_ALPHA
	AudioManager.play_effect_sfx("snd_cbs" if resolved_is_super else "snd_bs")

	print("Step60 Bisha start face=", face_id, " is_super=", is_super, " resolved_super=", resolved_is_super, " slot=", original_face_slot, " override=", face_slot_override, " face_pos=", face_target_pos, " effect=", effect_key, " xg_pos=", effect_pos, " zoom=", camera_zoom)


func end_bisha() -> void:
	is_active = false
	visible = false
	modulate.a = 0.0
	face_animating = false
	face_anim_timer = 0.0

	if dark_layer != null:
		dark_layer.visible = false
		dark_layer.modulate.a = 0.0
		dark_layer.color = Color(0, 0, 0, 0.0)

	if xg_effect != null:
		xg_effect.stop_effect()
		xg_effect.visible = false
		xg_effect.modulate.a = 0.0

	if face_rect != null:
		face_rect.texture = null
		face_rect.flip_h = false
		face_rect.visible = false
		face_rect.modulate.a = 0.0
		face_rect.position = Vector2.ZERO


func force_clear_bisha_visuals() -> void:
	# Round end / KO 后的强制清理；避免任何黑底、脸图或 XG 光效残留到结算菜单。
	end_bisha()
	for child in get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			item.visible = false
			item.modulate.a = 0.0
