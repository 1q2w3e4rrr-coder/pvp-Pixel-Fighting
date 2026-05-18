extends Control

# Godot 版 MCNumber：对应原版 net.play5d.kyo.display.MCNumber.as。
# 原版逻辑：每一位数字是一个 MovieClip，gotoAndStop(startFrame + digit)，按固定 mcWidth 横向排列。
# 这里把 fight.xfl 里的 time_txtmc / txtmc_score / hits_num_mc 预渲染成 PNG，再按同样规则组合。

var digit_dir: String = ""
var digit_width: float = 10.0
var bits: int = 0
var align_mode: int = HORIZONTAL_ALIGNMENT_LEFT
var number_value: int = 0
var textures: Array[Texture2D] = []


func setup(new_digit_dir: String, new_digit_width: float, new_bits: int = 0, new_align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	digit_dir = new_digit_dir
	digit_width = new_digit_width
	bits = new_bits
	align_mode = new_align
	_load_digits()
	set_number(number_value)


func set_number(v: int) -> void:
	number_value = maxi(0, v)
	_rebuild()


func _load_digits() -> void:
	textures.clear()
	for i: int in range(10):
		var path: String = digit_dir.path_join(str(i) + ".png")
		var tex: Resource = load(path)
		textures.append(tex as Texture2D)


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if textures.size() < 10:
		return
	var s: String = str(number_value)
	while s.length() < bits:
		s = "0" + s
	var content_width: float = digit_width * float(s.length())
	var start_x: float = 0.0
	if align_mode == HORIZONTAL_ALIGNMENT_CENTER:
		start_x = (size.x - content_width) * 0.5
	elif align_mode == HORIZONTAL_ALIGNMENT_RIGHT:
		start_x = size.x - content_width
	for i: int in range(s.length()):
		var digit: int = int(s.substr(i, 1))
		var tex: Texture2D = textures[digit]
		if tex == null:
			continue
		var rect: TextureRect = TextureRect.new()
		rect.name = "Digit" + str(i) + "_" + str(digit)
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = Vector2(start_x + digit_width * float(i), 0.0)
		rect.size = Vector2(float(tex.get_width()), float(tex.get_height()))
		add_child(rect)
