extends Control

# 原版 embed/fight/mc_043(startKOmc) 的 Godot 时间轴控制层。
# 这一版不再只用单张 announcer 图近似，而是使用按 mc_043 原始帧段预渲染的 PNG 序列：
# start=9..87, ko=144..189, winner=199..209, timeover=219..262, drawgame=266..308。
# 事件帧仍按原版：fight_in=54, fight=57, complete=87；sound_007=round；mc_041 nummc 内 sound_001=1；sound_005=fight, sound_009=timeover, sound_008=drawgame。

signal fight_in
signal fight
signal complete

const FPS: float = 30.0
const START_LABEL_FRAME: int = 9
const START_ROUND_SOUND_FRAME: int = 11
const START_ROUND_NUM_SOUND_FRAME: int = 41
const START_FIGHT_IN_FRAME: int = 54
const START_FIGHT_FRAME: int = 57
const START_COMPLETE_FRAME: int = 87
const KO_LABEL_FRAME: int = 144
const KO_COMPLETE_FRAME: int = 189
const WINNER_LABEL_FRAME: int = 199
const WINNER_COMPLETE_FRAME: int = 209
const TIMEOVER_LABEL_FRAME: int = 219
const TIMEOVER_SOUND_FRAME: int = 221
const TIMEOVER_COMPLETE_FRAME: int = 262
const DRAW_LABEL_FRAME: int = 266
const DRAW_SOUND_FRAME: int = 267
const DRAW_COMPLETE_FRAME: int = 308

const SEQ_DIR: String = "res://assets/ui/fight/startko_sequences/"
const TEX_DIR: String = "res://assets/ui/fight/announcer/"
const FIGHT_SFX_DIR: String = "res://assets/sfx/fight/"

# 原版 FightUI.showStart() 把 startKOmc.y 设为 -50。
# 当前 FFDec 逐帧导出的 start 序列保留了较大的透明舞台边距，实际 Round/Fight 视觉中心比原版截图略低。
# Step84：只对 start 序列做显示层微调，不影响 KO / Winner / TimeOver 的原版 y=0。
const START_SEQUENCE_VISUAL_Y: float = -70.0
const END_SEQUENCE_VISUAL_Y: float = 0.0

var sprite: TextureRect
var playing: bool = false
var mode: String = ""
var elapsed: float = 0.0
var label_frame: int = 0
var complete_frame: int = 0
var last_virtual_frame: int = -1
var complete_emitted: bool = false
var fight_in_emitted: bool = false
var fight_emitted: bool = false
var played_sound_frames: Dictionary = {}
var current_sequence: Array[Texture2D] = []
# FFDec 逐帧导出不会执行 startKOmc 里的 go:fight 标签；
# 原版 renderStartAndKO 遇到 currentFrameLabel == "go:fight" 会立即跳到 fight。
# 所以 start 段需要跳过导出序列中 Round 2 的过渡帧，只保留本项目指定的 Round 1。
var current_sequence_frame_map: Array[int] = []

var tex_blank: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_blank = _load_fallback_tex("blank.png")
	_build_nodes()
	set_process(true)


func play_start(_round_num: int = 1) -> void:
	# 本项目按你的要求只做单回合，固定 Round 1。
	# 不播放原版多回合时间轴中后续 Round 2/3/4 的帧。
	_start_sequence("start", START_LABEL_FRAME, START_COMPLETE_FRAME)


func play_ko() -> void:
	_start_sequence("ko", KO_LABEL_FRAME, KO_COMPLETE_FRAME)


func play_winner(winner_id: int, perfect: bool = false) -> void:
	var seq_name: String = "winner_p2" if winner_id == 2 else "winner_p1"
	if perfect:
		seq_name += "_perfect"
	_start_sequence(seq_name, WINNER_LABEL_FRAME, WINNER_COMPLETE_FRAME)


func play_timeover() -> void:
	_start_sequence("timeover", TIMEOVER_LABEL_FRAME, TIMEOVER_COMPLETE_FRAME)


func play_drawgame() -> void:
	_start_sequence("drawgame", DRAW_LABEL_FRAME, DRAW_COMPLETE_FRAME)


func stop_anim() -> void:
	playing = false
	visible = false
	current_sequence.clear()
	current_sequence_frame_map.clear()
	if sprite != null:
		sprite.texture = tex_blank


func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	var virtual_frame: int = label_frame + int(floor(elapsed * FPS))
	if virtual_frame != last_virtual_frame:
		last_virtual_frame = virtual_frame
		_apply_sequence_frame(virtual_frame - label_frame)
		_update_original_events(virtual_frame)
	if virtual_frame >= complete_frame and not complete_emitted:
		complete_emitted = true
		complete.emit()
		# 原版到 COMPLETE 后 startKOmc 不应把最后一帧残留在画面。
		# 只在开局 start 段自动清除；KO/WIN/TIMEOVER 由结束流程控制。
		if mode == "start":
			stop_anim()


func _start_sequence(seq_name: String, first_frame: int, end_frame: int) -> void:
	mode = seq_name
	label_frame = first_frame
	complete_frame = end_frame
	elapsed = 0.0
	last_virtual_frame = -1
	complete_emitted = false
	fight_in_emitted = false
	fight_emitted = false
	played_sound_frames.clear()
	current_sequence = _load_sequence(seq_name)
	if seq_name == "start":
		current_sequence_frame_map = _build_start_round1_frame_map()
	else:
		current_sequence_frame_map.clear()
	_apply_original_startko_position(seq_name)
	playing = true
	visible = true
	_apply_sequence_frame(0)


func _apply_original_startko_position(seq_name: String) -> void:
	if sprite == null:
		return
	# 原版 FightUI.showStart: ui.startKOmc.y = -50。
	# 但当前 FFDec 序列外框保留透明边距，视觉上 Round/Fight 偏低；
	# Step84 按截图反馈把 start 序列再上移 20px。KO/TimeOver/Winner 仍按原版 y=0。
	if seq_name == "start":
		sprite.position = Vector2(0.0, START_SEQUENCE_VISUAL_Y)
	else:
		sprite.position = Vector2(0.0, END_SEQUENCE_VISUAL_Y)


func _update_original_events(virtual_frame: int) -> void:
	if mode == "start":
		_maybe_play_sound(virtual_frame, START_ROUND_SOUND_FRAME, "start_round")
		_maybe_play_sound(virtual_frame, START_ROUND_NUM_SOUND_FRAME, "round_1")
		if virtual_frame >= START_FIGHT_IN_FRAME and not fight_in_emitted:
			fight_in_emitted = true
			fight_in.emit()
		if virtual_frame >= START_FIGHT_FRAME and not fight_emitted:
			_maybe_play_sound(virtual_frame, START_FIGHT_FRAME, "fight")
			fight_emitted = true
			fight.emit()
	elif mode == "timeover":
		_maybe_play_sound(virtual_frame, TIMEOVER_SOUND_FRAME, "timeover")
	elif mode == "drawgame":
		_maybe_play_sound(virtual_frame, DRAW_SOUND_FRAME, "drawgame")


func _apply_sequence_frame(local_frame: int) -> void:
	if sprite == null:
		return
	if current_sequence.is_empty():
		sprite.texture = tex_blank
		return
	var idx: int = local_frame
	if not current_sequence_frame_map.is_empty():
		idx = current_sequence_frame_map[clampi(local_frame, 0, current_sequence_frame_map.size() - 1)]
	idx = clampi(idx, 0, current_sequence.size() - 1)
	sprite.texture = current_sequence[idx]


func _build_start_round1_frame_map() -> Array[int]:
	var result: Array[int] = []
	# start sequence local frame = virtual_frame - START_LABEL_FRAME.
	# FFDec 逐帧导出不会执行 mc_043 中的 go:fight 标签，所以会把 Round 2 过渡帧导出来。
	# 从上传的 startKO 序列可见 Round 2 出现在 local 43..47 左右；原版运行到 go:fight 会跳过它。
	# 本项目固定单回合 Round 1，因此 local>=42 直接映射到 Fight 段，保证不会显示 Round 2。
	var max_local: int = START_COMPLETE_FRAME - START_LABEL_FRAME
	var raw_max: int = max(0, current_sequence.size() - 1)
	for i: int in range(max_local + 1):
		if i >= 42:
			result.append(clampi(i + 6, 0, raw_max))
		else:
			result.append(clampi(i, 0, raw_max))
	return result


func _load_sequence(seq_name: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var index: int = 0
	while true:
		var file_name: String = "%04d.png" % index
		var path: String = SEQ_DIR + seq_name + "/" + file_name
		if not ResourceLoader.exists(path):
			break
		var res: Resource = load(path)
		if res is Texture2D:
			frames.append(res as Texture2D)
		index += 1
		if index > 400:
			break
	if frames.is_empty():
		push_warning("FightStartKOAnimator missing sequence: " + seq_name)
		var fallback: Texture2D = _load_fallback_for_mode(seq_name)
		if fallback != null:
			frames.append(fallback)
	return frames


func _build_nodes() -> void:
	sprite = TextureRect.new()
	sprite.name = "StartKOSequence"
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# startKOmc 在 ui_fight(mc_044) 中没有额外 Matrix，x=0。
	# 原版 FightUI.showStart() 设置 startKOmc.y = -50；
	# KO / TimeOver 分支设置 startKOmc.y = 0。
	# 这里保持 FFDec 导出的原始像素尺寸，不居中、不拉伸。
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.position = Vector2.ZERO
	sprite.size = Vector2(663.0, 466.0)
	add_child(sprite)
	stop_anim()


func _maybe_play_sound(cur_frame: int, trigger_frame: int, sound_name: String) -> void:
	if cur_frame < trigger_frame:
		return
	if played_sound_frames.has(sound_name):
		return
	played_sound_frames[sound_name] = true
	AudioManager.play_sfx(FIGHT_SFX_DIR + sound_name + ".ogg", -2.0)


func _load_fallback_for_mode(seq_name: String) -> Texture2D:
	if seq_name == "start":
		return _load_fallback_tex("round_1.png")
	if seq_name == "ko":
		return _load_fallback_tex("ko.png")
	if seq_name == "timeover":
		return _load_fallback_tex("timeover.png")
	if seq_name == "drawgame":
		return _load_fallback_tex("drawgame.png")
	if seq_name.begins_with("winner_p2"):
		return _load_fallback_tex("p2_win.png")
	if seq_name.begins_with("winner_p1"):
		return _load_fallback_tex("p1_win.png")
	return tex_blank


func _load_fallback_tex(file_name: String) -> Texture2D:
	var tex: Resource = load(TEX_DIR + file_name)
	if tex == null:
		push_warning("FightStartKOAnimator missing fallback texture: " + TEX_DIR + file_name)
		return null
	return tex as Texture2D
