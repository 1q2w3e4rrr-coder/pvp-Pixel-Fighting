extends Control

const FightStartKOAnimator = preload("res://scripts/ui/FightStartKOAnimator.gd")
const MCNumberDisplay = preload("res://scripts/ui/MCNumberDisplay.gd")
const OriginalHitsDisplay = preload("res://scripts/ui/OriginalHitsDisplay.gd")

# BVN 原版 fight.swf / embed/fight XFL HUD 复刻层。
# 资源来源：OpenBleachVsNaruto/swf_source/embed/fight/
# 已接入原版 linkage：ui_fight、hpbar_mc、hpbar_barmc、hpbar_facegroup、energy_bar、qbar_mc、qbar_fzqi_mc、hits_mc。
# 注意：这里使用 XFL 中 bitmapDataHRef 解码出的 PNG 作为皮肤；hits_mc 已按 mc_018.xml 复刻 fadin/update/fadout；score/time 外层已按原版 MovieClip 坐标组合。

const TEX_DIR: String = "res://assets/ui/fight/"
const QBAR_MOVIE_DIR: String = "res://assets/ui/fight/ffdec_sprites/qbar_mc/"
const QBAR_MOVIE_FRAME_COUNT: int = 58
const QBAR_MOVIE_SIZE: Vector2 = Vector2(482.0, 151.0)
# FFDec 原版 qbar_mc 序列带完整透明画布。下面位置以 mc_044/fzqi1/fzqi2 与 mc_026/facemc/barmc 原始 Matrix 对齐。
const QBAR_MOVIE_P1_POS: Vector2 = Vector2(-201.55, 535.10)
const QBAR_MOVIE_P2_POS: Vector2 = Vector2(489.05, 535.10)
const QBAR_MOVIE_HOLD_FRAME_0: int = 32
const QBAR_MOVIE_HOLD_FRAME_1: int = 13
const QBAR_MOVIE_HOLD_FRAME_2: int = 14
const QBAR_MOVIE_HOLD_FRAME_3: int = 31

# 原版 startKOmc 时间轴：start label 从 frame 9 开始，fight_in=54，fight=57，complete=87；KO=144-189，winner=199-209，timeover=219-262，drawgame=266-308。
# 这里不伪造完整矢量时间轴，只按原版事件帧驱动文字/声音/UI 可见性。

const HP_FRAME_SIZE: Vector2 = Vector2(271.0, 23.0)       # picture_076, hpbar_barmc 外框
const HP_BAR_SIZE: Vector2 = Vector2(260.0, 15.0)         # picture_062 / redbar 区域
# 原版 mc_033.xml 里 bar 是绿色 shape_004，在 redbar 上层。
# 本补丁严格拆回原版四层：picture_076 底框 / picture_062 redbar / picture_047 green bar / picture_008 玻璃高光。
const HP_FRONT_SIZE: Vector2 = Vector2(260.0, 15.0)
const HP_FRONT_OFFSET: Vector2 = Vector2(4.0, 4.0)
const HP_GLASS_SIZE: Vector2 = Vector2(268.0, 19.0)       # picture_008, hpbar_barmc 玻璃层
const FACE_FRAME_SIZE: Vector2 = Vector2(105.0, 64.0)     # picture_090, hpbar_facemc
# 原版战斗血条头像不是 55x55 普通头像，而是 FightFaceUI -> AssetManager.getFighterFaceBar()
# 使用 FighterVO.faceBarCls，并在 AssetManager 中强制 size=(102,64)。
# 当前 BVN 资源配置里 id="aizen" 对应的是 start_frame=1 的队长蓝染，face_bar=aizen_captain_m.png；
# id="aizen_gz" 才对应叛变/白衣蓝染，face_bar=aizen_m.png。
const FACE_BAR_SIZE: Vector2 = Vector2(102.0, 64.0)
# mc_035(hpbar_facegroup) 内 face = mc_034 的 Matrix tx=0.15。
# faceBar 图本身是 102x64，外框 picture_090 是 105x64；P2 通过外层镜像后视觉上右边贴齐，所以左侧补 3px。
const P1_FACE_BAR_POS: Vector2 = Vector2(0.15, 6.0)
const P2_FACE_BAR_POS: Vector2 = Vector2(701.0, 6.0)
const ENERGY_FRAME_SIZE: Vector2 = Vector2(140.0, 10.0)   # picture_061, energybar_barmc
const ENERGY_FILL_SIZE: Vector2 = Vector2(123.0, 5.0)     # picture_057 / shape_002
const QI_FRAME_SIZE: Vector2 = Vector2(191.0, 23.0)       # picture_063, qbar_barmc
const QI_FILL_SIZE: Vector2 = Vector2(139.0, 12.0)        # qbar_barmcgroup bar1/bar2/bar3/bar4
const QI_FILL_WIDTHS: Array[float] = [139.0, 139.0, 140.0, 140.0]
const FZ_QI_FRAME_SIZE: Vector2 = Vector2(66.0, 47.0)       # qbar_fzqi_mc: picture_072 / picture_043 / picture_073
const FZ_QI_FILL_SIZE: Vector2 = Vector2(64.0, 12.0)        # qbar_fzqi_mc.barmc
const FZ_QI_FACE_SIZE: Vector2 = Vector2(56.0, 39.0)        # qbar_facemc: picture_070 + picture_075
const FZ_QI_FACE_IMAGE_SIZE: Vector2 = Vector2(42.0, 30.0)  # qbar_facemc masked ct 区域的 Godot 近似
# 原版主气槽六边形不是从 qbar_mc 整帧裁图。
# qbar_facemc 独立由 gradient back(picture_071/085) + front(sprite_96) 组合；
# gradient 比 front 大 64x45，front 叠在其内侧约 (4,3)。
const QI_FACE_GRADIENT_SIZE: Vector2 = Vector2(64.0, 45.0)
const QI_FACE_FRONT_OFFSET_IN_GRADIENT: Vector2 = Vector2(4.0, 3.0)

# 原版 ui_fight / hpbar_mc 在 fadin_fin 帧附近的 800x600 坐标。
const P1_FACE_POS: Vector2 = Vector2(0.0, 6.0)
const P2_FACE_POS: Vector2 = Vector2(698.0, 6.0)
const P1_HP_POS: Vector2 = Vector2(100.0, 31.0)
const P2_HP_POS: Vector2 = Vector2(429.0, 31.0)
const P1_ENERGY_POS: Vector2 = Vector2(235.0, 55.0)
const P2_ENERGY_POS: Vector2 = Vector2(425.0, 55.0)
# 原版 3.8.4.3 顶部 HP 数字不是 score_mc 的黄色数字。
# 当前已导出的 fight.swf 数字资源里，time_txtmc/mc_016 的白色数字更接近原版 HP 数字视觉。
# HP 数字位置按 3.8.4.3 顶部 HUD 截图与 time_mc / shape_007 叠层位置校正：贴在中央无限框两侧的血条内侧。
const P1_HP_NUMBER_POS: Vector2 = Vector2(304.0, 34.0)
const P2_HP_NUMBER_POS: Vector2 = Vector2(452.0, 34.0)
# SPIRITUAL 不是单独摆在 HUD 上的独立图。
# 原版位置来自 hpbar_mc(mc_040) -> energy_bar(mc_032) -> txtmc 的嵌套 Matrix：
#   ui_fight.hpbarmc = (400, 45.6)
#   hpbar_mc.energy1 = (-25.05, 9.2)
#   hpbar_mc.energy2 = (a=-1, tx=24.45, ty=9.2)
#   energy_bar.txtmc = (-170.95, 5.1)
# 2P 的 energy2 外层水平镜像，同时 EnergyBar.as 对 txtmc 执行 setDirect(-1)，所以文字不倒置，
# 但全局位置要按镜像后的 x = 400 + 24.45 + 170.95 计算。
const HPBAR_MC_ENERGY1_POS: Vector2 = Vector2(-25.05, 9.2)
const HPBAR_MC_ENERGY2_POS: Vector2 = Vector2(24.45, 9.2)
const ENERGY_BAR_TXTMC_POS: Vector2 = Vector2(-170.95, 5.1)
const ENERGY_BAR_TXTMC_SIZE: Vector2 = Vector2(58.0, 12.0)
# 原版 txtmc 只是 mc_029 容器原点；可见的 SPIRITUAL 位图还在其子层里有偏移。
# comicType=0 时：mc_029(frame1) -> mc_027(frame1) -> mc_015 -> picture_092，
# 矩阵合成约为 x=-29, y=-6。Godot 使用的 spiritual_text.png 是 picture_092 可见位图，
# 所以不能直接放在 txtmc 原点，否则会比原版向右、向下偏。
const ENERGY_BAR_TXTMC_BITMAP_OFFSET: Vector2 = Vector2(-29.0, -6.0)
const P1_SPIRITUAL_POS: Vector2 = Vector2(175.0, 53.9)
const P2_SPIRITUAL_POS: Vector2 = Vector2(566.4, 53.9)
const HP_NUMBER_DIGIT_WIDTH: float = 23.0
const HP_NUMBER_SCALE: Vector2 = Vector2(0.45, 0.45)

# 原版 time_mc / 无限时间框本身包含左右黑白三角遮挡。
# 之前 Godot 侧把 83x62 原始图缩成 75x54 且 z 层低于血条，
# 导致中央框两侧无法覆盖血条端部，看起来绿色条没有铺满。
const TIME_FRAME_POS: Vector2 = Vector2(358.5, 14.0)
const TIME_FRAME_SIZE: Vector2 = Vector2(83.0, 62.0)
const TIME_INFINITY_POS: Vector2 = Vector2(378.0, 28.0)
const TIME_NUMBER_POS: Vector2 = Vector2(378.0, 30.0)
const TIME_FRAME_Z_INDEX: int = 75
const TIME_INNER_Z_INDEX: int = 76
# 原版 hpbar_mc / mc_040.xml 里 time_mc 左右还有一对 shape_007。
# shape_007 = picture_033，矩阵在 fadin_fin 帧：
#   left : tx=-33.75, ty=4.2；picture_033 tx=-12, ty=-15.5
#   right: a=-1, tx=33.25, ty=4.2；picture_033 tx=-12, ty=-15.5
# ui_fight 把 hpbar_mc 放在 (400,45.6)，所以这里直接换算到 800x600 HUD 坐标。
const TIME_JOIN_SLASH_SIZE: Vector2 = Vector2(33.0, 31.0)
const TIME_JOIN_SLASH_LEFT_POS: Vector2 = Vector2(354.25, 34.30)
const TIME_JOIN_SLASH_RIGHT_POS: Vector2 = Vector2(412.25, 34.30)
const TIME_JOIN_SLASH_Z_INDEX: int = TIME_FRAME_Z_INDEX - 1
# 原版 mc_044.xml: fzqi1 Matrix tx=48, ty=534.1；fzqi2 Matrix a=-1, tx=749, ty=534.1。
# mc_026.xml: barmc final Matrix tx=35.95, ty=24.45。
# 因此 P1 barmc 视觉左上角 = (83.95, 558.55)；P2 镜像后 barmc 视觉左上角 = 749 - 35.95 - 191 = 522.05。
const P1_QI_POS: Vector2 = Vector2(83.95, 558.55)
const P2_QI_POS: Vector2 = Vector2(522.05, 558.55)
# 原版底部主气槽不是两张独立图片，而是：ui_fight.fzqi1/fzqi2 -> qbar_mc(mc_026) -> barmc(mc_022)。
# fzqi1 的 Matrix 是 tx=48,ty=534.1；fzqi2 的 Matrix 是 a=-1,tx=749,ty=534.1。
# barmc 在 qbar_mc 稳定帧的 Matrix 是 tx=35.95,ty=24.45。
# 所以 1P barmc 视觉左上角 = 48+35.95, 534.1+24.45；
# 2P 是同一个 qbar_mc 整体镜像后的视觉左上角 = 749-35.95-191, 534.1+24.45。
# 因此 P1 内部条仍从本地左侧 scaleX 增长，P2 通过外层镜像产生从右往左增长的视觉结果。
const QBAR_ROOT_P1_POS: Vector2 = Vector2(48.0, 534.1)
const QBAR_ROOT_P2_MIRROR_TX: float = 749.0

# 原版 FightUI.as 会额外创建 player_pos_p1 / player_pos_p2，并在 render() 中用 getPlayerPos(fighter) 跟随角色。
# mc_047(player_pos_p1): picture_082, matrix tx=-18, ty=-51, 38x55
# mc_046(player_pos_p2): picture_018, matrix tx=-18, ty=-50, 39x55
const PLAYER_POS_P1_SIZE: Vector2 = Vector2(38.0, 55.0)
const PLAYER_POS_P2_SIZE: Vector2 = Vector2(39.0, 55.0)
const PLAYER_POS_P1_OFFSET: Vector2 = Vector2(-18.0, -51.0)
const PLAYER_POS_P2_OFFSET: Vector2 = Vector2(-18.0, -50.0)
# 原版 FightUI.getPlayerPos(fighter) 使用的是 BaseGameSprite 的脚底/地面坐标，再取 (0,-50)。
# Godot 当前 ManifestFighter.position 是 normalized PNG 的 Sprite2D 中心点，不是原版脚底点。
# v17 中把 Godot 的 normalized Sprite2D 中心点直接换算成脚底点时，偏移取值过大，导致 P1/P2 箭头压到角色脸部。
# 原版 FightUI.getPlayerPos(fighter) 仍然是 getGameSpriteGlobalPosition(fighter, 0, -50)，这里不改原版 -50 逻辑；
# 只修正 Godot 当前蓝染 PNG/scale/pivot 下“节点中心 -> 原版脚底点”的换算量，使 player_pos 图像底部贴近角色头顶。
const PLAYER_POS_GODOT_CENTER_TO_ORIGINAL_FOOT_Y: float = 108.75
const PLAYER_POS_ORIGINAL_Y_OFFSET: float = -50.0

# 原版 ui_fight 里 hpbarmc 的放置位置：mc_044.xml 中 hpbarmc matrix tx=400, ty=45.6。
# FightBar.as 的 fadIn/fadOut 不是简单 alpha，而是让 hpbar_mc 跳到 fadin/fadout 标签后逐帧 nextFrame()，直到 fadin_fin/fadout_fin。
const HPBAR_MC_ORIGIN: Vector2 = Vector2(400.0, 45.6)
const ORIGINAL_UI_FPS: float = 24.0
const HPBAR_FADIN_START_FRAME: float = 9.0
const HPBAR_FADIN_FIN_FRAME: float = 24.0
const HPBAR_FADOUT_START_FRAME: float = 34.0
const HPBAR_FADOUT_FIN_FRAME: float = 45.0
const QIBAR_FADIN_START_FRAME: float = 9.0
const QIBAR_FADIN_FIN_FRAME: float = 14.0
const QIBAR_FADOUT_START_FRAME: float = 32.0
const QIBAR_FADOUT_FIN_FRAME: float = 37.0

const HP_BAR_OFFSET: Vector2 = Vector2(4.0, 4.0)
const HP_GLASS_OFFSET: Vector2 = Vector2(1.5, 1.0)
# 旧版空槽遮罩函数保留但当前四层血条不再使用；定义常量避免 Godot 解析报错。
const HP_EMPTY_MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const ENERGY_FILL_OFFSET: Vector2 = Vector2(9.0, 2.0)
const QI_FILL_OFFSET: Vector2 = Vector2(9.7, 5.65)
const QI_FILL_OFFSET_P2: Vector2 = Vector2(42.3, 5.65)
# 原版 qbar_barmc / mc_022 的 txtmc 是独立 MovieClip：
# txtmc.gotoAndStop(int(qi / 100) + 1)。
# 当前 qibar_frame.png 是 FFDec 静态帧，里面烘进了 txtmc=0；
# 因此这里只遮住原始数字所在的小黑底区域，再把动态数字放在黑底中央。
const QI_NUM_OFFSET_P1: Vector2 = Vector2(157.0, 5.5)
const QI_NUM_OFFSET_P2: Vector2 = Vector2(22.0, 5.5)
const QI_NUM_MASK_OFFSET_P1: Vector2 = Vector2(155.0, 4.5)
const QI_NUM_MASK_OFFSET_P2: Vector2 = Vector2(20.0, 4.5)
const QI_NUM_MASK_SIZE: Vector2 = Vector2(15.0, 16.0)
const QI_NUM_MASK_COLOR: Color = Color(0.0, 0.018, 0.020, 1.0)
const QI_NUM_SIZE: Vector2 = Vector2(11.0, 14.0)
# qibar_frame.png 是 FFDec 静态帧，内部烘入了 bar4/full 的红色显示；
# 原版常态不是直接使用整帧，而是 qbar_barmc 内的 shape_001 底槽 + bar1/bar2/bar3/bar4 动态可见/scaleX。
# 这里用底槽颜色遮掉静态帧里烘入的彩色条，再按 InsBar.setProcess 绘制真实分段颜色。
const QI_TRACK_MASK_SIZE: Vector2 = Vector2(142.0, 13.0)
const QI_TRACK_MASK_COLOR: Color = Color(0.0, 0.018, 0.020, 1.0)
const FZ_QI_FRAME_OFFSET: Vector2 = Vector2(64.0, -43.0)
const FZ_QI_FILL_OFFSET: Vector2 = Vector2(65.0, -25.0)
const FZ_QI_READY_OFFSET: Vector2 = Vector2(114.0, -50.0)
const FZ_QI_SP_OFFSET: Vector2 = Vector2(70.0, -48.0)
const FZ_QI_FACE_OFFSET: Vector2 = Vector2(69.0, -39.0)
const FZ_QI_FACE_IMAGE_OFFSET: Vector2 = Vector2(76.0, -34.5)

# qbar_mc / mc_026 的主气条 barmc 原版关键帧。frame 11 有明显 overshoot，这版不再用线性侧滑粗略代替。
const QIBAR_XML_MAIN_FINAL_POS: Vector2 = Vector2(35.95, 24.45)

# qbar_mc / qbar_fzqi_mc 原版相对关键帧。
# 这些数值来自 fight.xfl 的 mc_026.xml：fzqibar、readymc、barmc 在 fadin/fadout 关键帧中的 Matrix。
const QIBAR_XML_FZ_FINAL_POS: Vector2 = Vector2(-15.0, 1.5)
const QIBAR_XML_FZ_FINAL_SCALE: float = 1.0
# mc_026.xml / facemc final Matrix: tx=-10.55, ty=5.0. barmc final Matrix: tx=35.95, ty=24.45.
# 所以主气槽头像框相对于 barmc/qibar_frame 的原版偏移是 (-46.5, -19.45)。
const QIBAR_XML_FACE_FINAL_POS: Vector2 = Vector2(-10.55, 5.0)
const QI_MAIN_FACE_OFFSET: Vector2 = QIBAR_XML_FACE_FINAL_POS - QIBAR_XML_MAIN_FINAL_POS
const QIBAR_XML_READY_FINAL_POS: Vector2 = Vector2(18.1, -2.9)
const ENERGY_FLASH_FRAME_STEP: float = 3.0

const RED_DELAY_DEFAULT: float = 0.35
const RED_DELAY_FLY: float = 0.75
const RED_LERP_DOWN: float = 8.0
const RED_LERP_UP: float = 18.0

var p1_hp_target: float = 1.0
var p2_hp_target: float = 1.0
var p1_hp_front: float = 1.0
var p2_hp_front: float = 1.0
var p1_hp_red: float = 1.0
var p2_hp_red: float = 1.0
var p1_last_hp_target: float = 1.0
var p2_last_hp_target: float = 1.0
var p1_red_delay: float = 0.0
var p2_red_delay: float = 0.0
var p1_energy_rate: float = 1.0
var p2_energy_rate: float = 1.0
var p1_qi_process: float = 0.0
var p2_qi_process: float = 0.0
var p1_fzqi_process: float = 0.0
var p2_fzqi_process: float = 0.0
var p1_can_hurt_break: bool = false
var p2_can_hurt_break: bool = false
var p1_energy_overload: bool = false
var p2_energy_overload: bool = false
var flash_time: float = 0.0
var current_p1_character: String = "aizen"
var current_p2_character: String = "aizen"

var p1_hp_frame: TextureRect
var p2_hp_frame: TextureRect
var p1_hp_glass: TextureRect
var p2_hp_glass: TextureRect
var p1_hp_red_bar: TextureRect
var p2_hp_red_bar: TextureRect
var p1_hp_front_bar: TextureRect
var p2_hp_front_bar: TextureRect
var p1_hp_empty_mask: ColorRect
var p2_hp_empty_mask: ColorRect
var p1_energy_frame: TextureRect
var p2_energy_frame: TextureRect
var p1_energy_bar: TextureRect
var p2_energy_bar: TextureRect
var p1_hp_number_mc: Control
var p2_hp_number_mc: Control
var p1_spiritual_text: TextureRect
var p2_spiritual_text: TextureRect
var p1_qi_frame: TextureRect
var p2_qi_frame: TextureRect
var p1_face_frame: TextureRect
var p2_face_frame: TextureRect
var p1_face: TextureRect
var p2_face: TextureRect
var p1_qi_bars: Array[TextureRect] = []
var p2_qi_bars: Array[TextureRect] = []
var p1_qi_num: TextureRect
var p2_qi_num: TextureRect
var p1_qi_num_mask: ColorRect
var p2_qi_num_mask: ColorRect
var p1_qi_track_mask: ColorRect
var p2_qi_track_mask: ColorRect
var p1_qbar_movie: TextureRect
var p2_qbar_movie: TextureRect
var p1_fzqi_frame: TextureRect
var p2_fzqi_frame: TextureRect
var p1_fzqi_bar: TextureRect
var p2_fzqi_bar: TextureRect
var p1_fzqi_ready: TextureRect
var p2_fzqi_ready: TextureRect
var p1_sp_prompt: TextureRect
var p2_sp_prompt: TextureRect
var p1_qi_face_back: TextureRect
var p2_qi_face_back: TextureRect
var p1_qi_face_image: TextureRect
var p2_qi_face_image: TextureRect
var p1_qi_face_gradient: TextureRect
var p2_qi_face_gradient: TextureRect
var p1_qi_face_front: TextureRect
var p2_qi_face_front: TextureRect
var p1_player_pos_icon: TextureRect
var p2_player_pos_icon: TextureRect
var time_join_slash_left: TextureRect
var time_join_slash_right: TextureRect
var original_camera_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(800.0, 600.0))
var original_camera_zoom: float = 1.0
var p1_info: Label
var p2_info: Label
var p1_combo_label: Label
var p2_combo_label: Label
var score_label: Label
var center_label: Label
var startko_animator: Control
var time_number_label: Label
var time_number_mc: Control
var score_number_mc: Control
var p1_combo_group: Control
var p2_combo_group: Control
var p1_combo_number_mc: Control
var p2_combo_number_mc: Control
var infinity_time_rect: TextureRect
var qi_visible_rate: float = 1.0
var qi_target_rate: float = 1.0
var hud_visible_rate: float = 1.0
var hud_target_rate: float = 1.0
var time_is_infinite: bool = true

# mc_040 / hpbar_mc 原版时间轴状态。mode = hold / fadin / fadout。
var hpbar_timeline_frame: float = HPBAR_FADIN_FIN_FRAME
var hpbar_timeline_mode: String = "hold"
var hpbar_timeline_playing: bool = false

# mc_026 / qbar_mc 原版时间轴状态。mode = hold / fadin / fadout。
var qibar_timeline_frame: float = QIBAR_FADIN_FIN_FRAME
var qibar_timeline_mode: String = "hold"
var qibar_timeline_playing: bool = false

var tex_hp_frame: Texture2D
var tex_hp_red: Texture2D
var tex_hp_front: Texture2D
var tex_hp_glass: Texture2D
var tex_hp_green_front: Texture2D
var tex_face_frame: Texture2D
var tex_energy_frame: Texture2D
var tex_energy_fill: Texture2D
var tex_energy_fill_frame1: Texture2D
var tex_energy_fill_frame2: Texture2D
var tex_energy_fill_overload: Texture2D
var tex_qi_frame: Texture2D
var tex_qi_bar1: Texture2D
var tex_qi_bar2: Texture2D
var tex_qi_bar3: Texture2D
var tex_qi_bar4: Texture2D
var tex_qi_nums: Array[Texture2D] = []
var tex_qbar_movie_frames: Array[Texture2D] = []
var tex_fzqi_frame: Texture2D
var tex_fzqi_bar: Texture2D
var tex_fzqi_ready: Texture2D
var tex_sp_prompt: Texture2D
var tex_qi_face_back: Texture2D
var tex_qi_face_gradient: Texture2D
var tex_qi_face_front: Texture2D
var tex_player_pos_p1: Texture2D
var tex_player_pos_p2: Texture2D
var tex_score_text: Texture2D
var tex_time_frame: Texture2D
var tex_time_join_slash: Texture2D
var tex_infinity_text: Texture2D
var tex_ready_text: Texture2D
var tex_hits_text: Texture2D
var tex_spiritual_text: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_original_textures()
	set_process(true)


func setup(p1_character: String, p2_character: String) -> void:
	current_p1_character = p1_character
	current_p2_character = p2_character
	clear_children()
	_load_original_textures()
	_build_original_layout(p1_character, p2_character)
	# 本项目按你的要求只做单回合、无限时间。
	# 原版 FightTimeUI.as 在 gameTimeMax == -1 时显示 _ui.wuxian，且不创建/渲染 MCNumber。
	set_time_left(-1, true)


func _process(delta: float) -> void:
	flash_time += delta
	_update_hp_animation(delta)
	# 原版 FightBar/QiBar 先按 MovieClip 时间轴确定整组 Matrix，再由 FighterHpBar/QiBar.render() 更新内部 bar.scaleX。
	# 之前先改 bar 宽度、后套 qbar_mc Matrix，会把 P2 气条的位置重置成从左往右增长。
	_update_fade_rates(delta)
	_apply_hp_sizes()
	_apply_energy_sizes()
	_apply_qi_process(p1_qi_bars, p1_qi_process, true)
	_apply_qi_process(p2_qi_bars, p2_qi_process, false)
	_apply_fzqi_process(true)
	_apply_fzqi_process(false)
	_update_energy_flash()


func set_camera_state(rect: Rect2, zoom: float) -> void:
	original_camera_rect = rect
	original_camera_zoom = maxf(0.001, zoom)


func update_state(p1_node: Variant, p2_node: Variant, _p1_score: int, _p2_score: int, p1_combo: int, p2_combo: int) -> void:
	var p1_hp: float = _node_float(p1_node, "hp", 1000.0)
	var p1_hp_max: float = maxf(1.0, _node_float(p1_node, "hp_max", 1000.0))
	var p2_hp: float = _node_float(p2_node, "hp", 1000.0)
	var p2_hp_max: float = maxf(1.0, _node_float(p2_node, "hp_max", 1000.0))

	p1_hp_target = clampf(p1_hp / p1_hp_max, 0.0, 1.0)
	p2_hp_target = clampf(p2_hp / p2_hp_max, 0.0, 1.0)
	_update_hp_number(p1_hp_number_mc, int(round(p1_hp)))
	_update_hp_number(p2_hp_number_mc, int(round(p2_hp)))
	_update_red_delay(p1_node, true)
	_update_red_delay(p2_node, false)

	var p1_qi: float = _node_float(p1_node, "qi", 0.0)
	var p2_qi: float = _node_float(p2_node, "qi", 0.0)
	p1_qi_process = clampf(p1_qi / 100.0, 0.0, 3.0)
	p2_qi_process = clampf(p2_qi / 100.0, 0.0, 3.0)
	_update_qi_number(p1_qi_num, _qibar_level_from_process(p1_qi_process))
	_update_qi_number(p2_qi_num, _qibar_level_from_process(p2_qi_process))

	var p1_fzqi: float = _node_float(p1_node, "fzqi", 0.0)
	var p2_fzqi: float = _node_float(p2_node, "fzqi", 0.0)
	p1_fzqi_process = clampf(p1_fzqi / 100.0, 0.0, 1.0)
	p2_fzqi_process = clampf(p2_fzqi / 100.0, 0.0, 1.0)
	p1_can_hurt_break = _node_can_hurt_break(p1_node, p1_fzqi_process)
	p2_can_hurt_break = _node_can_hurt_break(p2_node, p2_fzqi_process)

	var p1_energy: float = _node_float(p1_node, "energy", 100.0)
	var p1_energy_max: float = maxf(1.0, _node_float(p1_node, "energy_max", 100.0))
	var p2_energy: float = _node_float(p2_node, "energy", 100.0)
	var p2_energy_max: float = maxf(1.0, _node_float(p2_node, "energy_max", 100.0))
	p1_energy_rate = clampf(p1_energy / p1_energy_max, 0.0, 1.0)
	p2_energy_rate = clampf(p2_energy / p2_energy_max, 0.0, 1.0)
	p1_energy_overload = _node_bool(p1_node, "energy_overload", false)
	p2_energy_overload = _node_bool(p2_node, "energy_overload", false)

	# 原版 fight HUD 不显示调试 HP/QI/EN 文本；分数是 FightScoreUI 的一个全局 MCNumber。
	if p1_info != null:
		p1_info.visible = false
	if p2_info != null:
		p2_info.visible = false
	# 本 Demo 按你的要求不显示 arcade score。
	# 原版 FightScoreUI 逻辑存在于 fight.swf / FightScoreUI.as，但当前单回合复刻不渲染 score_mc / txtmc_score。
	# 不在这里写入 0000000，避免残留分数层。
	_update_combo_number(p1_combo_group, p1_combo_number_mc, p1_combo, true)
	_update_combo_number(p2_combo_group, p2_combo_number_mc, p2_combo, false)
	_update_player_pos_ui(p1_node, p2_node)


func show_ko() -> void:
	if startko_animator != null and startko_animator.has_method("play_ko"):
		startko_animator.call("play_ko")
	else:
		show_center_message("K.O.", 72, Color(1.0, 0.12, 0.04, 1.0))


func show_round_start(round_num: int = 1) -> void:
	if startko_animator != null and startko_animator.has_method("play_start"):
		startko_animator.call("play_start", round_num)
	else:
		show_center_message("ROUND " + str(round_num), 56, Color(1.0, 0.90, 0.18, 1.0))


func show_fight() -> void:
	# startKOAnimator 会在 mc_043 frame57 自动切到 FIGHT；这里保留 fallback。
	if startko_animator == null:
		show_center_message("FIGHT!", 72, Color(1.0, 0.22, 0.06, 1.0))


func show_winner(winner_id: int, perfect: bool = false) -> void:
	if startko_animator != null and startko_animator.has_method("play_winner"):
		startko_animator.call("play_winner", winner_id, perfect)
	else:
		var text_value: String = "P" + str(winner_id) + " WIN"
		if perfect:
			text_value += "\nPERFECT"
		show_center_message(text_value, 48, Color(1.0, 0.86, 0.12, 1.0))


func show_timeover() -> void:
	if startko_animator != null and startko_animator.has_method("play_timeover"):
		startko_animator.call("play_timeover")
	else:
		show_center_message("TIME OVER", 54, Color(1.0, 0.86, 0.12, 1.0))


func show_fight_in() -> void:
	# startKOAnimator 会在 mc_043 frame54 的 fight_in 进入 FIGHT 过渡；这里保留无 animator 时的 fallback。
	if startko_animator == null:
		show_center_message("FIGHT", 52, Color(1.0, 0.22, 0.06, 1.0))


func show_drawgame() -> void:
	if startko_animator != null and startko_animator.has_method("play_drawgame"):
		startko_animator.call("play_drawgame")
	else:
		show_center_message("DRAW GAME", 50, Color(1.0, 0.86, 0.12, 1.0))


func stop_all_round_end_animators() -> void:
	if startko_animator != null:
		if startko_animator.has_method("stop_anim"):
			startko_animator.call("stop_anim")
		if startko_animator is CanvasItem:
			var item := startko_animator as CanvasItem
			item.visible = false
			item.modulate.a = 0.0
		_force_hide_round_end_nodes(startko_animator)


func hide_ko() -> void:
	stop_all_round_end_animators()


func hide_timeover() -> void:
	stop_all_round_end_animators()


func hide_winner() -> void:
	stop_all_round_end_animators()


func hide_drawgame() -> void:
	stop_all_round_end_animators()


func clear_center_message() -> void:
	hide_center_message()
	stop_all_round_end_animators()


func _force_hide_round_end_nodes(node: Node) -> void:
	if node == null:
		return
	var lower_name: String = node.name.to_lower()
	var should_hide: bool = lower_name.find("winner") >= 0 or lower_name.find("ko") >= 0 or lower_name.find("draw") >= 0 or lower_name.find("timeover") >= 0 or lower_name.find("startko") >= 0 or lower_name.find("sequence") >= 0
	if should_hide and node is CanvasItem:
		var item := node as CanvasItem
		item.visible = false
		item.modulate.a = 0.0
	if node is ColorRect:
		var rect := node as ColorRect
		var c: Color = rect.color
		if c.r <= 0.08 and c.g <= 0.08 and c.b <= 0.08 and rect.size.x >= 160.0 and rect.size.y >= 80.0:
			rect.visible = false
			rect.modulate.a = 0.0
			rect.color = Color(c.r, c.g, c.b, 0.0)
	for child in node.get_children():
		_force_hide_round_end_nodes(child)


func set_time_left(time_left: int, is_infinite: bool = false) -> void:
	# 原版 FightTimeUI.as 在 gameTimeMax == -1 时 _renderTime=false，
	# 不刷新 MCNumber。当前 FFDec 原版 time_mc 背景已带无限符号，
	# 所以无限时间分支不显示任何额外数字/文字层。
	time_is_infinite = is_infinite
	_refresh_time_display_visibility()
	if time_is_infinite:
		return
	if time_number_mc != null and time_number_mc.has_method("set_number"):
		time_number_mc.call("set_number", maxi(0, time_left))

func _refresh_time_display_visibility() -> void:
	# 无限时间时：不显示 00，也不额外显示 wuxian；
	# 只保留 FFDec 原版 UI 背景里自带的无限符号。
	if time_number_label != null:
		time_number_label.visible = false
	if infinity_time_rect != null:
		infinity_time_rect.visible = false
	if time_number_mc != null:
		time_number_mc.visible = not time_is_infinite and hud_visible_rate > 0.01
		time_number_mc.modulate.a = hud_visible_rate


func fad_in(animate: bool = true) -> void:
	# 原版 FightUI.fadIn -> FightBar.fadIn + QiBar.fadIn。
	# FightBar.fadIn(animate=true) 会 gotoAndStop("fadin")，renderAnimate 每帧 nextFrame 到 fadin_fin。
	if animate:
		hpbar_timeline_mode = "fadin"
		hpbar_timeline_frame = HPBAR_FADIN_START_FRAME
		hpbar_timeline_playing = true
	else:
		hpbar_timeline_mode = "hold"
		hpbar_timeline_frame = HPBAR_FADIN_FIN_FRAME
		hpbar_timeline_playing = false
	hud_target_rate = 1.0
	hud_visible_rate = 1.0
	qibar_fad_in(animate)
	_apply_hud_alpha()
	_apply_original_hpbar_frame()
	_apply_original_qibar_frame()


func fad_out(animate: bool = true) -> void:
	# 原版 FightUI.fadOut -> FightBar.fadOut + QiBar.fadOut。
	# FightBar.fadOut(animate=true) 会 gotoAndStop("fadout")，renderAnimate 每帧 nextFrame 到 fadout_fin。
	if animate:
		hpbar_timeline_mode = "fadout"
		hpbar_timeline_frame = HPBAR_FADOUT_START_FRAME
		hpbar_timeline_playing = true
	else:
		hpbar_timeline_mode = "hold"
		hpbar_timeline_frame = HPBAR_FADOUT_FIN_FRAME
		hpbar_timeline_playing = false
	hud_target_rate = 0.0
	qibar_fad_out(animate)
	_apply_hud_alpha()
	_apply_original_hpbar_frame()
	_apply_original_qibar_frame()


func qibar_fad_out(animate: bool = true) -> void:
	# 原版 QiBar.fadOut：qbar_mc gotoAndStop("fadout")，直到 fadout_fin 后 visible=false。
	if animate:
		qibar_timeline_mode = "fadout"
		qibar_timeline_frame = QIBAR_FADOUT_START_FRAME
		qibar_timeline_playing = true
	else:
		qibar_timeline_mode = "hold"
		qibar_timeline_frame = QIBAR_FADOUT_FIN_FRAME
		qibar_timeline_playing = false
	qi_target_rate = 0.0
	_apply_hud_alpha()
	_apply_original_qibar_frame()


func qibar_fad_in(animate: bool = true) -> void:
	# 原版 QiBar.fadIn：qbar_mc gotoAndStop("fadin")，直到 fadin_fin。
	if animate:
		qibar_timeline_mode = "fadin"
		qibar_timeline_frame = QIBAR_FADIN_START_FRAME
		qibar_timeline_playing = true
	else:
		qibar_timeline_mode = "hold"
		qibar_timeline_frame = QIBAR_FADIN_FIN_FRAME
		qibar_timeline_playing = false
	qi_target_rate = 1.0
	qi_visible_rate = 1.0
	_apply_hud_alpha()
	_apply_original_qibar_frame()


func hide_center_message() -> void:
	if center_label != null:
		center_label.visible = false


func show_center_message(text_value: String, font_size: int, color: Color) -> void:
	if center_label == null:
		return
	center_label.text = text_value
	center_label.add_theme_font_size_override("font_size", font_size)
	center_label.add_theme_color_override("font_color", color)
	center_label.visible = true


func clear_children() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	p1_qi_bars.clear()
	p2_qi_bars.clear()


func _load_original_textures() -> void:
	# hpbar_barmc / mc_033 原版四层：
	# picture_076 -> 底框/空槽；picture_062 -> redbar；picture_047 -> bar；picture_008 -> 玻璃高光。
	tex_hp_frame = _load_tex("hpbar_frame.png")
	tex_hp_red = _load_tex("hpbar_redbar.png")
	tex_hp_front = _load_tex("hpbar_frontbar.png")
	tex_hp_glass = _load_tex("hpbar_top_glass.png")
	tex_hp_green_front = _load_tex_optional("hpbar_greenbar.jpg")
	if tex_hp_green_front == null:
		tex_hp_green_front = tex_hp_front
	tex_face_frame = _load_tex("hpbar_face_frame.png")
	tex_energy_frame = _load_tex("energybar_frame.png")
	tex_energy_fill = _load_tex("energybar_fill.png")
	tex_energy_fill_frame1 = _load_tex("energybar_fill_frame1.png")
	tex_energy_fill_frame2 = _load_tex("energybar_fill_frame2.png")
	tex_energy_fill_overload = _load_tex("energybar_fill_overload.png")
	tex_qi_frame = _load_tex("qibar_frame.png")
	tex_qi_bar1 = _load_tex("qibar_bar1.png")
	tex_qi_bar2 = _load_tex("qibar_bar2.png")
	tex_qi_bar3 = _load_tex("qibar_bar3.png")
	tex_qi_bar4 = _load_tex("qibar_bar4.png")
	tex_qi_nums = [_load_tex("qibar_num0.png"), _load_tex("qibar_num1.png"), _load_tex("qibar_num2.png"), _load_tex("qibar_num3.png")]
	tex_qbar_movie_frames.clear()
	for i: int in range(QBAR_MOVIE_FRAME_COUNT):
		var qbar_path: String = QBAR_MOVIE_DIR + "%04d.png" % i
		if ResourceLoader.exists(qbar_path):
			tex_qbar_movie_frames.append(load(qbar_path) as Texture2D)
	tex_fzqi_frame = _load_tex("qibar_fz_frame.png")
	tex_fzqi_bar = _load_tex("qibar_fz_bar.png")
	tex_fzqi_ready = _load_tex("qibar_fz_ready.png")
	tex_sp_prompt = _load_tex("qibar_sp_prompt.png")
	tex_qi_face_back = _load_tex("qibar_face_back.png")
	tex_qi_face_gradient = _load_tex("qibar_face_gradient.png")
	tex_qi_face_front = _load_tex("qibar_face_front.png")
	tex_player_pos_p1 = _load_tex("player_pos_p1.png")
	tex_player_pos_p2 = _load_tex("player_pos_p2.png")
	tex_score_text = _load_tex("score_text.png")
	tex_time_frame = _load_tex("time_frame.png")
	tex_time_join_slash = _load_tex("hpbar_time_join_slash.png")
	tex_infinity_text = _load_tex("infinity_text.png")
	tex_ready_text = _load_tex("ready_text.png")
	tex_hits_text = _load_tex("hits_text.png")
	tex_spiritual_text = _load_tex("spiritual_text.png")


func _build_original_layout(p1_character: String, p2_character: String) -> void:
	var top_mask: ColorRect = ColorRect.new()
	top_mask.name = "OriginalFightTopDarkMask"
	top_mask.position = Vector2(0.0, 0.0)
	top_mask.size = Vector2(800.0, 78.0)
	top_mask.color = Color(0.0, 0.0, 0.0, 0.22)
	add_child(top_mask)

	# 原版 hpbar_facemc：ct 中放入 102x64 faceBar，外层 frame / mask 再压上去。
	# P2 在原版 mc_040.xml 中不是重新计算一个新裁切框，而是 face2 外层 Matrix a=-1。
	# 所以 Godot 侧要把“P1 已裁切好的头像层 + frame overlay”整体做水平镜像，
	# 不能只在 shader 里单独镜像 UV 或单独镜像 mask。
	p1_face = _face_bar_rect("P1Face", p1_character, P1_FACE_BAR_POS, FACE_BAR_SIZE, false)
	p2_face = _face_bar_rect("P2Face", p2_character, P2_FACE_BAR_POS + Vector2(FACE_BAR_SIZE.x, 0.0), FACE_BAR_SIZE, false)
	p2_face.scale = Vector2(-1.0, 1.0)
	p1_face.z_index = 34
	p2_face.z_index = 34
	add_child(p1_face)
	add_child(p2_face)
	p1_face_frame = _tex_rect("P1FaceFrame", tex_face_frame, P1_FACE_POS, FACE_FRAME_SIZE, false)
	p2_face_frame = _tex_rect("P2FaceFrame", tex_face_frame, P2_FACE_POS + Vector2(FACE_FRAME_SIZE.x, 0.0), FACE_FRAME_SIZE, false)
	p2_face_frame.scale = Vector2(-1.0, 1.0)
	# hpbar_face_frame.png / picture_090 本身带黑色内底。
	# 原版 mc_034.xml 中 ct 头像层受 mask 裁切后显示在框内；
	# Godot 里如果直接把 picture_090 压在头像上层，会把头像完全盖黑。
	# 因此这里保留外框高光，但把原版 mask 内部区域打透明，让 faceBar 显示出来。
	# P2 通过节点 scale.x=-1 镜像整个 P1 结果，所以 overlay shader 仍使用 P1 的非镜像 mask。
	p1_face_frame.material = _make_face_frame_overlay_material(false)
	p2_face_frame.material = _make_face_frame_overlay_material(false)
	p1_face_frame.z_index = 35
	p2_face_frame.z_index = 35
	add_child(p1_face_frame)
	add_child(p2_face_frame)

	_build_hp_side(true)
	_build_hp_side(false)
	_build_energy_side(true)
	_build_energy_side(false)
	_build_hp_numbers_and_spiritual()
	_build_qi_side(true)
	_build_qi_side(false)
	_build_center_and_text()
	_build_player_pos_icons()


func _build_player_pos_icons() -> void:
	# 原版 FightUI.as 会创建 player_pos_p1 / player_pos_p2。
	# renderPlayerPosUI(zoom)：当 zoom > 1.8 时隐藏；否则显示并跟随角色全局坐标 (0,-50)。
	p1_player_pos_icon = _player_pos_icon("player_pos_p1", tex_player_pos_p1, Vector2(38.0, 55.0))
	p2_player_pos_icon = _player_pos_icon("player_pos_p2", tex_player_pos_p2, Vector2(39.0, 55.0))
	if p1_player_pos_icon != null:
		add_child(p1_player_pos_icon)
	if p2_player_pos_icon != null:
		add_child(p2_player_pos_icon)
	_set_player_pos_visible(false, false)


func _player_pos_icon(node_name: String, tex: Texture2D, rect_size: Vector2) -> TextureRect:
	if tex == null:
		return null
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = tex
	icon.size = rect_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	return icon


func _build_hp_side(is_p1: bool) -> void:
	var base: Vector2 = P1_HP_POS if is_p1 else P2_HP_POS
	var frame: TextureRect = _tex_rect("P1HpFrame" if is_p1 else "P2HpFrame", tex_hp_frame, base, HP_FRAME_SIZE, not is_p1)
	var red: TextureRect = _tex_rect("P1HpRed" if is_p1 else "P2HpRed", tex_hp_red, base + HP_BAR_OFFSET, HP_BAR_SIZE, not is_p1)
	var front: TextureRect = _tex_rect("P1HpFront" if is_p1 else "P2HpFront", tex_hp_green_front, base + HP_FRONT_OFFSET, HP_FRONT_SIZE, not is_p1)
	var glass: TextureRect = _tex_rect("P1HpGlass" if is_p1 else "P2HpGlass", tex_hp_glass, base + HP_GLASS_OFFSET, HP_GLASS_SIZE, not is_p1)
	# 原版 FighterHpBar.as 真正控制的是 bar/redbar 的 scaleX；
	# 3.8.4.3 实际截图中绿色 HP 前条不应被黑色网格盖住。
	# 当前 FFDec 拆出的 picture_008 / hpbar_top_glass 是整条黑色网格高光，
	# 在 Godot 里直接覆盖到绿色条上就会形成用户截图中的条纹。
	# 保留节点以免后续位置/alpha 代码报错，但默认隐藏，不再盖住 HP 前条。
	glass.visible = false
	glass.self_modulate.a = 0.0
	frame.z_index = 10
	red.z_index = 11
	front.z_index = 12
	glass.z_index = 13
	add_child(frame)
	add_child(red)
	add_child(front)
	add_child(glass)
	if is_p1:
		p1_hp_frame = frame
		p1_hp_red_bar = red
		p1_hp_front_bar = front
		p1_hp_empty_mask = null
		p1_hp_glass = glass
	else:
		p2_hp_frame = frame
		p2_hp_red_bar = red
		p2_hp_front_bar = front
		p2_hp_empty_mask = null
		p2_hp_glass = glass


func _build_energy_side(is_p1: bool) -> void:
	var base: Vector2 = P1_ENERGY_POS if is_p1 else P2_ENERGY_POS
	var frame: TextureRect = _tex_rect("P1EnergyFrame" if is_p1 else "P2EnergyFrame", tex_energy_frame, base, ENERGY_FRAME_SIZE, not is_p1)
	var bar: TextureRect = _tex_rect("P1EnergyBar" if is_p1 else "P2EnergyBar", tex_energy_fill, base + ENERGY_FILL_OFFSET, ENERGY_FILL_SIZE, not is_p1)
	add_child(frame)
	add_child(bar)
	if is_p1:
		p1_energy_frame = frame
		p1_energy_bar = bar
	else:
		p2_energy_frame = frame
		p2_energy_bar = bar


func _build_hp_numbers_and_spiritual() -> void:
	# 3.8.4.3 原版战斗 HUD 会在上方血条附近显示当前 HP 数值。
	# SPIRITUAL 按原版 energy_bar/mc_032.txtmc 的嵌套 Matrix 放置，不再用截图手调坐标。
	p1_hp_number_mc = MCNumberDisplay.new()
	p1_hp_number_mc.name = "P1OriginalHpNumber"
	p1_hp_number_mc.position = P1_HP_NUMBER_POS
	p1_hp_number_mc.size = Vector2(96.0, 32.0)
	p1_hp_number_mc.scale = HP_NUMBER_SCALE
	p1_hp_number_mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 原版 score 数字是黄橙色，用在 HP 会明显偏色；这里改用 fight.swf 的 time_txtmc 白色数字。
	p1_hp_number_mc.call("setup", "res://assets/ui/fight/mcnumber/time", HP_NUMBER_DIGIT_WIDTH, 0, HORIZONTAL_ALIGNMENT_LEFT)
	p1_hp_number_mc.z_index = 90
	add_child(p1_hp_number_mc)

	p2_hp_number_mc = MCNumberDisplay.new()
	p2_hp_number_mc.name = "P2OriginalHpNumber"
	p2_hp_number_mc.position = P2_HP_NUMBER_POS
	p2_hp_number_mc.size = Vector2(96.0, 32.0)
	p2_hp_number_mc.scale = HP_NUMBER_SCALE
	p2_hp_number_mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# P2 同样使用 time_txtmc 白色数字，并贴近中央框右侧。
	p2_hp_number_mc.call("setup", "res://assets/ui/fight/mcnumber/time", HP_NUMBER_DIGIT_WIDTH, 0, HORIZONTAL_ALIGNMENT_LEFT)
	p2_hp_number_mc.z_index = 90
	add_child(p2_hp_number_mc)

	p1_spiritual_text = _tex_rect("P1SpiritualText", tex_spiritual_text, _original_spiritual_position(true), ENERGY_BAR_TXTMC_SIZE, false)
	p2_spiritual_text = _tex_rect("P2SpiritualText", tex_spiritual_text, _original_spiritual_position(false), ENERGY_BAR_TXTMC_SIZE, false)
	p1_spiritual_text.z_index = 70
	p2_spiritual_text.z_index = 70
	add_child(p1_spiritual_text)
	add_child(p2_spiritual_text)


func _build_qi_side(is_p1: bool) -> void:
	var base: Vector2 = P1_QI_POS if is_p1 else P2_QI_POS
	# 原版 qbar_mc 持有状态由 QiBar.as / InsBar.setProcess 动态控制 barmc：
	# qbar_frame 作为底层外观，bar1/bar2/bar3/bar4 叠在其上，txtmc 只显示当前层数的一帧。
	# P2 不是单独素材，而是 fzqi2 的 a=-1 外层镜像；因此这里 P2 的 frame/bar 使用同一套资源并水平翻转。
	var frame: TextureRect = _tex_rect("P1QiFrame" if is_p1 else "P2QiFrame", tex_qi_frame, base, QI_FRAME_SIZE, not is_p1)
	frame.z_index = 20
	add_child(frame)
	# qibar_frame 的 FFDec 静态图包含烘入的满段红条；原版 InsBar.setProcess 会动态控制 bar1/2/3/4，
	# 因此先遮掉静态彩色条，再在上层绘制原版 bar1->bar2->bar3->bar4。
	var track_mask := ColorRect.new()
	track_mask.name = "P1QiTrackMask" if is_p1 else "P2QiTrackMask"
	track_mask.position = _qi_fill_base_position(is_p1, base) + Vector2(-1.0, -0.5)
	track_mask.size = QI_TRACK_MASK_SIZE
	track_mask.color = QI_TRACK_MASK_COLOR
	track_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_mask.z_index = 21
	add_child(track_mask)
	var bars: Array[TextureRect] = []
	var textures: Array[Texture2D] = [tex_qi_bar1, tex_qi_bar2, tex_qi_bar3, tex_qi_bar4]
	for i: int in range(4):
		var bar_size: Vector2 = Vector2(139.0, 12.0) if i < 2 else Vector2(140.0, 12.0)
		var bar: TextureRect = _tex_rect(("P1QiBar" if is_p1 else "P2QiBar") + str(i + 1), textures[i], _qi_fill_base_position(is_p1, base), bar_size, not is_p1)
		bar.visible = false
		bar.z_index = 22 + i
		add_child(bar)
		bars.append(bar)
	var num_mask := ColorRect.new()
	num_mask.name = "P1QiNumMask" if is_p1 else "P2QiNumMask"
	num_mask.position = _qi_num_mask_position(is_p1, base)
	num_mask.size = QI_NUM_MASK_SIZE
	num_mask.color = QI_NUM_MASK_COLOR
	num_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_mask.z_index = 44
	add_child(num_mask)
	var num: TextureRect = _tex_rect("P1QiNum" if is_p1 else "P2QiNum", tex_qi_nums[0], _qi_num_position(is_p1, base), QI_NUM_SIZE, false)
	num.z_index = 45
	num.flip_h = false
	add_child(num)

	# 原版 QiBar.as 同时管理主气条 barmc、辅助气条 fzqibar、readymc、sp 提示和 qbar_facemc。
	# O 支援/换人已按你的要求忽略；这里保留 HUD 资源与 fzqi/破招提示显示逻辑。
	var qi_face_back: TextureRect = _tex_rect("P1QiFaceBack" if is_p1 else "P2QiFaceBack", tex_qi_face_back, base + FZ_QI_FACE_OFFSET, FZ_QI_FACE_SIZE, not is_p1)
	var qi_face_image: TextureRect = _face_rect("P1QiFaceImage" if is_p1 else "P2QiFaceImage", current_p1_character if is_p1 else current_p2_character, base + FZ_QI_FACE_IMAGE_OFFSET, FZ_QI_FACE_IMAGE_SIZE, not is_p1)
	# 主气槽 facemc 前框按原版 qbar_facemc 子层重建：
	# gradient back 独立一层，front 黑色六边形/青色边框再压上去；不再从 qbar_mc 整帧裁切。
	var qi_face_gradient: TextureRect = _tex_rect("P1QiFaceGradient" if is_p1 else "P2QiFaceGradient", tex_qi_face_gradient, _qi_main_face_gradient_position(is_p1, base, Vector2.ZERO), QI_FACE_GRADIENT_SIZE, not is_p1)
	var qi_face_front: TextureRect = _tex_rect("P1QiFaceFront" if is_p1 else "P2QiFaceFront", tex_qi_face_front, _qi_main_face_position(is_p1, base, Vector2.ZERO), FZ_QI_FACE_SIZE, not is_p1)
	var fz_frame: TextureRect = _tex_rect("P1FzQiFrame" if is_p1 else "P2FzQiFrame", tex_fzqi_frame, base + FZ_QI_FRAME_OFFSET, FZ_QI_FRAME_SIZE, not is_p1)
	var fz_bar: TextureRect = _tex_rect("P1FzQiBar" if is_p1 else "P2FzQiBar", tex_fzqi_bar, base + FZ_QI_FILL_OFFSET, FZ_QI_FILL_SIZE, not is_p1)
	var fz_ready: TextureRect = _tex_rect("P1FzQiReady" if is_p1 else "P2FzQiReady", tex_fzqi_ready, base + FZ_QI_READY_OFFSET, Vector2(58.0, 18.0), not is_p1)
	var sp_prompt: TextureRect = _tex_rect("P1SpPrompt" if is_p1 else "P2SpPrompt", tex_sp_prompt, base + FZ_QI_SP_OFFSET, Vector2(64.0, 18.0), not is_p1)
	qi_face_back.z_index = 26
	qi_face_image.z_index = 27
	qi_face_gradient.z_index = 28
	qi_face_front.z_index = 29
	fz_frame.z_index = 18
	fz_bar.z_index = 19
	fz_ready.z_index = 31
	sp_prompt.z_index = 31
	qi_face_back.visible = false
	qi_face_image.visible = false
	# qbar_mc 的主 facemc 外观常驻显示；辅助头像 bitmap 仍在 fzqi 条满/显示时再出现。
	qi_face_gradient.visible = true
	qi_face_front.visible = true
	fz_frame.visible = false
	fz_bar.visible = false
	fz_ready.visible = false
	sp_prompt.visible = false
	add_child(qi_face_back)
	add_child(qi_face_image)
	add_child(qi_face_gradient)
	add_child(qi_face_front)
	add_child(fz_frame)
	add_child(fz_bar)
	add_child(fz_ready)
	add_child(sp_prompt)
	var qbar_movie_pos: Vector2 = QBAR_MOVIE_P1_POS if is_p1 else QBAR_MOVIE_P2_POS
	var qbar_movie: TextureRect = _tex_rect("P1QbarMovie" if is_p1 else "P2QbarMovie", _qbar_movie_texture_for_side(is_p1), qbar_movie_pos, QBAR_MOVIE_SIZE, not is_p1)
	# qbar_movie 只用于 fadin/fadout 时间轴；持有状态必须按 QiBar.as 动态更新 barmc 子层。
	qbar_movie.z_index = 19
	qbar_movie.visible = false
	qbar_movie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(qbar_movie)
	if is_p1:
		p1_qi_frame = frame
		p1_qi_bars = bars
		p1_qi_num = num
		p1_qi_num_mask = num_mask
		p1_qi_track_mask = track_mask
		p1_qbar_movie = qbar_movie
		p1_fzqi_frame = fz_frame
		p1_fzqi_bar = fz_bar
		p1_fzqi_ready = fz_ready
		p1_sp_prompt = sp_prompt
		p1_qi_face_back = qi_face_back
		p1_qi_face_image = qi_face_image
		p1_qi_face_gradient = qi_face_gradient
		p1_qi_face_front = qi_face_front
	else:
		p2_qi_frame = frame
		p2_qi_bars = bars
		p2_qi_num = num
		p2_qi_num_mask = num_mask
		p2_qi_track_mask = track_mask
		p2_qbar_movie = qbar_movie
		p2_fzqi_frame = fz_frame
		p2_fzqi_bar = fz_bar
		p2_fzqi_ready = fz_ready
		p2_sp_prompt = sp_prompt
		p2_qi_face_back = qi_face_back
		p2_qi_face_image = qi_face_image
		p2_qi_face_gradient = qi_face_gradient
		p2_qi_face_front = qi_face_front


func _build_center_and_text() -> void:
	# 原版 center time_mc / 无限符号框位于 FightBar 上层；
	# 它自身盖住 HP 条靠近中心处的斜边/空隙。
	# 另外 hpbar_mc / mc_040.xml 在 time_mc 左右各放了一个 shape_007，
	# shape_007 使用 picture_033，右侧通过 a=-1 镜像。
	# 因此这里先放左右连接斜片，再放 time_mc。time_mc 的 z_index 更高，保持原版覆盖关系。
	time_join_slash_left = _tex_rect("OriginalTimeJoinSlashLeft", tex_time_join_slash, TIME_JOIN_SLASH_LEFT_POS, TIME_JOIN_SLASH_SIZE, false)
	time_join_slash_left.z_index = TIME_JOIN_SLASH_Z_INDEX
	time_join_slash_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_join_slash_left)
	time_join_slash_right = _tex_rect("OriginalTimeJoinSlashRight", tex_time_join_slash, TIME_JOIN_SLASH_RIGHT_POS, TIME_JOIN_SLASH_SIZE, true)
	time_join_slash_right.z_index = TIME_JOIN_SLASH_Z_INDEX
	time_join_slash_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_join_slash_right)

	# 因此这里用 FFDec 导出的原始 83x62 尺寸，不再缩成 75x54。
	var time_frame: TextureRect = _tex_rect("OriginalTimeFrame", tex_time_frame, TIME_FRAME_POS, TIME_FRAME_SIZE, false)
	time_frame.z_index = TIME_FRAME_Z_INDEX
	time_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_frame)
	infinity_time_rect = _tex_rect("OriginalInfinityTime", tex_infinity_text, TIME_INFINITY_POS, Vector2(43.0, 27.0), false)
	infinity_time_rect.z_index = TIME_INNER_Z_INDEX
	# 现在使用 FFDec 导出的原版 time_mc 背景；无限符号已经在背景层中，
	# 不再额外叠加 wuxian / MCNumber，避免显示成 00 或重复无限符号。
	infinity_time_rect.visible = false
	add_child(infinity_time_rect)
	# 原版 FightTimeUI: new MCNumber(time_txtmc, 0, 1, 20, 2)，x=-22, y=-15。
	time_number_label = null
	time_number_mc = MCNumberDisplay.new()
	time_number_mc.name = "OriginalTimeMCNumber"
	time_number_mc.position = TIME_NUMBER_POS
	time_number_mc.size = Vector2(44.0, 31.0)
	time_number_mc.z_index = TIME_INNER_Z_INDEX + 1
	time_number_mc.call("setup", "res://assets/ui/fight/mcnumber/time", 20.0, 2, HORIZONTAL_ALIGNMENT_CENTER)
	time_number_mc.visible = false
	add_child(time_number_mc)

	# 原版 fight.swf 中确实包含 score_mc / txtmc_score；但当前项目只做单回合对战，
	# 你明确要求不显示 SCORE 和 0000000，所以这里不实例化 FightScoreUI。
	score_label = null
	score_number_mc = null

	# 调试数值文本不属于原版 HUD，默认隐藏，只保留变量避免旧逻辑空引用。
	p1_info = _make_label("", Vector2(108.0, 8.0), Vector2(255.0, 18.0), 11, Color(1.0, 1.0, 1.0, 0.0), HORIZONTAL_ALIGNMENT_LEFT)
	p2_info = _make_label("", Vector2(437.0, 8.0), Vector2(255.0, 18.0), 11, Color(1.0, 1.0, 1.0, 0.0), HORIZONTAL_ALIGNMENT_RIGHT)
	p1_info.visible = false
	p2_info.visible = false
	add_child(p1_info)
	add_child(p2_info)

	p1_combo_label = null
	p2_combo_label = null
	_build_hits_group(true)
	_build_hits_group(false)

	center_label = _make_label("", Vector2(250.0, 210.0), Vector2(300.0, 100.0), 64, Color(1.0, 0.12, 0.04, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.visible = false
	add_child(center_label)

	startko_animator = FightStartKOAnimator.new()
	startko_animator.name = "OriginalStartKOAnimator"
	startko_animator.position = Vector2.ZERO
	startko_animator.size = Vector2(800.0, 600.0)
	add_child(startko_animator)



func _update_fade_rates(delta: float) -> void:
	_update_original_hpbar_timeline(delta)
	_update_original_qibar_timeline(delta)
	# timeline 帧负责具体位移/缩放；alpha 只负责整体可见性和 qibar fade 完成隐藏。
	if not hpbar_timeline_playing:
		hud_visible_rate = _fade_rate_towards(hud_visible_rate, hud_target_rate, delta)
	if not qibar_timeline_playing:
		qi_visible_rate = _fade_rate_towards(qi_visible_rate, qi_target_rate, delta)
	_apply_hud_alpha()
	_apply_original_hpbar_frame()
	_apply_original_qibar_frame()


func _update_original_hpbar_timeline(delta: float) -> void:
	if not hpbar_timeline_playing:
		return
	hpbar_timeline_frame += delta * ORIGINAL_UI_FPS
	if hpbar_timeline_mode == "fadin" and hpbar_timeline_frame >= HPBAR_FADIN_FIN_FRAME:
		hpbar_timeline_frame = HPBAR_FADIN_FIN_FRAME
		hpbar_timeline_mode = "hold"
		hpbar_timeline_playing = false
		hud_target_rate = 1.0
		hud_visible_rate = 1.0
	elif hpbar_timeline_mode == "fadout" and hpbar_timeline_frame >= HPBAR_FADOUT_FIN_FRAME:
		hpbar_timeline_frame = HPBAR_FADOUT_FIN_FRAME
		hpbar_timeline_mode = "hold"
		hpbar_timeline_playing = false
		hud_target_rate = 0.0
		hud_visible_rate = 0.0


func _update_original_qibar_timeline(delta: float) -> void:
	if not qibar_timeline_playing:
		return
	qibar_timeline_frame += delta * ORIGINAL_UI_FPS
	if qibar_timeline_mode == "fadin" and qibar_timeline_frame >= QIBAR_FADIN_FIN_FRAME:
		qibar_timeline_frame = QIBAR_FADIN_FIN_FRAME
		qibar_timeline_mode = "hold"
		qibar_timeline_playing = false
		qi_target_rate = 1.0
		qi_visible_rate = 1.0
	elif qibar_timeline_mode == "fadout" and qibar_timeline_frame >= QIBAR_FADOUT_FIN_FRAME:
		qibar_timeline_frame = QIBAR_FADOUT_FIN_FRAME
		qibar_timeline_mode = "hold"
		qibar_timeline_playing = false
		qi_target_rate = 0.0
		qi_visible_rate = 0.0


func _fade_rate_towards(current: float, target: float, delta: float) -> float:
	var next_value: float = current + (target - current) * clampf(delta * 8.0, 0.0, 1.0)
	if absf(next_value - target) < 0.01:
		return target
	return next_value


func _apply_hud_alpha() -> void:
	var fightbar_alpha: float = hud_visible_rate
	if hpbar_timeline_playing and hpbar_timeline_mode == "fadin":
		fightbar_alpha = clampf((hpbar_timeline_frame - HPBAR_FADIN_START_FRAME) / maxf(1.0, HPBAR_FADIN_FIN_FRAME - HPBAR_FADIN_START_FRAME), 0.0, 1.0)
	elif hpbar_timeline_playing and hpbar_timeline_mode == "fadout":
		fightbar_alpha = 1.0

	var top_nodes: Array[CanvasItem] = [p1_hp_frame, p2_hp_frame, p1_hp_glass, p2_hp_glass, p1_hp_red_bar, p2_hp_red_bar, p1_hp_front_bar, p2_hp_front_bar, p1_hp_empty_mask, p2_hp_empty_mask, p1_energy_frame, p2_energy_frame, p1_energy_bar, p2_energy_bar, p1_face_frame, p2_face_frame, p1_face, p2_face, p1_hp_number_mc, p2_hp_number_mc, p1_spiritual_text, p2_spiritual_text, p1_info, p2_info]
	for node: CanvasItem in top_nodes:
		if node != null:
			node.modulate.a = fightbar_alpha
			node.visible = fightbar_alpha > 0.01
	# HitsUI 的 visible 必须由 OriginalHitsDisplay.show_hits/hide_hits 控制，不能在 HUD 淡入时强制显示。
	for combo_node: Control in [p1_combo_group, p2_combo_group]:
		if combo_node != null:
			combo_node.modulate.a = fightbar_alpha
	_refresh_time_display_visibility()

	var qi_alpha: float = qi_visible_rate
	if qibar_timeline_playing and qibar_timeline_mode == "fadin":
		qi_alpha = clampf((qibar_timeline_frame - QIBAR_FADIN_START_FRAME) / maxf(1.0, QIBAR_FADIN_FIN_FRAME - QIBAR_FADIN_START_FRAME), 0.0, 1.0)
	elif qibar_timeline_playing and qibar_timeline_mode == "fadout":
		qi_alpha = 1.0

	var qi_nodes: Array[CanvasItem] = [p1_qi_frame, p2_qi_frame, p1_qi_num, p2_qi_num]
	for node: CanvasItem in qi_nodes:
		if node != null:
			node.modulate.a = qi_alpha
			node.visible = qi_alpha > 0.01
	for bar: TextureRect in p1_qi_bars:
		if bar != null:
			bar.modulate.a = qi_alpha
			bar.visible = bar.visible and qi_alpha > 0.01
	for bar: TextureRect in p2_qi_bars:
		if bar != null:
			bar.modulate.a = qi_alpha
			bar.visible = bar.visible and qi_alpha > 0.01


func _apply_original_hpbar_frame() -> void:
	# 近似复刻 mc_040.xml / hpbar_mc 的关键帧位移。Godot 仍使用已提取 PNG 皮肤，但位移节奏遵守原版标签和帧段。
	var f: float = hpbar_timeline_frame
	var p1_hp_delta: Vector2 = _mc040_delta_p1_hp(f)
	var p2_hp_delta: Vector2 = _mc040_delta_p2_hp(f)
	var p1_face_delta: Vector2 = _mc040_delta_p1_face(f)
	var p2_face_delta: Vector2 = _mc040_delta_p2_face(f)
	var p1_energy_delta: Vector2 = _mc040_delta_p1_energy(f)
	var p2_energy_delta: Vector2 = _mc040_delta_p2_energy(f)
	var time_delta: Vector2 = _mc040_delta_time(f)
	_apply_hp_side_positions(true, p1_hp_delta)
	_apply_hp_side_positions(false, p2_hp_delta)
	_apply_face_positions(true, p1_face_delta)
	_apply_face_positions(false, p2_face_delta)
	_apply_energy_positions(true, p1_energy_delta)
	_apply_energy_positions(false, p2_energy_delta)
	_apply_hp_number_positions(true, p1_hp_delta)
	_apply_hp_number_positions(false, p2_hp_delta)
	_apply_spiritual_positions(true, p1_energy_delta)
	_apply_spiritual_positions(false, p2_energy_delta)
	_apply_time_positions(time_delta)
	# mc_040 时间轴先决定整组位置；随后按 FighterHpBar / EnergyBar 原版比例更新条的 scale/size。
	_apply_hp_sizes()
	_apply_energy_sizes()



func _has_original_qbar_movie() -> bool:
	return tex_qbar_movie_frames.size() >= QBAR_MOVIE_FRAME_COUNT


func _using_qbar_movie_timeline() -> bool:
	# 只表示正在播放 qbar_mc 的 fadin/fadout 时间轴。
	return _has_original_qbar_movie() and qibar_timeline_playing


func _using_qbar_movie_base() -> bool:
	# 持有状态不能直接使用 FFDec 导出的 qbar_mc 整帧截图。原版 QiBar.as 在运行时会改 barmc.bar1/bar2/bar3
	# 的 scaleX 和 txtmc 当前帧；整帧 PNG 只适合 fadin/fadout 时间轴，不适合当动态底图。
	return false


func _qbar_movie_texture_for_side(is_p1: bool) -> Texture2D:
	if not _has_original_qbar_movie():
		return null
	var value: float = p1_qi_process if is_p1 else p2_qi_process
	var idx: int = _qbar_movie_frame_index(value)
	return tex_qbar_movie_frames[clampi(idx, 0, tex_qbar_movie_frames.size() - 1)]


func _qbar_movie_frame_index(value: float) -> int:
	if qibar_timeline_playing:
		return clampi(int(round(qibar_timeline_frame)), 0, QBAR_MOVIE_FRAME_COUNT - 1)
	var segment: int = int(floor(clampf(value, 0.0, 3.0)))
	if segment <= 0:
		return QBAR_MOVIE_HOLD_FRAME_0
	if segment == 1:
		return QBAR_MOVIE_HOLD_FRAME_1
	if segment == 2:
		return QBAR_MOVIE_HOLD_FRAME_2
	return QBAR_MOVIE_HOLD_FRAME_3


func _apply_qbar_movie_side(is_p1: bool, alpha: float) -> void:
	if not _has_original_qbar_movie():
		return
	var movie: TextureRect = p1_qbar_movie if is_p1 else p2_qbar_movie
	if movie == null:
		return
	movie.texture = _qbar_movie_texture_for_side(is_p1)
	movie.position = QBAR_MOVIE_P1_POS if is_p1 else QBAR_MOVIE_P2_POS
	movie.size = QBAR_MOVIE_SIZE
	movie.flip_h = not is_p1
	movie.visible = alpha > 0.01
	movie.modulate.a = alpha


func _hide_manual_main_qbar_nodes() -> void:
	# 使用原版 qbar_mc 整数段帧作为底层时，隐藏旧 qibar_frame / txtmc / facemc 前框，避免数字 0 与当前层数数字叠成“01”。
	# bar1/bar2/bar3 不在这里隐藏，它们用于复刻 InsBar.setProcess 的连续缩放。
	var nodes: Array[CanvasItem] = [p1_qi_frame, p2_qi_frame, p1_qi_track_mask, p2_qi_track_mask, p1_qi_num_mask, p2_qi_num_mask, p1_qi_num, p2_qi_num, p1_qi_face_gradient, p2_qi_face_gradient, p1_qi_face_front, p2_qi_face_front]
	for node: CanvasItem in nodes:
		if node != null:
			node.visible = false


func _set_qbar_movie_visible(value: bool) -> void:
	if p1_qbar_movie != null:
		p1_qbar_movie.visible = value
	if p2_qbar_movie != null:
		p2_qbar_movie.visible = value


func _apply_original_qibar_frame() -> void:
	# mc_026.xml / qbar_mc：主气条 barmc 的 fadin 有 overshoot，frame 11 会先冲到更左，再回到 frame14 的最终位置。
	# P2 使用水平镜像的同一条时间轴。
	var main_delta: Vector2 = _qibar_main_extra_delta(qibar_timeline_frame)
	var p1_delta: Vector2 = main_delta
	var p2_delta: Vector2 = Vector2(-main_delta.x, main_delta.y)
	_apply_qi_side_positions(true, p1_delta)
	_apply_qi_side_positions(false, p2_delta)
	if _using_qbar_movie_base():
		var alpha: float = _current_qi_alpha()
		_apply_qbar_movie_side(true, alpha)
		_apply_qbar_movie_side(false, alpha)
		_hide_manual_main_qbar_nodes()
	else:
		_set_qbar_movie_visible(false)


func _mc040_delta_p1_hp(f: float) -> Vector2:
	var v0: Vector2 = Vector2(0.0, -140.0)
	var v1: Vector2 = Vector2(262.0, 0.0)
	var v2: Vector2 = Vector2(-103.0, 0.0)
	var v3: Vector2 = Vector2(0.0, 0.0)
	var v4: Vector2 = Vector2(274.0, 0.0)
	var v5: Vector2 = Vector2(274.0, -70.0)
	return _mc040_piecewise(f, 9.0, v0, 14.0, v1, 18.0, v2, 24.0, v3, 36.0, v3, 42.0, v4, 43.0, v5)


func _mc040_delta_p2_hp(f: float) -> Vector2:
	var v0: Vector2 = Vector2(0.0, -140.0)
	var v1: Vector2 = Vector2(-262.0, 0.0)
	var v2: Vector2 = Vector2(102.0, 0.0)
	var v3: Vector2 = Vector2(0.0, 0.0)
	var v4: Vector2 = Vector2(-272.0, 0.0)
	var v5: Vector2 = Vector2(-272.0, -70.0)
	return _mc040_piecewise(f, 9.0, v0, 14.0, v1, 18.0, v2, 24.0, v3, 36.0, v3, 42.0, v4, 43.0, v5)


func _mc040_delta_p1_face(f: float) -> Vector2:
	var v0: Vector2 = Vector2(0.0, -140.0)
	var v1: Vector2 = Vector2(-100.0, 0.0)
	var v2: Vector2 = Vector2(0.0, 0.0)
	var v3: Vector2 = Vector2(-100.0, 0.0)
	var v4: Vector2 = Vector2(-110.0, 0.0)
	var v5: Vector2 = Vector2(-110.0, -80.0)
	return _mc040_piecewise(f, 9.0, v0, 18.0, v1, 24.0, v2, 36.0, v3, 39.0, v4, 40.0, v5, 48.0, v5)


func _mc040_delta_p2_face(f: float) -> Vector2:
	var v0: Vector2 = Vector2(0.0, -140.0)
	var v1: Vector2 = Vector2(98.0, 0.0)
	var v2: Vector2 = Vector2(0.0, 0.0)
	var v3: Vector2 = Vector2(115.0, 0.0)
	var v4: Vector2 = Vector2(115.0, -80.0)
	return _mc040_piecewise(f, 9.0, v0, 18.0, v1, 24.0, v2, 36.0, v2, 39.0, v3, 40.0, v4, 48.0, v4)


func _mc040_delta_p1_energy(f: float) -> Vector2:
	var v0: Vector2 = Vector2(-25.0, -140.0)
	var v1: Vector2 = Vector2(25.0, 0.0)
	var v2: Vector2 = Vector2(0.0, 0.0)
	var v3: Vector2 = Vector2(22.0, 0.0)
	var v4: Vector2 = Vector2(22.0, -90.0)
	return _mc040_piecewise(f, 9.0, v0, 16.0, v1, 22.0, v2, 34.0, v2, 39.0, v3, 40.0, v4, 48.0, v4)


func _mc040_delta_p2_energy(f: float) -> Vector2:
	var v0: Vector2 = Vector2(25.0, -140.0)
	var v1: Vector2 = Vector2(-25.0, 0.0)
	var v2: Vector2 = Vector2(0.0, 0.0)
	var v3: Vector2 = Vector2(-23.0, 0.0)
	var v4: Vector2 = Vector2(-23.0, -90.0)
	return _mc040_piecewise(f, 9.0, v0, 16.0, v1, 22.0, v2, 34.0, v2, 39.0, v3, 40.0, v4, 48.0, v4)


func _mc040_delta_time(f: float) -> Vector2:
	var v0: Vector2 = Vector2(0.0, -140.0)
	var v1: Vector2 = Vector2(0.0, 0.0)
	var v2: Vector2 = Vector2(0.0, -75.0)
	return _mc040_piecewise(f, 9.0, v0, 12.0, v0, 24.0, v1, 42.0, v1, 45.0, v2, 48.0, v2, 49.0, v2)


func _mc040_delta_score(f: float) -> Vector2:
	var v0: Vector2 = Vector2(20.0, -140.0)
	var v1: Vector2 = Vector2(0.0, 0.0)
	var v2: Vector2 = Vector2(0.0, -45.0)
	var v3: Vector2 = Vector2(0.0, -50.0)
	return _mc040_piecewise(f, 9.0, v0, 20.0, v0, 24.0, v1, 36.0, v1, 39.0, v2, 40.0, v3, 48.0, v3)


func _mc040_piecewise(f: float, f0: float, v0: Vector2, f1: float, v1: Vector2, f2: float, v2: Vector2, f3: float, v3: Vector2, f4: float, v4: Vector2, f5: float, v5: Vector2, f6: float, v6: Vector2) -> Vector2:
	if f <= f1:
		return _interp_vec(f, f0, v0, f1, v1)
	if f <= f2:
		return _interp_vec(f, f1, v1, f2, v2)
	if f <= f3:
		return _interp_vec(f, f2, v2, f3, v3)
	if f <= f4:
		return _interp_vec(f, f3, v3, f4, v4)
	if f <= f5:
		return _interp_vec(f, f4, v4, f5, v5)
	return _interp_vec(f, f5, v5, f6, v6)


func _interp_vec(f: float, f0: float, v0: Vector2, f1: float, v1: Vector2) -> Vector2:
	if f1 <= f0:
		return v1
	var t: float = clampf((f - f0) / (f1 - f0), 0.0, 1.0)
	t = _flash_ease_out(t)
	return v0.lerp(v1, t)


func _flash_ease_out(t: float) -> float:
	# XFL acceleration="-100" 的视觉效果接近先快后慢。这里用二次 ease-out 近似，保持原版关键帧位置。
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)


func _apply_hp_side_positions(is_p1: bool, delta: Vector2) -> void:
	var base: Vector2 = P1_HP_POS if is_p1 else P2_HP_POS
	var flip: bool = not is_p1
	var frame: TextureRect = p1_hp_frame if is_p1 else p2_hp_frame
	var red: TextureRect = p1_hp_red_bar if is_p1 else p2_hp_red_bar
	var front: TextureRect = p1_hp_front_bar if is_p1 else p2_hp_front_bar
	var empty_mask: ColorRect = p1_hp_empty_mask if is_p1 else p2_hp_empty_mask
	var glass: TextureRect = p1_hp_glass if is_p1 else p2_hp_glass
	_set_pos_if_valid(frame, base + delta)
	_set_pos_if_valid(red, base + HP_BAR_OFFSET + delta)
	_set_pos_if_valid(front, base + HP_FRONT_OFFSET + delta)
	if empty_mask != null:
		empty_mask.position.y = base.y + HP_BAR_OFFSET.y + delta.y
	_set_pos_if_valid(glass, base + HP_GLASS_OFFSET + delta)
	if frame != null:
		frame.flip_h = flip
	if red != null:
		red.flip_h = flip
	if front != null:
		front.flip_h = flip
	if glass != null:
		glass.flip_h = flip


func _apply_face_positions(is_p1: bool, delta: Vector2) -> void:
	var frame: TextureRect = p1_face_frame if is_p1 else p2_face_frame
	var face: TextureRect = p1_face if is_p1 else p2_face
	# 原版 mc_040 在 fadin_fin 帧把 face1/face2 放到 hpbar_mc 两侧；
	# mc_035(hpbar_facegroup) 内部 face(mc_034) 的 faceBar 是 102x64。
	# P2 的原版 face2 外层 Matrix a=-1，所以这里用负 scale 镜像整个 P1 裁切结果。
	if is_p1:
		_set_pos_if_valid(frame, P1_FACE_POS + delta)
		_set_pos_if_valid(face, P1_FACE_BAR_POS + delta)
		if frame != null:
			frame.scale = Vector2.ONE
		if face != null:
			face.scale = Vector2.ONE
	else:
		_set_pos_if_valid(frame, P2_FACE_POS + Vector2(FACE_FRAME_SIZE.x, 0.0) + delta)
		_set_pos_if_valid(face, P2_FACE_BAR_POS + Vector2(FACE_BAR_SIZE.x, 0.0) + delta)
		if frame != null:
			frame.scale = Vector2(-1.0, 1.0)
		if face != null:
			face.scale = Vector2(-1.0, 1.0)


func _apply_energy_positions(is_p1: bool, delta: Vector2) -> void:
	var base: Vector2 = P1_ENERGY_POS if is_p1 else P2_ENERGY_POS
	var frame: TextureRect = p1_energy_frame if is_p1 else p2_energy_frame
	var bar: TextureRect = p1_energy_bar if is_p1 else p2_energy_bar
	_set_pos_if_valid(frame, base + delta)
	_set_pos_if_valid(bar, base + ENERGY_FILL_OFFSET + delta)


func _qi_fill_base_position(is_p1: bool, base: Vector2, delta: Vector2 = Vector2.ZERO) -> Vector2:
	return base + (QI_FILL_OFFSET if is_p1 else QI_FILL_OFFSET_P2) + delta


func _qi_num_position(is_p1: bool, base: Vector2) -> Vector2:
	return base + (QI_NUM_OFFSET_P1 if is_p1 else QI_NUM_OFFSET_P2)


func _qi_num_mask_position(is_p1: bool, base: Vector2) -> Vector2:
	return base + (QI_NUM_MASK_OFFSET_P1 if is_p1 else QI_NUM_MASK_OFFSET_P2)


func _apply_qi_side_positions(is_p1: bool, delta: Vector2) -> void:
	var base: Vector2 = P1_QI_POS if is_p1 else P2_QI_POS
	var frame: TextureRect = p1_qi_frame if is_p1 else p2_qi_frame
	var num: TextureRect = p1_qi_num if is_p1 else p2_qi_num
	var num_mask: ColorRect = p1_qi_num_mask if is_p1 else p2_qi_num_mask
	var track_mask: ColorRect = p1_qi_track_mask if is_p1 else p2_qi_track_mask
	var _bars: Array[TextureRect] = p1_qi_bars if is_p1 else p2_qi_bars
	_set_pos_if_valid(frame, base + delta)
	_set_pos_if_valid(track_mask, _qi_fill_base_position(is_p1, base) + Vector2(-1.0, -0.5) + delta)
	_set_pos_if_valid(num_mask, _qi_num_mask_position(is_p1, base) + delta)
	_set_pos_if_valid(num, _qi_num_position(is_p1, base) + delta)
	# 不在这里重设 bar.position。原版 QiBar.render() 在 qbar_mc Matrix 确定后才执行 InsBar.setProcess，
	# P2 依靠父级 scaleX=-1 得到从右往左增长。Godot 版的连续宽度/位置统一由 _apply_qi_process() 处理，
	# 避免时间轴位置函数把 P2 已计算好的 right-anchor 位置覆盖回左侧。
	_apply_fzqi_positions(is_p1, delta)


func _apply_fzqi_positions(is_p1: bool, delta: Vector2) -> void:
	var base: Vector2 = P1_QI_POS if is_p1 else P2_QI_POS
	var frame: TextureRect = p1_fzqi_frame if is_p1 else p2_fzqi_frame
	var bar: TextureRect = p1_fzqi_bar if is_p1 else p2_fzqi_bar
	var ready_tex: TextureRect = p1_fzqi_ready if is_p1 else p2_fzqi_ready
	var sp: TextureRect = p1_sp_prompt if is_p1 else p2_sp_prompt
	var face_back: TextureRect = p1_qi_face_back if is_p1 else p2_qi_face_back
	var face_image: TextureRect = p1_qi_face_image if is_p1 else p2_qi_face_image
	var face_gradient: TextureRect = p1_qi_face_gradient if is_p1 else p2_qi_face_gradient
	var face_front: TextureRect = p1_qi_face_front if is_p1 else p2_qi_face_front

	var fz_extra: Vector2 = _qibar_fz_extra_delta(qibar_timeline_frame)
	var fz_scale: float = _qibar_fz_scale(qibar_timeline_frame)
	var ready_extra: Vector2 = _qibar_ready_extra_delta(qibar_timeline_frame)

	_set_tex_transform(face_back, base + FZ_QI_FACE_OFFSET + delta + fz_extra, fz_scale)
	_set_tex_transform(face_image, base + FZ_QI_FACE_IMAGE_OFFSET + delta + fz_extra, fz_scale)
	# 主气槽 facemc 按 mc_026.xml 的 facemc Matrix 运动，不跟 fzqibar 的 Matrix 走。
	_set_tex_transform(face_gradient, _qi_main_face_gradient_position(is_p1, base, delta), _qibar_face_scale(qibar_timeline_frame))
	_set_tex_transform(face_front, _qi_main_face_position(is_p1, base, delta), _qibar_face_scale(qibar_timeline_frame))
	_set_tex_transform(frame, base + FZ_QI_FRAME_OFFSET + delta + fz_extra, fz_scale)
	if bar != null:
		var bar_pos: Vector2 = base + FZ_QI_FILL_OFFSET + delta + fz_extra
		if not is_p1:
			bar_pos.x += FZ_QI_FILL_SIZE.x - bar.size.x
		_set_tex_transform(bar, bar_pos, fz_scale)
	_set_tex_transform(sp, base + FZ_QI_SP_OFFSET + delta + fz_extra, fz_scale)
	_set_tex_transform(ready_tex, base + FZ_QI_READY_OFFSET + delta + ready_extra, 1.0)


func _apply_time_positions(delta: Vector2) -> void:
	_set_pos_if_valid(time_join_slash_left, TIME_JOIN_SLASH_LEFT_POS + delta)
	_set_pos_if_valid(time_join_slash_right, TIME_JOIN_SLASH_RIGHT_POS + delta)
	var frame_node: Node = get_node_or_null("OriginalTimeFrame")
	if frame_node is TextureRect:
		(frame_node as TextureRect).position = TIME_FRAME_POS + delta
	_set_pos_if_valid(infinity_time_rect, TIME_INFINITY_POS + delta)
	if time_number_mc is Control:
		(time_number_mc as Control).position = TIME_NUMBER_POS + delta


func _apply_score_positions(delta: Vector2) -> void:
	var score_node: Node = get_node_or_null("OriginalScoreText")
	if score_node is TextureRect:
		(score_node as TextureRect).position = Vector2(360.0, 54.0) + delta
	if score_number_mc is Control:
		(score_number_mc as Control).position = Vector2(346.0, 68.0) + delta


func _set_pos_if_valid(node: Control, pos: Vector2) -> void:
	if node != null:
		node.position = pos


func _set_tex_transform(node: TextureRect, pos: Vector2, scale_value: float) -> void:
	if node == null:
		return
	node.position = pos
	node.scale = Vector2(scale_value, scale_value)



func _qi_main_face_gradient_position(is_p1: bool, base: Vector2, main_delta: Vector2) -> Vector2:
	# gradient back 比 front 多一圈外沿；原版不是从 qbar_mc 截图，而是 qbar_facemc 子层单独叠放。
	return _qi_main_face_position(is_p1, base, main_delta) - QI_FACE_FRONT_OFFSET_IN_GRADIENT


func _qi_main_face_position(is_p1: bool, base: Vector2, main_delta: Vector2) -> Vector2:
	var face_extra: Vector2 = _qibar_face_extra_delta(qibar_timeline_frame)
	if is_p1:
		return base + QI_MAIN_FACE_OFFSET + main_delta + face_extra
	# P2 的 qbar 资源在 Godot 侧水平翻转：以 qbar_frame 宽度为镜像基准还原 facemc 在右侧的位置。
	var mirror_offset_x: float = QI_FRAME_SIZE.x - QI_MAIN_FACE_OFFSET.x - FZ_QI_FACE_SIZE.x
	return base + Vector2(mirror_offset_x, QI_MAIN_FACE_OFFSET.y) + main_delta + Vector2(-face_extra.x, face_extra.y)


func _qibar_face_extra_delta(f: float) -> Vector2:
	# mc_026.xml / facemc Matrix：frame0=(-150.55,105), frame10=(13.7,17.7), frame14=(-10.55,5), frame36=(13.8,21.75), frame37=(-74.7,97.3).
	var pos: Vector2 = _piecewise_vec2(
		f,
		0.0, Vector2(-150.55, 105.0),
		10.0, Vector2(13.7, 17.7),
		14.0, QIBAR_XML_FACE_FINAL_POS,
		33.0, QIBAR_XML_FACE_FINAL_POS,
		36.0, Vector2(13.8, 21.75),
		37.0, Vector2(-74.7, 97.3),
		58.0, Vector2(-74.7, 97.3)
	)
	return pos - QIBAR_XML_FACE_FINAL_POS


func _qibar_face_scale(f: float) -> float:
	return _piecewise_float(
		f,
		0.0, 1.0,
		10.0, 0.24798583984375,
		14.0, 1.0,
		33.0, 1.0,
		36.0, 0.177993774414063,
		37.0, 0.177993774414063,
		58.0, 0.177993774414063
	)


func _qibar_main_extra_delta(f: float) -> Vector2:
	# mc_026.xml / 气槽 layer / barmc Matrix：
	# frame0=(-200.55,89.45), frame11=(-254.1,24.2), frame14=(35.95,24.45), frame32=(35.95,24.45), frame36=(-254.05,24.45).
	var pos: Vector2 = _piecewise_vec2(
		f,
		0.0, Vector2(-200.55, 89.45),
		11.0, Vector2(-254.1, 24.2),
		14.0, QIBAR_XML_MAIN_FINAL_POS,
		32.0, QIBAR_XML_MAIN_FINAL_POS,
		36.0, Vector2(-254.05, 24.45),
		37.0, Vector2(-254.05, 24.45),
		58.0, Vector2(-254.05, 24.45)
	)
	return pos - QIBAR_XML_MAIN_FINAL_POS

func _qibar_fz_extra_delta(f: float) -> Vector2:
	# mc_026.xml / 辅助底图 layer / fzqibar Matrix：
	# frame0=(-155,101.05), frame9=(13,16), frame13=(-15,1.5), frame36=(13,21.05), frame37=(-75.5,96.6).
	var pos: Vector2 = _piecewise_vec2(
		f,
		0.0, Vector2(-155.0, 101.05),
		9.0, Vector2(13.0, 16.0),
		13.0, QIBAR_XML_FZ_FINAL_POS,
		33.0, QIBAR_XML_FZ_FINAL_POS,
		36.0, Vector2(13.0, 21.05),
		37.0, Vector2(-75.5, 96.6),
		58.0, Vector2(-75.5, 96.6)
	)
	return pos - QIBAR_XML_FZ_FINAL_POS


func _qibar_fz_scale(f: float) -> float:
	return _piecewise_float(
		f,
		0.0, 1.0,
		9.0, 0.24798583984375,
		13.0, QIBAR_XML_FZ_FINAL_SCALE,
		33.0, QIBAR_XML_FZ_FINAL_SCALE,
		36.0, 0.177993774414063,
		37.0, 0.177993774414063,
		58.0, 0.177993774414063
	)


func _qibar_ready_extra_delta(f: float) -> Vector2:
	# mc_026.xml / ready layer / readymc Matrix：frame0=(-121.9,97.1), frame14=(18.1,-2.9), frame32=(-109.45,59.15).
	var pos: Vector2 = _piecewise_vec2(
		f,
		0.0, Vector2(-121.9, 97.1),
		14.0, QIBAR_XML_READY_FINAL_POS,
		32.0, QIBAR_XML_READY_FINAL_POS,
		37.0, Vector2(-109.45, 59.15),
		58.0, Vector2(-109.45, 59.15),
		59.0, Vector2(-109.45, 59.15),
		60.0, Vector2(-109.45, 59.15)
	)
	return pos - QIBAR_XML_READY_FINAL_POS


func _piecewise_vec2(
	f: float,
	f0: float, v0: Vector2,
	f1: float, v1: Vector2,
	f2: float, v2: Vector2,
	f3: float, v3: Vector2,
	f4: float, v4: Vector2,
	f5: float, v5: Vector2,
	f6: float, v6: Vector2
) -> Vector2:
	if f <= f0:
		return v0
	if f <= f1:
		return v0.lerp(v1, _segment_t(f, f0, f1))
	if f <= f2:
		return v1.lerp(v2, _segment_t(f, f1, f2))
	if f <= f3:
		return v2.lerp(v3, _segment_t(f, f2, f3))
	if f <= f4:
		return v3.lerp(v4, _segment_t(f, f3, f4))
	if f <= f5:
		return v4.lerp(v5, _segment_t(f, f4, f5))
	if f <= f6:
		return v5.lerp(v6, _segment_t(f, f5, f6))
	return v6


func _piecewise_float(
	f: float,
	f0: float, v0: float,
	f1: float, v1: float,
	f2: float, v2: float,
	f3: float, v3: float,
	f4: float, v4: float,
	f5: float, v5: float,
	f6: float, v6: float
) -> float:
	if f <= f0:
		return v0
	if f <= f1:
		return lerpf(v0, v1, _segment_t(f, f0, f1))
	if f <= f2:
		return lerpf(v1, v2, _segment_t(f, f1, f2))
	if f <= f3:
		return lerpf(v2, v3, _segment_t(f, f2, f3))
	if f <= f4:
		return lerpf(v3, v4, _segment_t(f, f3, f4))
	if f <= f5:
		return lerpf(v4, v5, _segment_t(f, f4, f5))
	if f <= f6:
		return lerpf(v5, v6, _segment_t(f, f5, f6))
	return v6


func _segment_t(f: float, a: float, b: float) -> float:
	if absf(b - a) < 0.001:
		return 1.0
	return _flash_ease_out(clampf((f - a) / (b - a), 0.0, 1.0))


func _update_hp_animation(delta: float) -> void:
	p1_hp_front = p1_hp_target
	p2_hp_front = p2_hp_target
	if p1_red_delay > 0.0:
		p1_red_delay -= delta
	else:
		p1_hp_red = _move_rate(p1_hp_red, p1_hp_target, delta)
	if p2_red_delay > 0.0:
		p2_red_delay -= delta
	else:
		p2_hp_red = _move_rate(p2_hp_red, p2_hp_target, delta)


func _move_rate(cur: float, target: float, delta: float) -> float:
	# 原版 FighterHpBar.as：redbar.scaleX += diffRed * addRateRed；
	# 掉血时 addRateRed=0.1，回血/恢复时 addRateRed=0.02。这里按 24FPS 换成 delta 版本，避免帧率变化导致红条速度不一致。
	var per_frame_add: float = 0.1 if target < cur else 0.02
	var frame_count: float = maxf(0.0, delta * ORIGINAL_UI_FPS)
	var factor: float = 1.0 - pow(1.0 - per_frame_add, frame_count)
	var next_value: float = cur + (target - cur) * clampf(factor, 0.0, 1.0)
	if absf(next_value - target) < 0.005:
		return target
	return next_value


func _apply_hp_sizes() -> void:
	# 原版 FighterHpBar.as：_bar.scaleX = hp / hpMax；redbar.scaleX 延迟追随。
	# picture_076 底框本身已经是空槽；redbar 在下，绿色 bar 在上，picture_008 高光最后覆盖。
	var p1_delta: Vector2 = _mc040_delta_p1_hp(hpbar_timeline_frame)
	var p2_delta: Vector2 = _mc040_delta_p2_hp(hpbar_timeline_frame)
	var p1_red_base: Vector2 = P1_HP_POS + HP_BAR_OFFSET + p1_delta
	var p2_red_base: Vector2 = P2_HP_POS + HP_BAR_OFFSET + p2_delta
	var p1_front_base: Vector2 = P1_HP_POS + HP_FRONT_OFFSET + p1_delta
	var p2_front_base: Vector2 = P2_HP_POS + HP_FRONT_OFFSET + p2_delta
	# 原版 mc_040：bar1 不镜像，bar2 外层 a=-1 镜像；mc_033 内部 bar/redbar 的注册点在右端。
	# 所以 1P 从头像侧向中央缩短，2P 从头像侧向中央缩短；绿色 bar 始终在 redbar 上层。
	_set_tex_width(p1_hp_red_bar, p1_red_base, HP_BAR_SIZE.x, p1_hp_red, true)
	_set_tex_width(p2_hp_red_bar, p2_red_base, HP_BAR_SIZE.x, p2_hp_red, false)
	_set_tex_width(p1_hp_front_bar, p1_front_base, HP_FRONT_SIZE.x, p1_hp_front, true)
	_set_tex_width(p2_hp_front_bar, p2_front_base, HP_FRONT_SIZE.x, p2_hp_front, false)


func _apply_hp_empty_mask(mask: ColorRect, base_pos: Vector2, rate: float, from_right: bool) -> void:
	if mask == null:
		return
	var fill_rate: float = clampf(rate, 0.0, 1.0)
	var empty_width: float = HP_FRONT_SIZE.x * (1.0 - fill_rate)
	mask.visible = empty_width > 0.5 and hud_visible_rate > 0.01
	mask.color = HP_EMPTY_MASK_COLOR
	mask.size = Vector2(empty_width, HP_FRONT_SIZE.y)
	mask.position.y = base_pos.y
	if from_right:
		mask.position.x = base_pos.x
	else:
		mask.position.x = base_pos.x + HP_FRONT_SIZE.x - empty_width


func _apply_energy_sizes() -> void:
	var p1_delta: Vector2 = _mc040_delta_p1_energy(hpbar_timeline_frame)
	var p2_delta: Vector2 = _mc040_delta_p2_energy(hpbar_timeline_frame)
	_set_tex_width(p1_energy_bar, P1_ENERGY_POS + ENERGY_FILL_OFFSET + p1_delta, ENERGY_FILL_SIZE.x, p1_energy_rate, false)
	_set_tex_width(p2_energy_bar, P2_ENERGY_POS + ENERGY_FILL_OFFSET + p2_delta, ENERGY_FILL_SIZE.x, p2_energy_rate, true)
	_apply_energy_bar_texture(p1_energy_bar, p1_energy_rate, p1_energy_overload)
	_apply_energy_bar_texture(p2_energy_bar, p2_energy_rate, p2_energy_overload)


func _qi_bar_full_width(index: int) -> float:
	if index >= 0 and index < QI_FILL_WIDTHS.size():
		return float(QI_FILL_WIDTHS[index])
	return QI_FILL_SIZE.x


func _apply_qi_process(bars: Array[TextureRect], value: float, is_p1: bool) -> void:
	if _using_qbar_movie_timeline():
		_hide_manual_main_qbar_nodes()
		for bar: TextureRect in bars:
			if bar != null:
				bar.visible = false
		_apply_qbar_movie_side(is_p1, _current_qi_alpha())
		return
	if bars.size() < 4:
		return
	for i: int in range(4):
		bars[i].visible = false

	var base: Vector2 = P1_QI_POS if is_p1 else P2_QI_POS
	var alpha: float = _current_qi_alpha()
	var frame: TextureRect = p1_qi_frame if is_p1 else p2_qi_frame
	var track_mask: ColorRect = p1_qi_track_mask if is_p1 else p2_qi_track_mask
	var num_rect: TextureRect = p1_qi_num if is_p1 else p2_qi_num
	var num_mask: ColorRect = p1_qi_num_mask if is_p1 else p2_qi_num_mask
	if frame != null:
		frame.visible = alpha > 0.01
		frame.modulate.a = alpha
	if track_mask != null:
		track_mask.visible = alpha > 0.01
		track_mask.modulate.a = alpha
	if num_mask != null:
		# qibar_frame.png 是 FFDec 的静态帧，里面烘进了 txtmc 的 0。
		# 原版是 txtmc.gotoAndStop(int(qi/100)+1)，所以先遮住静态 0，再只绘制一个动态数字。
		num_mask.visible = alpha > 0.01
		num_mask.modulate.a = alpha
	if num_rect != null:
		num_rect.visible = alpha > 0.01
		num_rect.modulate.a = alpha

	var v: float = clampf(value, 0.0, 3.0)
	_update_qi_number(num_rect, _qibar_level_from_process(v))
	var base_pos: Vector2 = _qi_fill_base_position(is_p1, base, Vector2.ZERO)
	# 原版 P2 的 fzqi2/qbar_mc 外层 Matrix 为 a=-1。内部 barmc 仍按本地左侧 scaleX，
	# 镜像后视觉上就是从右往左增长；Godot 这里用 from_right 重建这个视觉结果。
	var fill_from_right: bool = not is_p1
	# 原版 InsBar.setProcess 的颜色/层级顺序：
	# bar1(picture_053, 蓝青) 0..1；bar2(picture_054, 黄绿) 1..2；bar3(picture_055, 橙) 2..3；bar4(picture_059, 红) v>=3。
	# bar2/bar3/bar4 在更高图层覆盖前一段，所以不是换整张 qbar_mc 帧，而是逐层 visible + scaleX。
	var rates: Array[float] = [
		clampf(v, 0.0, 1.0),
		clampf(v - 1.0, 0.0, 1.0),
		clampf(v - 2.0, 0.0, 1.0),
		1.0 if v >= 3.0 else 0.0
	]
	for i: int in range(4):
		var rate: float = rates[i]
		if rate <= 0.001:
			bars[i].visible = false
			continue
		bars[i].visible = alpha > 0.01
		bars[i].modulate.a = alpha
		_set_tex_width(bars[i], base_pos, _qi_bar_full_width(i), rate, fill_from_right)


func _current_qi_alpha() -> float:
	if qibar_timeline_playing and qibar_timeline_mode == "fadin":
		return clampf((qibar_timeline_frame - QIBAR_FADIN_START_FRAME) / maxf(1.0, QIBAR_FADIN_FIN_FRAME - QIBAR_FADIN_START_FRAME), 0.0, 1.0)
	if qibar_timeline_playing and qibar_timeline_mode == "fadout":
		return 1.0
	return qi_visible_rate


func _update_player_pos_ui(p1_node: Variant, p2_node: Variant) -> void:
	# 原版 FightUI.renderPlayerPosUI：zoom > 1.8 时隐藏 P1/P2 指示；
	# 两人距离拉远时 GameCamera 自动 zoom 降低，P1/P2 才显示。
	if original_camera_zoom > 1.8:
		_set_player_pos_visible(false, false)
		return
	_update_single_player_pos(p1_node, p1_player_pos_icon, PLAYER_POS_P1_OFFSET)
	_update_single_player_pos(p2_node, p2_player_pos_icon, PLAYER_POS_P2_OFFSET)


func _set_player_pos_visible(p1_visible: bool, p2_visible: bool) -> void:
	if p1_player_pos_icon != null:
		p1_player_pos_icon.visible = p1_visible
	if p2_player_pos_icon != null:
		p2_player_pos_icon.visible = p2_visible


func _update_single_player_pos(node: Variant, icon: TextureRect, bitmap_offset: Vector2) -> void:
	if icon == null:
		return
	if node == null or not is_instance_valid(node):
		icon.visible = false
		return
	var original_sprite_pos: Vector2 = Vector2.ZERO
	if node is Node2D:
		# 原版 getGameSpriteGlobalPosition(sp, 0, -50) 中的 sp.y 是角色脚底/地面点。
		# 当前 Godot 的 Node2D position 是 normalized Sprite2D 中心点，所以先还原到原版脚底点，
		# 再应用原版 (0,-50) 偏移。否则 P1/P2 会被算到屏幕顶部。
		original_sprite_pos = (node as Node2D).position + Vector2(0.0, PLAYER_POS_GODOT_CENTER_TO_ORIGINAL_FOOT_Y + PLAYER_POS_ORIGINAL_Y_OFFSET)
	else:
		icon.visible = false
		return

	# 对应 GameStage.getGameSpriteGlobalPosition(sp, 0, -50)：先应用 camera scrollRect，再乘 zoom 得到 HUD 屏幕坐标。
	var pos: Vector2 = (original_sprite_pos - original_camera_rect.position) * original_camera_zoom
	# 原版 FightUI.getPlayerPos：x 限制在 20..GAME_SIZE.x-20，y 最低 60。
	pos.x = clampf(pos.x, 20.0, 780.0)
	pos.y = maxf(pos.y, 60.0)
	icon.position = pos + bitmap_offset
	icon.visible = true
	icon.modulate.a = 1.0


func _apply_fzqi_process(is_p1: bool) -> void:
	var value: float = p1_fzqi_process if is_p1 else p2_fzqi_process
	var can_break: bool = p1_can_hurt_break if is_p1 else p2_can_hurt_break
	var base: Vector2 = P1_QI_POS if is_p1 else P2_QI_POS
	var from_right: bool = not is_p1
	var frame: TextureRect = p1_fzqi_frame if is_p1 else p2_fzqi_frame
	var bar: TextureRect = p1_fzqi_bar if is_p1 else p2_fzqi_bar
	var ready_tex: TextureRect = p1_fzqi_ready if is_p1 else p2_fzqi_ready
	var sp: TextureRect = p1_sp_prompt if is_p1 else p2_sp_prompt
	var face_back: TextureRect = p1_qi_face_back if is_p1 else p2_qi_face_back
	var face_image: TextureRect = p1_qi_face_image if is_p1 else p2_qi_face_image
	var face_gradient: TextureRect = p1_qi_face_gradient if is_p1 else p2_qi_face_gradient
	var face_front: TextureRect = p1_qi_face_front if is_p1 else p2_qi_face_front
	var rate: float = clampf(value, 0.0, 1.0)
	var alpha: float = _current_qi_alpha()
	var show_fz: bool = rate > 0.001 and alpha > 0.01
	if face_back != null:
		face_back.visible = show_fz
		face_back.modulate.a = alpha
	if face_image != null:
		face_image.visible = show_fz
		face_image.modulate.a = alpha
	if face_gradient != null:
		face_gradient.visible = (alpha > 0.01) and not _using_qbar_movie_timeline()
		face_gradient.modulate.a = alpha
	if face_front != null:
		face_front.visible = (alpha > 0.01) and not _using_qbar_movie_timeline()
		face_front.modulate.a = alpha
	if frame != null:
		frame.visible = show_fz
		frame.modulate.a = alpha
	if bar != null:
		bar.visible = show_fz
		bar.modulate.a = alpha
		_set_tex_width(bar, base + FZ_QI_FILL_OFFSET, FZ_QI_FILL_SIZE.x, rate, from_right)
	if ready_tex != null:
		ready_tex.visible = rate >= 1.0 and alpha > 0.01
		if ready_tex.visible:
			ready_tex.modulate.a = alpha * (0.45 + 0.55 * (0.5 + 0.5 * sin(flash_time * 9.0)))
	if sp != null:
		sp.visible = can_break and alpha > 0.01
		if sp.visible:
			sp.modulate.a = alpha * (0.55 + 0.45 * (0.5 + 0.5 * sin(flash_time * 12.0)))


func _update_energy_flash() -> void:
	var base_alpha: float = hud_visible_rate
	if hpbar_timeline_playing and hpbar_timeline_mode == "fadin":
		base_alpha = clampf((hpbar_timeline_frame - HPBAR_FADIN_START_FRAME) / maxf(1.0, HPBAR_FADIN_FIN_FRAME - HPBAR_FADIN_START_FRAME), 0.0, 1.0)
	elif hpbar_timeline_playing and hpbar_timeline_mode == "fadout":
		base_alpha = 1.0
	_apply_energy_visual(p1_energy_bar, base_alpha)
	_apply_energy_visual(p2_energy_bar, base_alpha)
	_apply_energy_bar_texture(p1_energy_bar, p1_energy_rate, p1_energy_overload)
	_apply_energy_bar_texture(p2_energy_bar, p2_energy_rate, p2_energy_overload)


func _apply_energy_bar_texture(bar: TextureRect, rate: float, overload: bool) -> void:
	if bar == null:
		return
	if overload:
		bar.texture = tex_energy_fill_overload
		return
	# 原版 EnergyBar.InsBar.flash(): 每 3 个 render 帧在 bar frame1 / frame2 间切换。
	if rate < 0.3:
		var frame_id: int = int(floor(flash_time * ORIGINAL_UI_FPS / ENERGY_FLASH_FRAME_STEP)) % 2
		bar.texture = tex_energy_fill_frame2 if frame_id == 0 else tex_energy_fill_frame1
		return
	bar.texture = tex_energy_fill_frame1


func _apply_energy_visual(bar: TextureRect, base_alpha: float) -> void:
	if bar == null:
		return
	bar.modulate = Color(1.0, 1.0, 1.0, base_alpha)

func _update_red_delay(node: Variant, is_p1: bool) -> void:
	var current: float = p1_hp_target if is_p1 else p2_hp_target
	var last: float = p1_last_hp_target if is_p1 else p2_last_hp_target
	if current < last - 0.001:
		var action_name: String = _node_string(node, "current_action", "")
		var delay: float = RED_DELAY_FLY if action_name.begins_with("knock") or action_name == "hurt_fly" else RED_DELAY_DEFAULT
		if is_p1:
			p1_red_delay = delay
		else:
			p2_red_delay = delay
	if is_p1:
		p1_last_hp_target = current
	else:
		p2_last_hp_target = current


func _set_bar_width(bar: ColorRect, base_pos: Vector2, full_width: float, rate: float, from_right: bool) -> void:
	if bar == null:
		return
	var width_value: float = full_width * clampf(rate, 0.0, 1.0)
	bar.size.x = maxf(0.0, width_value)
	bar.position.x = base_pos.x + (full_width - width_value if from_right else 0.0)
	bar.position.y = base_pos.y


func _set_tex_width(bar: TextureRect, base_pos: Vector2, full_width: float, rate: float, from_right: bool, keep_current_pos: bool = false) -> void:
	if bar == null:
		return
	var width_value: float = full_width * clampf(rate, 0.0, 1.0)
	var original_pos: Vector2 = bar.position
	bar.size.x = maxf(0.0, width_value)
	if keep_current_pos:
		if from_right:
			bar.position.x = original_pos.x + (full_width - width_value)
		return
	bar.position.x = base_pos.x + (full_width - width_value if from_right else 0.0)
	bar.position.y = base_pos.y


func _update_hp_number(num_mc: Control, hp_value: int) -> void:
	if num_mc == null:
		return
	if num_mc.has_method("set_number"):
		num_mc.call("set_number", maxi(0, hp_value))


func _apply_hp_number_positions(is_p1: bool, delta: Vector2) -> void:
	var node: Control = p1_hp_number_mc if is_p1 else p2_hp_number_mc
	var base: Vector2 = P1_HP_NUMBER_POS if is_p1 else P2_HP_NUMBER_POS
	_set_pos_if_valid(node, base + delta)


func _original_spiritual_position(is_p1: bool) -> Vector2:
	# FightBar.as 创建 EnergyBar(_ui.energy1 / _ui.energy2)。
	# EnergyBar.as 的 setDirect(-1) 只把 txtmc 再次翻转，保证 2P 文字不倒置。
	# 注意：txtmc 是 mc_029 容器原点，真正可见的 SPIRITUAL 位图 picture_092 还带有
	# mc_029/mc_027/mc_015 内部矩阵偏移，Godot 必须把这个偏移一起算进去。
	if is_p1:
		return HPBAR_MC_ORIGIN + HPBAR_MC_ENERGY1_POS + ENERGY_BAR_TXTMC_POS + ENERGY_BAR_TXTMC_BITMAP_OFFSET

	# P2 原版：energy2 外层 a=-1 镜像，txtmc 再 scaleX=-1 修正文字方向。
	# 因为 Godot 这里直接绘制未翻转的 picture_092，所以需要取镜像后可见位图的左上角：
	# x = hpbar.x + energy2.tx - (txtmc.x + bitmap_offset.x + bitmap_width)
	var p2_x: float = HPBAR_MC_ORIGIN.x + HPBAR_MC_ENERGY2_POS.x - (ENERGY_BAR_TXTMC_POS.x + ENERGY_BAR_TXTMC_BITMAP_OFFSET.x + ENERGY_BAR_TXTMC_SIZE.x)
	var p2_y: float = HPBAR_MC_ORIGIN.y + HPBAR_MC_ENERGY2_POS.y + ENERGY_BAR_TXTMC_POS.y + ENERGY_BAR_TXTMC_BITMAP_OFFSET.y
	return Vector2(p2_x, p2_y)


func _apply_spiritual_positions(is_p1: bool, delta: Vector2) -> void:
	var node: TextureRect = p1_spiritual_text if is_p1 else p2_spiritual_text
	_set_pos_if_valid(node, _original_spiritual_position(is_p1) + delta)


func _qibar_level_from_process(process: float) -> int:
	# 原版 QiBar.as / InsBar.setProcess:
	# txtmc.gotoAndStop(int(qi / 100) + 1)
	# 这里 process 已经是 qi / 100，所以 floor 后得到 0/1/2/3。
	return clampi(int(floor(clampf(process, 0.0, 3.0))), 0, 3)


func _update_qi_number(num_rect: TextureRect, num: int) -> void:
	if num_rect == null or tex_qi_nums.size() < 4:
		return

	var idx: int = clampi(num, 0, 3)
	num_rect.texture = tex_qi_nums[idx]
	num_rect.size = QI_NUM_SIZE
	num_rect.visible = true
	num_rect.flip_h = false


func _build_hits_group(is_p1: bool) -> void:
	# 对应原版 hits_mc。具体 fadin/update/fadout 动画在 OriginalHitsDisplay.gd 中按 mc_018.xml 关键帧执行。
	var group: Control = OriginalHitsDisplay.new()
	group.name = "hits1" if is_p1 else "hits2"
	group.position = Vector2(62.15, 121.95) if is_p1 else Vector2(662.15, 121.95)
	group.size = Vector2(230.0, 105.0)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.call("setup", is_p1)
	add_child(group)
	if is_p1:
		p1_combo_group = group
		p1_combo_number_mc = group
	else:
		p2_combo_group = group
		p2_combo_number_mc = group


func _update_combo_number(group: Control, _num_mc: Control, combo: int, _is_p1: bool) -> void:
	if group == null:
		return
	if combo >= 1:
		if group.has_method("show_hits"):
			group.call("show_hits", combo)
	else:
		if group.has_method("hide_hits"):
			group.call("hide_hits")


func _tex_rect(node_name: String, tex: Texture2D, pos: Vector2, rect_size: Vector2, flip_h: bool) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = node_name
	rect.position = pos
	rect.size = rect_size
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.flip_h = flip_h
	return rect


func _face_rect(node_name: String, character: String, pos: Vector2, rect_size: Vector2, flip_h: bool) -> TextureRect:
	# 通用头像贴图：用于 qbar_facemc / 辅助头像等小头像，不套 hpbar_facemc 的 102x64 mask。
	var rect: TextureRect = _tex_rect(node_name, _load_face_texture(character), pos, rect_size, flip_h)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect


func _face_bar_rect(node_name: String, character: String, pos: Vector2, rect_size: Vector2, _flip_h: bool) -> TextureRect:
	# 战斗顶部 HP 头像专用：对应 FightFaceUI.setData -> AssetManager.getFighterFaceBar。
	# 这里始终使用 P1 的原始 mask。P2 不在 shader 内拆开镜像，
	# 而是在 _build_original_layout() / _apply_face_positions() 中把整个已裁切结果 scale.x=-1，
	# 对齐原版 mc_040.xml face2 的 Matrix a=-1。
	var rect: TextureRect = _tex_rect(node_name, _load_face_bar_texture(character), pos, rect_size, false)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.material = _make_face_bar_mask_material(false)
	return rect


func _make_face_bar_mask_material(mirror_mask: bool = false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 face_size = vec2(102.0, 64.0);
uniform bool mirror_mask = false;

float cross2(vec2 a, vec2 b, vec2 p) {
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
}

void fragment() {
	vec2 sample_uv = UV;
	vec2 p = UV * face_size;
	if (mirror_mask) {
		// P2 的最终结果应与 P1 完全镜像：
		// 1) 先镜像未裁切头像图片的采样；
		// 2) 再把 P1 的 faceBar mask 多边形也水平镜像。
		// 等价于“先镜像原图，再使用镜像后的 P1 裁切形状”。
		sample_uv.x = 1.0 - sample_uv.x;
		p.x = face_size.x - p.x;
	}
	vec4 col = texture(TEXTURE, sample_uv);

	// fight.xfl / mc_034.xml / hpbar_facemc 的 mask 层：
	// edges="!1988 956|1681 1242!1681 1242|282 1242!..."，Flash twip / 20 = 像素。
	// 这个 mask 只裁 102x64 faceBar 图像，不负责画外框；外框由 hpbar_face_frame.png 压在上层。
	// P2 时 sample_uv 与 p 都镜像，保证内容和裁切形状同时成为 P1 的水平镜像。
	float inside = 1.0;
	inside *= step(0.0, cross2(vec2(99.40, 47.80), vec2(84.05, 62.10), p));
	inside *= step(0.0, cross2(vec2(84.05, 62.10), vec2(14.10, 62.10), p));
	inside *= step(0.0, cross2(vec2(14.10, 62.10), vec2(-0.15, 50.65), p));
	inside *= step(0.0, cross2(vec2(-0.15, 50.65), vec2(-0.15, 3.85), p));
	inside *= step(0.0, cross2(vec2(-0.15, 3.85), vec2(70.00, 3.85), p));
	inside *= step(0.0, cross2(vec2(70.00, 3.85), vec2(99.40, 27.75), p));
	inside *= step(0.0, cross2(vec2(99.40, 27.75), vec2(99.40, 47.80), p));

	col.a *= inside;
	COLOR = col;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("face_size", FACE_BAR_SIZE)
	shader_material.set_shader_parameter("mirror_mask", mirror_mask)
	return shader_material


func _make_face_frame_overlay_material(mirror_mask: bool = false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 frame_size = vec2(105.0, 64.0);
uniform bool mirror_mask = false;

float cross2(vec2 a, vec2 b, vec2 p) {
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 p = UV * frame_size;
	if (mirror_mask) {
		p.x = frame_size.x - p.x;
	}

	// hpbar_facemc / mc_034.xml 的 mask 多边形，换算自 twip / 20。
	// 对 picture_090 外框层取反：mask 内部透明，只保留外框/高光在头像上方。
	float inside = 1.0;
	inside *= step(0.0, cross2(vec2(99.40, 47.80), vec2(84.05, 62.10), p));
	inside *= step(0.0, cross2(vec2(84.05, 62.10), vec2(14.10, 62.10), p));
	inside *= step(0.0, cross2(vec2(14.10, 62.10), vec2(-0.15, 50.65), p));
	inside *= step(0.0, cross2(vec2(-0.15, 50.65), vec2(-0.15, 3.85), p));
	inside *= step(0.0, cross2(vec2(-0.15, 3.85), vec2(70.00, 3.85), p));
	inside *= step(0.0, cross2(vec2(70.00, 3.85), vec2(99.40, 27.75), p));
	inside *= step(0.0, cross2(vec2(99.40, 27.75), vec2(99.40, 47.80), p));

	// 防止半透明边缘留下黑底：内部完全打空，边框区域保持原图。
	col.a *= (1.0 - inside);
	COLOR = col;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("frame_size", FACE_FRAME_SIZE)
	shader_material.set_shader_parameter("mirror_mask", mirror_mask)
	return shader_material


func _make_label(text_value: String, pos: Vector2, rect_size: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = pos
	label.size = rect_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_atlas_texture(source: Texture2D, region: Rect2) -> Texture2D:
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

func _load_tex_optional(file_name: String) -> Texture2D:
	var path: String = TEX_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	var tex: Resource = load(path)
	return tex as Texture2D


func _load_tex(file_name: String) -> Texture2D:
	var path: String = TEX_DIR + file_name
	var tex: Resource = load(path)
	if tex == null:
		push_warning("FightHud missing original texture: " + path)
		return null
	return tex as Texture2D


func _load_face_bar_texture(character: String) -> Texture2D:
	var key: String = character.strip_edges().to_lower()
	if key == "":
		key = "aizen"

	var candidates: Array[String] = []

	# 当前项目的 Aizen 使用原版 start_frame=1 队长蓝染。
	# 在 BleachVsNaruto-master/shared/assets/assets/config/fighter.json 中：
	#   id="aizen"    -> face_bar="aizen_captain_m.png"
	#   id="aizen_gz" -> face_bar="aizen_m.png"
	# 之前直接按 OpenBleachVsNaruto 旧 fighter.xml 取 aizen_m，会误用白衣/叛变蓝染头像。
	match key:
		"aizen":
			candidates.append("res://assets/face/aizen_captain_m.png")
			candidates.append("res://assets/face/aizen_m.png")
		"aizen_gz", "aizen_rebel", "aizen_rebellion":
			candidates.append("res://assets/face/aizen_m.png")
		"aizen_captain":
			candidates.append("res://assets/face/aizen_captain_m.png")
		_:
			if key.ends_with("_m"):
				candidates.append("res://assets/face/" + key + ".png")
			else:
				candidates.append("res://assets/face/" + key + "_m.png")
				candidates.append("res://assets/face/" + key + ".png")

	candidates.append("res://assets/face/aizen_captain_m.png")
	candidates.append("res://assets/face/aizen_m.png")
	candidates.append("res://assets/face/aizen.png")

	for path: String in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

	return null


func _load_face_texture(character: String) -> Texture2D:
	var key: String = character.strip_edges().to_lower()
	if key == "":
		key = "aizen"

	var candidates: Array[String] = []

	# 原版战斗 HUD 头像使用 FighterVO.faceBarCls。
	# fighter.xml 中蓝染为：
	# <face cls="aizen" big_cls="aizen_b" bar_cls="aizen_m" win_cls="aizen_w"/>
	# 所以战斗 HUD 应优先加载 *_m.png，而不是普通 face/*.png。
	if key.ends_with("_m"):
		candidates.append("res://assets/face/" + key + ".png")
	else:
		candidates.append("res://assets/face/" + key + "_m.png")
		candidates.append("res://assets/face/" + key + ".png")

	# 当前 Demo 的安全 fallback：仍优先使用战斗 HUD 头像。
	candidates.append("res://assets/face/aizen_m.png")
	candidates.append("res://assets/face/aizen.png")

	for path: String in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

	return null


func _node_float(node_value: Variant, property_name: String, default_value: float) -> float:
	if node_value == null:
		return default_value
	var obj: Object = node_value as Object
	if obj == null:
		return default_value
	var v: Variant = obj.get(property_name)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	return default_value


func _node_string(node_value: Variant, property_name: String, default_value: String) -> String:
	if node_value == null:
		return default_value
	var obj: Object = node_value as Object
	if obj == null:
		return default_value
	var v: Variant = obj.get(property_name)
	if typeof(v) == TYPE_STRING:
		return String(v)
	return default_value


func _node_bool(node_value: Variant, property_name: String, default_value: bool) -> bool:
	if node_value == null:
		return default_value
	var obj: Object = node_value as Object
	if obj == null:
		return default_value
	var v: Variant = obj.get(property_name)
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	return default_value


func _node_can_hurt_break(node_value: Variant, fzqi_rate: float) -> bool:
	if node_value == null or fzqi_rate < 1.0:
		return false
	var obj: Object = node_value as Object
	if obj == null:
		return false
	if obj.has_method("is_can_hurt_break"):
		var result: Variant = obj.call("is_can_hurt_break")
		if typeof(result) == TYPE_BOOL:
			return bool(result)
	var action_name: String = _node_string(node_value, "current_action", "")
	return action_name == "hurt" or action_name.begins_with("knock") or action_name == "hurt_fly"
