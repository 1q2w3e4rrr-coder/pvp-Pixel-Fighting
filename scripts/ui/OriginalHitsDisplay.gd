extends Control

const MCNumberDisplay = preload("res://scripts/ui/MCNumberDisplay.gd")

# 原版 HitsUI.as 逻辑：
#   show(num) 第一次 gotoAndPlay("fadin")；数字变化 gotoAndPlay("update")；消失 gotoAndPlay("fadout")。
# 当前 Godot 版仍使用原版 fight.swf / hits_mc / hits_num_mc 导出的 PNG，
# 但显示时把 hits_mc 和 ct 数字层拆开组合，所以必须在隐藏时彻底销毁子节点，避免 Godot 保留压扁末帧造成彩线/阴影。

const ORIGINAL_FPS: float = 30.0
const DIGIT_WIDTH: float = 35.0
const DIGIT_TEXTURE_WIDTH: float = 47.0
const HITS_STABLE_FRAME_INDEX: int = 19
const DIGIT_BASE_X: float = -23.5
const DIGIT_BASE_Y: float = 0.0
const HITS_TEXT_X: float = 65.05
const HITS_TEXT_Y: float = 3.0
const HITS_SEQUENCE_DIR: String = "res://assets/ui/fight/hits_mc_sequence/"

var is_p1_side: bool = true
var original_position: Vector2 = Vector2.ZERO
var hits_timeline_rect: TextureRect
var number_mc: Control
var showing: bool = false
var anim_state: String = "hidden"
var frame_pos: float = 0.0
var current_combo: int = 0
var last_combo: int = 0
var initialized_origin: bool = false
var hits_frames: Array[Texture2D] = []


func setup(new_is_p1: bool) -> void:
	is_p1_side = new_is_p1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	z_index = 120
	_load_hits_frames()
	visible = false
	set_process(false)


func show_hits(combo_value: int) -> void:
	if combo_value < 1:
		hide_hits()
		return
	if not initialized_origin:
		original_position = position
		initialized_origin = true
	_ensure_children()
	var was_showing: bool = showing
	var combo_changed: bool = combo_value != last_combo
	current_combo = combo_value
	_update_number_and_alignment(combo_value)
	visible = true
	show()
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_set_parts_visible(true)
	if hits_timeline_rect != null:
		hits_timeline_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if number_mc != null:
		number_mc.modulate = Color(1.0, 1.0, 1.0, 1.0)
	# 原版 HitsUI.show：第一次 show -> gotoAndPlay("fadin")；已显示时数字变化 -> gotoAndPlay("update")。
	# 当前仍用 FFDec 原版 hits_mc 稳定帧作为文字贴图，避免播放 fadout 末段压成黄色残线；
	# 但 fadin/update 的 Matrix/scale 仍按 mc_018.xml 作用到 ct 数字层与 hitsmc 文字层。
	showing = true
	if not was_showing:
		anim_state = "fadin"
		frame_pos = 9.0
		set_process(true)
	elif combo_changed:
		anim_state = "update"
		frame_pos = 29.0
		set_process(true)
	else:
		anim_state = "hold"
		frame_pos = 19.0
		set_process(false)
	last_combo = combo_value
	_apply_timeline_frame(frame_pos)


func hide_hits() -> void:
	# 原版可以播放 fadout；但当前 Godot 拆层方案中，fadout 最后几帧会把 FFDec 位图压成 1px 彩线。
	# 因此 combo 归零时直接进入原版最终不可见状态，并销毁所有视觉子节点。
	_finish_hidden()


func _process(delta: float) -> void:
	if anim_state == "hidden":
		return
	frame_pos += delta * ORIGINAL_FPS
	if anim_state == "fadin" and frame_pos >= 19.0:
		frame_pos = 19.0
		anim_state = "hold"
	elif anim_state == "update" and frame_pos >= 37.0:
		frame_pos = 37.0
		anim_state = "hold"
	_apply_timeline_frame(frame_pos)


func _finish_hidden() -> void:
	frame_pos = 0.0
	anim_state = "hidden"
	showing = false
	current_combo = 0
	last_combo = 0
	if initialized_origin:
		position = original_position
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	visible = false
	hide()
	set_process(false)
	_clear_visual_children()
	queue_redraw()


func _ensure_children() -> void:
	if hits_timeline_rect != null and is_instance_valid(hits_timeline_rect) and number_mc != null and is_instance_valid(number_mc):
		return
	_make_children()


func _clear_visual_children() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	hits_timeline_rect = null
	number_mc = null


func _set_parts_visible(value: bool) -> void:
	if hits_timeline_rect != null:
		hits_timeline_rect.visible = value
	if number_mc != null:
		number_mc.visible = value


func _load_hits_frames() -> void:
	hits_frames.clear()
	var index: int = 0
	while index < 80:
		var path: String = HITS_SEQUENCE_DIR + "%04d.png" % index
		if not ResourceLoader.exists(path):
			break
		var res: Resource = load(path)
		if res is Texture2D:
			hits_frames.append(res as Texture2D)
		index += 1


func _make_children() -> void:
	_clear_visual_children()
	hits_timeline_rect = TextureRect.new()
	hits_timeline_rect.name = "hits_mc_ffdec"
	if not hits_frames.is_empty():
		hits_timeline_rect.texture = hits_frames[0]
	hits_timeline_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hits_timeline_rect.stretch_mode = TextureRect.STRETCH_KEEP
	hits_timeline_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hits_timeline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 原版 mc_018.xml：hitsmc 文字层 Matrix tx=65.05, ty=3。
	hits_timeline_rect.position = Vector2(HITS_TEXT_X, HITS_TEXT_Y)
	hits_timeline_rect.size = Vector2(196.0, 72.0)
	add_child(hits_timeline_rect)
	hits_timeline_rect.visible = false

	number_mc = MCNumberDisplay.new()
	number_mc.name = "ct"
	number_mc.size = Vector2(260.0, 80.0)
	number_mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_mc.clip_contents = false
	number_mc.call("setup", "res://assets/ui/fight/mcnumber/hits", DIGIT_WIDTH, 0, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(number_mc)
	number_mc.visible = false


func _update_number_and_alignment(combo_value: int) -> void:
	if number_mc != null and number_mc.has_method("set_number"):
		number_mc.call("set_number", combo_value)
	var digits: int = max(1, str(combo_value).length())
	var num_width: float = _number_visual_width(digits)
	var xoffset: float = -num_width + 45.0
	if is_p1_side:
		position.x = original_position.x - xoffset
	else:
		position.x = original_position.x


func _apply_timeline_frame(frame_value: float) -> void:
	_ensure_children()
	# 使用稳定 HITS 贴图，不直接播放会压缩成细线的 fadout 末帧；
	# 文字层的位置/缩放仍按原版 mc_018.xml 的 hitsmc Matrix 还原。
	var frame_index: int = clampi(HITS_STABLE_FRAME_INDEX, 0, max(0, hits_frames.size() - 1))
	if frame_index % 2 == 0 and frame_index + 1 < hits_frames.size():
		frame_index += 1
	var hits_transform: Vector4 = _hits_transform_at(frame_value)
	if hits_timeline_rect != null and not hits_frames.is_empty():
		hits_timeline_rect.visible = true
		hits_timeline_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		hits_timeline_rect.texture = hits_frames[frame_index]
		hits_timeline_rect.position = Vector2(hits_transform.z, hits_transform.w)
		hits_timeline_rect.scale = Vector2(hits_transform.x, hits_transform.y)
	var digit_transform: Vector4 = _digit_transform_at(frame_value)
	var digits: int = max(1, str(maxi(current_combo, 0)).length())
	var num_width: float = _number_visual_width(digits)
	var xoffset: float = -num_width + 45.0
	if number_mc != null:
		number_mc.visible = true
		number_mc.scale = Vector2(digit_transform.x, digit_transform.y)
		number_mc.position = Vector2(digit_transform.z + xoffset, digit_transform.w)


func _number_visual_width(digits: int) -> float:
	# 原版 HitsUI.as: new MCNumber(hits_num_mc, 0, 1, 35)，随后用 _txtmc.width 计算 xoffset。
	# hits_num_mc 单个导出位图宽约 47px，多位数字按 35px 步进叠放，所以不能简单用 47 * digits。
	return DIGIT_TEXTURE_WIDTH + maxf(0.0, float(digits - 1)) * DIGIT_WIDTH


func _hits_transform_at(f: float) -> Vector4:
	# HITS 文字层按原版 mc_018.xml / hitsmc 图层关键帧：
	# frame19/37 为稳定显示；frame29..37 为 update 弹跳。
	if f < 11.0:
		return Vector4(1.0, 1.0, HITS_TEXT_X, HITS_TEXT_Y)
	if f < 14.0:
		return _lerp_v4(Vector4(0.482986450195313, 0.482986450195313, 1.3, 12.05), Vector4(1.0, 0.8179931640625, 70.05, 5.8), 11.0, 14.0, f)
	if f < 19.0:
		return _lerp_v4(Vector4(1.0, 0.8179931640625, 70.05, 5.8), Vector4(1.0, 1.0, HITS_TEXT_X, HITS_TEXT_Y), 14.0, 19.0, f)
	if f < 30.0:
		return Vector4(1.0, 1.0, HITS_TEXT_X, HITS_TEXT_Y)
	if f < 33.0:
		return _lerp_v4(Vector4(1.0, 0.709991455078125, HITS_TEXT_X, 12.5), Vector4(1.0, 1.19398498535156, HITS_TEXT_X, -8.5), 30.0, 33.0, f)
	if f < 37.0:
		return _lerp_v4(Vector4(1.0, 1.19398498535156, HITS_TEXT_X, -8.5), Vector4(1.0, 1.0, HITS_TEXT_X, HITS_TEXT_Y), 33.0, 37.0, f)
	return Vector4(1.0, 1.0, HITS_TEXT_X, HITS_TEXT_Y)


func _digit_transform_at(f: float) -> Vector4:
	# 数字 MC 的 transform 按原版 mc_018.xml 的 ct 图层关键帧。
	if f < 9.0:
		return Vector4(1.0, 1.0, DIGIT_BASE_X, DIGIT_BASE_Y)
	if f < 11.0:
		return _lerp_v4(Vector4(0.216995239257813, 0.216995239257813, -5.5, 23.0), Vector4(1.20999145507813, 1.20999145507813, -27.3, -4.35), 9.0, 11.0, f)
	if f < 16.0:
		return _lerp_v4(Vector4(1.20999145507813, 1.20999145507813, -27.3, -4.35), Vector4(1.0, 1.0, DIGIT_BASE_X, DIGIT_BASE_Y), 11.0, 16.0, f)
	if f < 29.0:
		return Vector4(1.0, 1.0, DIGIT_BASE_X, DIGIT_BASE_Y)
	if f < 31.0:
		return _lerp_v4(Vector4(1.0, 0.595993041992188, DIGIT_BASE_X, 21.5), Vector4(1.0, 1.22799682617188, DIGIT_BASE_X, -16.5), 29.0, 31.0, f)
	if f < 35.0:
		return _lerp_v4(Vector4(1.0, 1.22799682617188, DIGIT_BASE_X, -16.5), Vector4(1.0, 1.0, DIGIT_BASE_X, DIGIT_BASE_Y), 31.0, 35.0, f)
	return Vector4(1.0, 1.0, DIGIT_BASE_X, DIGIT_BASE_Y)


func _lerp_v4(a: Vector4, b: Vector4, f0: float, f1: float, f: float) -> Vector4:
	var denom: float = maxf(0.0001, f1 - f0)
	var t: float = clampf((f - f0) / denom, 0.0, 1.0)
	return a.lerp(b, t)
