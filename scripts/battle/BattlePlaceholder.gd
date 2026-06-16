extends Control

const ManifestFighter = preload("res://scripts/character/ManifestFighter.gd")
const EffectPlayer = preload("res://scripts/character/EffectPlayer.gd")
const BishaEffectPlayer = preload("res://scripts/character/BishaEffectPlayer.gd")
const CommonEffectLayer = preload("res://scripts/character/CommonEffectLayer.gd")
const FightHud = preload("res://scripts/ui/FightHud.gd")

var p1
var p2
var p1_effect
var bisha_effect
var common_effects: CommonEffectLayer

# 原版 GameStage / GameCamera 显示层。
# HUD 留在根 Control；地图、人物、普通特效放进 game_layer，按原版 camera.scrollRect + scale 逻辑统一移动/缩放。
var game_layer: Node2D
var map_sprite: Sprite2D
var map_bg_sprite: Sprite2D
var map_front_sprite: Node2D
var camera_zoom: float = 1.0
var camera_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(800, 600))

var move_speed: float = 220.0
var dash_distance: float = 180.0

# Step11 原版时间轴控制事件：shine / dash / moveToTarget / movePercent / isApplyG。
# FighterEffectCtrler.shine(color=0xFFFFFF) 会传 alpha=0.3 到 EffectCtrler.shine；
# EffectCtrler.shine 默认 alpha=0.2，但蓝染时间轴使用的是 fighter effect ctrler。
const ORIGINAL_SHINE_WHITE_ALPHA: float = 0.30
const ORIGINAL_SHINE_COLORED_ALPHA: float = 0.20
const ORIGINAL_SHINE_DURATION: float = 0.12
# 原版 Flash 战斗时间轴按 30 fps 计算。move / movePercent / hurtTime 等帧制换算都以此为基准。


# 原版 GenSe.xfl / MapMain.as / GameStage.as / GameCamera.as 依据：
# line_bottom.y=395，line_player_bottom.y=365，GameConfig.GAME_SIZE=800x600，
# MapMain.initlize() offsetY=600-395=205，所以 playerBottom=570，bottom=600。
# p1=(370.1,365)+offsetY，p2=(643.55,365)+offsetY。
# 当前 Godot actions_game PNG 是 normalized centered Sprite2D，idle 非透明底部到纹理中心约 111px；
# 因此在本地 scale=1.25 时，Node2D y = 570 - 111*1.25 = 431.25。
const ORIGINAL_GAME_SIZE := Vector2(800.0, 600.0)
const ORIGINAL_STAGE_SIZE := Vector2(1000.0, 600.0)
const ORIGINAL_MAP_LEFT: float = 0.0
const ORIGINAL_MAP_RIGHT: float = 1000.0
# 原版地图通过 line_left / line_right 限制角色活动范围。
# xianshi.swf 当前已确认 mapLayer 宽 1000；角色不能越过地图可见活动边界，
# 这里用角色可见身体半宽作为边界内缩，避免 camera 到边缘后人物继续走出画面。
const ORIGINAL_FIGHTER_BOUND_MARGIN_X: float = 42.0
const ORIGINAL_PLAYER_BOTTOM: float = 570.0
const ORIGINAL_MAP_BOTTOM: float = 600.0
const ORIGINAL_CAMERA_OFFSET_Y: float = ORIGINAL_MAP_BOTTOM - ORIGINAL_PLAYER_BOTTOM
const ORIGINAL_CAMERA_AUTO_ZOOM_MIN: float = 1.0
const ORIGINAL_CAMERA_AUTO_ZOOM_MAX: float = 2.5
# 原版 GameCamera 仍按 autoZoomMin=1 / autoZoomMax=2.5 / margin=0.8 计算。
# 但当前 Godot 版 xianshi 分层 PNG 与 centered ManifestFighter 的导出基准合成后，实际画面比 3.8.4.3 运行版偏大。
# 这里不改原版公式，只在最终 viewport 显示 zoom 上做一次坐标系校正，让近战最小画面和远景最小画面更接近原版截图。
const GODOT_XIANSHI_CAMERA_VISUAL_SCALE: float = 0.80
const ORIGINAL_CAMERA_TWEEN_SPEED: float = 2.5
const ORIGINAL_CAMERA_MARGIN_RATE: float = 0.8
const ORIGINAL_FIGHTER_SCALE: float = 1.25
const ORIGINAL_IDLE_FOOT_FROM_CENTER: float = 111.0
const ORIGINAL_FIGHTER_FOOT_OFFSET_Y: float = ORIGINAL_IDLE_FOOT_FROM_CENTER * ORIGINAL_FIGHTER_SCALE
const GROUND_Y: float = ORIGINAL_PLAYER_BOTTOM - ORIGINAL_FIGHTER_FOOT_OFFSET_Y
const P1_START_POS := Vector2(370.1, GROUND_Y)
const P2_START_POS := Vector2(643.55, GROUND_Y)
const ORIGINAL_XIANSHI_MAP_Y: float = ORIGINAL_MAP_BOTTOM - 397.0
# 原版 xianshi.swf / MapMain.as：frontLayer 在 _playerLayer 上方，render(gameX, gameY, zoom) 时按 0.1 视差移动。
# FFDec 导出的 DefineSprite_18 是 1201x229；mapLayer 宽 1000，所以默认 x 取居中后的 -100.5，
# 默认 y 按 bottom=600 与 frontLayer 高度 229 对齐到 371。
const ORIGINAL_XIANSHI_FRONT_WIDTH: float = 1201.0
const ORIGINAL_XIANSHI_FRONT_HEIGHT: float = 229.0
# v15：不再用“按宽度居中”的猜测值。
# 直接使用 xianshi.swf 根时间轴 PlaceObject2 读取到的 front Matrix：x=430.5, y=166.5。
# MapMain.initlize() 会把 frontLayer.y += offsetY，其中 offsetY = 600 - line_bottom.y = 205。
const ORIGINAL_XIANSHI_FRONT_ROOT_POS := Vector2(430.5, 166.5)
const ORIGINAL_XIANSHI_FRONT_DEFAULT_POS := Vector2(430.5, 166.5 + (ORIGINAL_GAME_SIZE.y - 395.0))
const ORIGINAL_FRONT_OPTICAL_ALPHA: float = 0.5

var prev_j_pressed: bool = false
var prev_k_pressed: bool = false
var prev_l_pressed: bool = false
var prev_u_pressed: bool = false
var prev_i_pressed: bool = false
var prev_p_pressed: bool = false
var prev_t_pressed: bool = false

# 原版 FighterAttacker 里 followTargetX / followTargetY 每帧跟随 currentTarget。
# 当前 Demo 是单目标 P2，因此 currentTarget 按原版语义固定映射到 P2；bsmc 每帧跟随 P2 地面坐标。
# Aizen mc_023.xml 原版 addAttacker 位置依据：
#   bsmc  : global frame 804, params={x:{followTarget:true,offset:0}, y:{followTarget:true,offset:-25}, applyG:false}
#   zh3mc : global frame 680, params={applyG:false}, child Matrix tx=28.15, ty=-3466.3
# 当前 zh3mc PNG 来自 FFDec 展平导出，已丢失原始 3466px 注册点画布；
# 因此 visual offset 保持已验证的 FFDec rebased 偏移，攻击面仍使用 XFL 推导出的 ZH3ATM_RECT。
# Step6 报告已确认：
#   mc_023 frame804 bsmc instance Matrix = tx=149.35, ty=-19.65
#   但 FighterAttacker.as 在 params.x/y 为 object 且 offset 存在时，会把 _startX/_startY 改为 offset，
#   renderFollowTarget() 每帧使用 target.x + _startX * direct / target.y + _startY。
#   所以 bsmc 的最终世界原点应来自 raw addAttacker params，而不是 mc_023 的静态 Matrix。
const BSMC_MC023_INSTANCE_MATRIX := Vector2(149.35, -19.65)
const BSMC_ORIGINAL_TARGET_OFFSET := Vector2(0.0, -25.0)
# bsmc 视觉帧来自 FFDec 展平后的 443x377 画布。Step8 已确认 EffectPlayer 缺少注册点逻辑，
# Step9 起视觉注册点不再由 BattlePlaceholder 硬编码，而写入 aizen_effect_manifest.json:
#   bsmc.visual_offset = [6, -5]
# 此常量仅作为原版对照记录，不参与运行逻辑。
const BSMC_FFDEC_CANVAS_TO_ORIGINAL_REGISTRATION := Vector2(6.0, -5.0)

# Step6 报告已确认：
#   mc_023 frame680 zh3mc instance Matrix = tx=28.15, ty=-3466.3
#   mc_015 内 zh3atm Matrix = tx=32.25, ty=4043.9, a=-0.367..., d=-27.270...
#   合成后得到当前 ZH3ATM_RECT 的超高攻击区域。当前 FFDec 视觉 PNG 已丢失原始 -3466 注册点画布，
#   所以视觉仍使用 FFDec-rebased offset；攻击面继续用 XFL 合成矩形，不从截图手调。
const ZH3MC_MC023_INSTANCE_MATRIX := Vector2(28.15, -3466.3)
const ZH3MC_ZH3ATM_MATRIX_IN_MC015 := Vector2(32.25, 4043.9)
# Step9 起 zh3mc 视觉注册点也迁移到 aizen_effect_manifest.json:
#   zh3mc.visual_offset = [118, -118], visual_offset_mirrors_with_facing = true
# 此常量仅作为 Step6/Step8 报告对照记录，不参与运行逻辑。
const ZH3MC_FFDEC_REBASED_VISUAL_OFFSET := Vector2(118.0, -118.0)
var active_attacker_follow_target: bool = false
var active_attacker_effect_name: String = ""
var active_attacker_offset: Vector2 = Vector2.ZERO
var active_attacker_original_origin: Vector2 = Vector2.ZERO
var active_attacker_facing: int = 1

# 第 6 步：原版攻击面调试显示。
# 已确认：mc_024 是基础攻击面，原始 shape 边界为 1319 x 810 XFL 单位；换算为 Flash 像素约 65.95 x 40.5。
# 这些矩形只用于对齐/验证，不是最终伤害系统。后续会接 HitVO、hurtbox、GameLogic.hitTarget。
const DEBUG_ORIGINAL_ATTACK_BOX_DEFAULT := false
const ORIGINAL_DEV_KEYS_ENABLED := false
const XFL_BASE_ATM_SIZE := Vector2(65.95, 40.5)
const BS1ATM_RECT := Rect2(Vector2(-49.75, -63.9), Vector2(107.57, 123.83))
const BSATM_RECT := Rect2(Vector2(-88.9, -84.45), Vector2(174.04, 178.19))
const ZH3ATM_RECT := Rect2(Vector2(36.19, -526.86), Vector2(24.69, 1104.46))

# 第 7 步：P2 被打面 + 初步命中反应。
# bdmn 来自 mc_023 “被打面”层，大多数动作使用同一套 mc_024 矩形：
# Matrix(a=0.2702484, d=1.3928070, tx=-8.8, ty=-31.65)。
# mc_024 基础尺寸 65.95 x 40.5，所以换算为舞台像素约 17.82 x 56.41。
const BDMN_DEFAULT_HURT_RECT := Rect2(Vector2(-8.8, -31.65), Vector2(17.82, 56.41))

# 第 8 步：从蓝染 DOMDocument.xml 的 defineAction 抽出原版 HitVO 核心数据。
# FighterHitModel.getHitVOByDisplayName 会把显示对象名 bs1atm / bsatm / zh3atm 映射为 bs1 / bs / zh3。
const AIZEN_HIT_VO := {
	# DOMDocument.xml defineAction：蓝染空中 J / U / I。
	"tk": {"id":"tk", "power":50, "powerRate":1.0, "hitType":6, "hitx":6, "hity":6, "hurtTime":600, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"tz": {"id":"tz", "power":80, "powerRate":1.0, "hitType":5, "hitx":10, "hity":0, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"kbs": {"id":"kbs", "power":200, "powerRate":1.0, "hitType":5, "hitx":15, "hity":8, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},

	# DOMDocument.xml defineAction：蓝染 J 普攻连段。
	"k1": {"id":"k1", "power":30, "powerRate":1.0, "hitType":1, "hitx":1, "hity":0, "hurtTime":300, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"k2": {"id":"k2", "power":30, "powerRate":1.0, "hitType":1, "hitx":3, "hity":0, "hurtTime":400, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"k3": {"id":"k3", "power":50, "powerRate":1.0, "hitType":6, "hitx":4, "hity":0, "hurtTime":600, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"k4": {"id":"k4", "power":50, "powerRate":1.0, "hitType":6, "hitx":5, "hity":0, "hurtTime":400, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"k5": {"id":"k5", "power":30, "powerRate":1.0, "hitType":1, "hitx":5, "hity":-2, "hurtTime":600, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"k52": {"id":"k52", "power":30, "powerRate":1.0, "hitType":1, "hitx":3, "hity":-5, "hurtTime":600, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},

	# 蓝染 S+J / W+J。
	"kj1": {"id":"kj1", "power":100, "powerRate":1.0, "hitType":6, "hitx":3, "hity":0, "hurtTime":500, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"kj12": {"id":"kj12", "power":110, "powerRate":1.0, "hitType":6, "hitx":7, "hity":0, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"kj21": {"id":"kj21", "power":40, "powerRate":1.0, "hitType":6, "hitx":1, "hity":0, "hurtTime":600, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"kj2": {"id":"kj2", "power":120, "powerRate":1.0, "hitType":5, "hitx":10, "hity":-10, "hurtTime":0, "hurtType":1, "isBreakDef":true, "isReal":false, "isApplyG":true},
	"kj22": {"id":"kj22", "power":50, "powerRate":1.0, "hitType":6, "hitx":7, "hity":0, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},

	# 蓝染 U / S+U / W+U。
	"zh1": {"id":"zh1", "power":100, "powerRate":1.0, "hitType":9, "hitx":15, "hity":0, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"zh2": {"id":"zh2", "power":110, "powerRate":1.0, "hitType":5, "hitx":30, "hity":-5, "hurtTime":0, "hurtType":1, "isBreakDef":true, "isReal":false, "isApplyG":true},
	"zh31": {"id":"zh31", "power":100, "powerRate":1.0, "hitType":5, "hitx":20, "hity":-3, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},

	# 已接入的招3/普通必杀 attacker。
	"bs1": {"id":"bs1", "power":20, "powerRate":1.0, "hitType":1, "hitx":0, "hity":0, "hurtTime":500, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"bs": {"id":"bs", "power":80, "powerRate":1.0, "hitType":5, "hitx":10, "hity":0, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},

	# 蓝染 W+I / S+I。
	"sbs": {"id":"sbs", "power":150, "powerRate":1.0, "hitType":5, "hitx":0, "hity":-15, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"sbs1": {"id":"sbs1", "power":30, "powerRate":1.0, "hitType":1, "hitx":5, "hity":0, "hurtTime":500, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"sbs2": {"id":"sbs2", "power":30, "powerRate":1.0, "hitType":1, "hitx":6, "hity":-6, "hurtTime":500, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"sbs3": {"id":"sbs3", "power":30, "powerRate":1.0, "hitType":1, "hitx":6, "hity":6, "hurtTime":500, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"sbs4": {"id":"sbs4", "power":50, "powerRate":1.0, "hitType":6, "hitx":3, "hity":0, "hurtTime":1000, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"cbs2": {"id":"cbs2", "power":15, "powerRate":1.0, "hitType":4, "hitx":1, "hity":-0.1, "hurtTime":500, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"cbs": {"id":"cbs", "power":150, "powerRate":1.0, "hitType":5, "hitx":2, "hity":-10, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":true, "isApplyG":true},

	"zh3": {"id":"zh3", "power":100, "powerRate":1.0, "hitType":5, "hitx":10, "hity":0, "hurtTime":700, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true}
}

# mc_023 主时间轴里的普攻攻击面。矩形由 mc_024 基础尺寸 65.95 x 40.5 乘以 Matrix(a,d)，再加 tx/ty 得到。
# 这些不是手写猜测框，而是从 k1atm / k2atm / k3atm / k4atm / k5atm / k52atm 的 XFL Matrix 换算。
const K1ATM_RECT := Rect2(Vector2(-36.30, -27.85), Vector2(90.93, 42.07))
const K2ATM_RECT := Rect2(Vector2(-61.00, -34.85), Vector2(126.89, 65.69))
const K3ATM_RECT := Rect2(Vector2(-49.75, -19.10), Vector2(153.68, 27.14))
const K4ATM_RECT_A := Rect2(Vector2(-48.10, -24.85), Vector2(82.35, 35.53))
const K4ATM_RECT_B := Rect2(Vector2(-44.30, -24.85), Vector2(90.61, 35.53))
const K5ATM_RECT_A := Rect2(Vector2(-30.85, -62.75), Vector2(141.40, 85.35))
const K5ATM_RECT_B := Rect2(Vector2(-29.75, -60.20), Vector2(150.80, 83.37))
const K52ATM_RECT := Rect2(Vector2(-25.50, -80.40), Vector2(172.33, 105.99))

# 第 9 步：蓝染 S+J / W+J 技能攻击面。
# 砍技1：不是主动命中技，而是 setHurtAction("砍技1_HA") 的反击动作；真正攻击面 kj1atm 在“砍技1_HA”全局帧 458-460。
# 砍技2：先用 kj2_chkm 检测目标，命中后跳到“砍技2_CHK”；后续 W+J 可进入“砍技2_1”。
const KJ1ATM_RECT := Rect2(Vector2(-50.30, -25.75), Vector2(255.31, 41.19))
const KJ2_CHKM_RECT := Rect2(Vector2(-0.40, -29.40), Vector2(79.60, 54.93))
const KJ21ATM_RECT := Rect2(Vector2(-98.90, -37.55), Vector2(165.73, 57.64))
const KJ2ATM_RECT := Rect2(Vector2(15.70, -76.15), Vector2(113.09, 131.93))

# 第 12 步：蓝染 U / S+U。
# 招1：zh1atm 在全局帧 511/513/515/517，矩形由 mc_024 + Matrix 换算。
# 招2：先用 zh2_chkm 检测，命中后跳转到“招2_CHK”，zh2atm 负责实际攻击。
const ZH1ATM_RECT_A := Rect2(Vector2(14.15, -35.95), Vector2(113.10, 46.33))
const ZH1ATM_RECT_B := Rect2(Vector2(18.00, -33.20), Vector2(214.34, 49.19))
const ZH1ATM_RECT_C := Rect2(Vector2(23.55, -45.95), Vector2(309.90, 68.08))
const ZH1ATM_RECT_D := Rect2(Vector2(24.55, -42.45), Vector2(307.10, 53.13))
const ZH2_CHKM_RECT := Rect2(Vector2(-14.20, -33.05), Vector2(48.39, 58.01))
const ZH2ATM_RECT := Rect2(Vector2(6.30, -65.80), Vector2(55.37, 107.87))

# 第 13 步：蓝染空中攻击面。
# 跳砍 start=78：tkatm 全局帧 81-84，对应 relative 3-6。
# 跳招 start=103：tzatm 全局帧 118-127，对应 relative 15-24。
# 空中必杀 start=1126：kbsatm 全局帧 1148-1150，对应 relative 22-24。
const TKATM_RECT_A := Rect2(Vector2(-24.80, -57.85), Vector2(91.55, 152.01))
const TKATM_RECT_B := Rect2(Vector2(24.15, 6.65), Vector2(80.36, 127.20))
const TZATM_RECT_A := Rect2(Vector2(-75.60, -35.55), Vector2(152.68, 65.57))
const TZATM_RECT_B := Rect2(Vector2(-75.60, -84.30), Vector2(152.68, 113.63))
const TZATM_RECT_C := Rect2(Vector2(-88.35, -139.65), Vector2(188.36, 171.16))
const KBSATM_RECT := Rect2(Vector2(-55.50, -103.15), Vector2(197.80, 200.25))

# 第 14 步：蓝染 W+I 上必杀 / S+I 超必杀攻击面。
# 矩形来自 mc_023 攻击面层 sbs1atm/sbs2atm/sbs3atm/sbs4atm/sbsatm/cbs2atm/cbsatm 的 Matrix。
const SBS1ATM_RECT_A := Rect2(Vector2(-37.30, -43.39), Vector2(91.80, 57.89))
const SBS1ATM_RECT_B := Rect2(Vector2(-48.75, -32.10), Vector2(107.02, 45.70))
const SBS1ATM_RECT_C := Rect2(Vector2(-8.80, -30.77), Vector2(92.90, 57.17))
const SBS2ATM_RECT := Rect2(Vector2(-61.40, -34.12), Vector2(127.71, 64.67))
const SBS3ATM_RECT := Rect2(Vector2(-24.10, -40.95), Vector2(81.88, 90.40))
const SBS1ATM_RECT_D := Rect2(Vector2(-32.70, -55.37), Vector2(83.37, 67.42))
const SBS4ATM_RECT_A := Rect2(Vector2(-37.05, -41.73), Vector2(140.95, 72.38))
const SBS4ATM_RECT_B := Rect2(Vector2(-22.30, -82.91), Vector2(128.41, 119.81))
const SBSATM_RECT_A := Rect2(Vector2(50.65, -278.75), Vector2(27.25, 506.70))
const SBSATM_RECT_B := Rect2(Vector2(54.40, -278.75), Vector2(20.45, 506.70))
const SBSATM_RECT_C := Rect2(Vector2(55.40, -278.75), Vector2(18.11, 506.70))
const CBS2ATM_RECT := Rect2(Vector2(-611.05, -444.42), Vector2(1213.78, 897.37))
const CBSATM_RECT := Rect2(Vector2(-611.05, -444.42), Vector2(1213.78, 897.37))


var p1_hp_bar: ColorRect
var p2_hp_bar: ColorRect
var p1_hp_label: Label
var p2_hp_label: Label
var p1_qi_bar: ColorRect
var p2_qi_bar: ColorRect
var p1_energy_bar: ColorRect
var p2_energy_bar: ColorRect
var p1_qi_label: Label
var p2_qi_label: Label
var p1_combo_label: Label
var p2_combo_label: Label
var ko_label: Label
var fight_hud: Control

var p1_combo_count: int = 0
var p2_combo_count: int = 0
var p1_combo_timer: float = 0.0
var p2_combo_timer: float = 0.0
var p1_score: int = 0
var p2_score: int = 0
var ko_finished: bool = false

# 原版 EffectCtrler 反馈：命中/防御/破防会带 freeze / shine / shake。
# 这里不直接暂停整棵树，避免 Godot 音频/UI 被卡住；用短时间 hit-stop + 画面闪白/震动近似原版效果。
var hit_stop_timer: float = 0.0
var shake_timer: float = 0.0
var shake_power: Vector2 = Vector2.ZERO
var shine_overlay: ColorRect
var shine_alpha: float = 0.0

const COMBO_RESET_TIME := 1.25
const QI_HIT_MAX := 15.0
const QI_HURT_MAX := 20.0

# 原版 FightUI.showStart：startKOmc.gotoAndStop("start") 从 frame 9 起播。
# AS 事件帧：frame54 = fight_in，frame57 = fight，frame87 = COMPLETE。
# 因为从 label start(frame9) 开始，所以输入锁定应约为 (57-9)/30。
const START_LABEL_FRAME: float = 9.0
const START_FIGHT_IN_FRAME: float = 54.0
const START_FIGHT_FRAME: float = 57.0
const START_COMPLETE_FRAME: float = 87.0
const ROUND_INTRO_TOTAL_TIME: float = (START_COMPLETE_FRAME - START_LABEL_FRAME) / 30.0
const ROUND_INTRO_FIGHT_IN_TIME: float = (START_FIGHT_IN_FRAME - START_LABEL_FRAME) / 30.0
const ROUND_INTRO_FIGHT_TIME: float = (START_FIGHT_FRAME - START_LABEL_FRAME) / 30.0

# 原版 showEnd：KO 前 500ms 先做 hit_end/shine/shake/snd_over_hit；随后 startKOmc 播 ko label。
const KO_PRE_DELAY_TIME: float = 0.5
const KO_ANIM_TIME: float = (189.0 - 144.0) / 30.0
const WINNER_ANIM_TIME: float = (209.0 - 199.0) / 30.0
const TIMEOVER_ANIM_TIME: float = (262.0 - 219.0) / 30.0
const DRAWGAME_ANIM_TIME: float = (308.0 - 266.0) / 30.0
const WINNER_DELAY_AFTER_KO: float = 2.0
const WINNER_DELAY_AFTER_TIMEOVER: float = 1.0

# 原版 FightTimeUI 从 GameCtrler.I.gameRunData.gameTime 读取。这里 Demo 默认 99 秒；设 -1 可显示无限。
const DEMO_GAME_TIME_MAX: int = -1

var round_intro_timer: float = 0.0
var fight_input_lock_timer: float = 0.0
var round_intro_phase: int = -1
var ko_sequence_timer: float = 0.0
var ko_winner_id: int = 0
var ko_perfect: bool = false
var ko_winner_shown: bool = false
var ko_anim_phase: int = 0 # 0 none, 1 pre-delay, 2 ko/timeover anim, 3 winner delay, 4 done
var ko_draw_game: bool = false
var ko_timeover: bool = false
var game_time_left: float = float(DEMO_GAME_TIME_MAX)
var game_time_enabled: bool = DEMO_GAME_TIME_MAX >= 0
var time_over_finished: bool = false
var ko_score_added: bool = false

var attack_debug_layer: Control
var attack_debug_box: ColorRect
var attack_debug_label: Label
var target_hurt_debug_box: ColorRect
var target_hurt_debug_label: Label
var attack_debug_enabled: bool = DEBUG_ORIGINAL_ATTACK_BOX_DEFAULT
var active_original_hitbox: String = ""
var current_attack_world_rect: Rect2 = Rect2()
var current_attack_label: String = ""
var current_hit_vo_id: String = ""
var active_attacker_has_hit: bool = false
var active_attack_key: String = ""

var pending_hit_target_checker: String = ""
var pending_hit_target_action: String = ""
var pending_hit_target_enabled: bool = false
var attack_skill2_1_ready: bool = false
var attack_skill2_next_attack_ready: bool = false

# 第 13 步：空中 J / U / I 的原版衔接窗口。
# 跳砍第 9 帧 setBishaAIR + setSkillAIR 后，原版允许继续接空中 U 或空中 I。
var p1_air_skill_ready: bool = false
var p1_air_bisha_ready: bool = false

# 第 10 步补充：P2 最小攻击测试，用来验证原版 setHurtAction 反击逻辑。
# 这不是最终 P2 控制方案，只是为了让 P1 的 S+J “砍技1”能被真实 HitVO 打中后转入 砍技1_HA。
var p2_attack_debug_box: ColorRect
var p2_attack_debug_label: Label
var p1_hurt_debug_box: ColorRect
var p1_hurt_debug_label: Label
var p2_test_attack_has_hit: bool = false
var p2_test_attack_key: String = ""

# 原版 justHitToPlay：只检查当前动作中刚命中的攻击 ID。
var p1_last_hit_vo_id: String = ""
var p1_last_hit_action: String = ""
var p2_last_hit_vo_id: String = ""
var p2_last_hit_action: String = ""


func _ready() -> void:
	print("BattlePlaceholder ready")
	AudioManager.play_music("res://assets/bgm/bleach.mp3")
	create_background()
	create_ui()
	create_attack_debug_layer()
	spawn_fighters()
	update_original_camera(0.0, true)
	start_round_intro()


func create_background() -> void:
	# 原版 xianshi.swf 并不是当前项目早期使用的 450x270 合成小图。
	# FFDec 导出确认：
	#   DefineSprite_3 / 1.png = 800x600 原版远景背景组合层；
	#   images/4.png = 1000x397 原版 map 主层，透明 PNG；
	#   DefineSprite_18 / 1.png = 1201x229 原版 front 候选层，先保留资源，不叠加以免与 images/4 重复。
	# 因此这里取消旧 xianshi.png * 2.222 缩放，改为原版 SWF 导出的实际像素层。
	var fixed_bg := TextureRect.new()
	fixed_bg.name = "XianshiOriginalBgStage"
	fixed_bg.texture = load("res://assets/maps/xianshi_layers/bg_stage.png")
	if fixed_bg.texture == null:
		fixed_bg.texture = load("res://assets/maps/xianshi.png")
	fixed_bg.position = Vector2.ZERO
	fixed_bg.size = ORIGINAL_GAME_SIZE
	fixed_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fixed_bg.stretch_mode = TextureRect.STRETCH_SCALE
	fixed_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fixed_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fixed_bg)
	move_child(fixed_bg, 0)

	game_layer = Node2D.new()
	game_layer.name = "OriginalGameLayer"
	game_layer.z_index = 1
	add_child(game_layer)

	map_sprite = Sprite2D.new()
	map_sprite.name = "XianshiOriginalMapLayer"
	map_sprite.texture = load("res://assets/maps/xianshi_layers/map_layer.png")
	if map_sprite.texture == null:
		push_error("xianshi 原版 map_layer.png 没有加载成功，请检查 res://assets/maps/xianshi_layers/map_layer.png")
	map_sprite.centered = false
	map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_sprite.scale = Vector2.ONE
	# images/4.png 高 397，原版 bottom=600，因此主 map 层 y=203。
	# 这一步替代旧版 450x270 合成图放大，避免地面/角色比例失真。
	if map_sprite.texture != null:
		map_sprite.position = Vector2(0.0, ORIGINAL_XIANSHI_MAP_Y)
	game_layer.add_child(map_sprite)

	# v15：frontLayer 不再用 FFDec 导出的整张扁平 Sprite 直接盖在角色上。
	# 原版 MapMain.renderOptical(frontLayer) 是逐个 front 子 MovieClip 检测角色 area，
	# 相交的子元件 alpha=0.5；如果使用整张 flat PNG，就无法做到逐元件透明，会出现柱子完全盖住角色。
	# 这里按 xianshi.swf 的 DefineSprite_18 display list 重建 frontLayer 子元件。
	map_front_sprite = Node2D.new()
	map_front_sprite.name = "XianshiOriginalFrontLayer"
	map_front_sprite.position = ORIGINAL_XIANSHI_FRONT_DEFAULT_POS
	map_front_sprite.z_index = 90
	game_layer.add_child(map_front_sprite)
	_build_xianshi_front_layer_children()


func create_ui() -> void:
	fight_hud = FightHud.new()
	fight_hud.name = "FightHud"
	fight_hud.z_index = 200
	fight_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fight_hud)
	if fight_hud.has_method("setup"):
		fight_hud.call("setup", GameData.p1_character, GameData.p2_character)

	# 保留一个独立 KO Label，避免旧场景里引用 ko_label 时报空；FightHud 自己也有 show_ko。
	ko_label = Label.new()
	ko_label.position = Vector2(250, 220)
	ko_label.size = Vector2(300, 90)
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_label.add_theme_font_size_override("font_size", 64)
	ko_label.add_theme_color_override("font_color", Color(1, 0.15, 0.05, 1))
	ko_label.visible = false
	ko_label.z_index = 210
	add_child(ko_label)

func create_hp_ui() -> void:
	var p1_back := ColorRect.new()
	p1_back.position = Vector2(20, 86)
	p1_back.size = Vector2(260, 14)
	p1_back.color = Color(0.05, 0.05, 0.05, 0.85)
	add_child(p1_back)

	p1_hp_bar = ColorRect.new()
	p1_hp_bar.position = p1_back.position
	p1_hp_bar.size = p1_back.size
	p1_hp_bar.color = Color(0.85, 0.15, 0.15, 0.95)
	add_child(p1_hp_bar)

	p1_hp_label = Label.new()
	p1_hp_label.position = Vector2(20, 102)
	p1_hp_label.size = Vector2(300, 22)
	p1_hp_label.add_theme_font_size_override("font_size", 14)
	p1_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(p1_hp_label)

	var p2_back := ColorRect.new()
	p2_back.position = Vector2(520, 86)
	p2_back.size = Vector2(260, 14)
	p2_back.color = Color(0.05, 0.05, 0.05, 0.85)
	add_child(p2_back)

	p2_hp_bar = ColorRect.new()
	p2_hp_bar.position = p2_back.position
	p2_hp_bar.size = p2_back.size
	p2_hp_bar.color = Color(0.85, 0.15, 0.15, 0.95)
	add_child(p2_hp_bar)

	p2_hp_label = Label.new()
	p2_hp_label.position = Vector2(520, 102)
	p2_hp_label.size = Vector2(260, 22)
	p2_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_hp_label.add_theme_font_size_override("font_size", 14)
	p2_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(p2_hp_label)

	var p1_qi_back := ColorRect.new()
	p1_qi_back.position = Vector2(20, 128)
	p1_qi_back.size = Vector2(260, 8)
	p1_qi_back.color = Color(0.05, 0.05, 0.05, 0.85)
	add_child(p1_qi_back)

	p1_qi_bar = ColorRect.new()
	p1_qi_bar.position = p1_qi_back.position
	p1_qi_bar.size = p1_qi_back.size
	p1_qi_bar.color = Color(0.15, 0.35, 1.0, 0.95)
	add_child(p1_qi_bar)

	var p1_energy_back := ColorRect.new()
	p1_energy_back.position = Vector2(20, 140)
	p1_energy_back.size = Vector2(260, 7)
	p1_energy_back.color = Color(0.05, 0.05, 0.05, 0.85)
	add_child(p1_energy_back)

	p1_energy_bar = ColorRect.new()
	p1_energy_bar.position = p1_energy_back.position
	p1_energy_bar.size = p1_energy_back.size
	p1_energy_bar.color = Color(1.0, 0.9, 0.2, 0.95)
	add_child(p1_energy_bar)

	p1_qi_label = Label.new()
	p1_qi_label.position = Vector2(20, 150)
	p1_qi_label.size = Vector2(300, 22)
	p1_qi_label.add_theme_font_size_override("font_size", 13)
	p1_qi_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(p1_qi_label)

	p1_combo_label = Label.new()
	p1_combo_label.position = Vector2(290, 118)
	p1_combo_label.size = Vector2(150, 42)
	p1_combo_label.add_theme_font_size_override("font_size", 24)
	p1_combo_label.add_theme_color_override("font_color", Color(1, 0.95, 0.2, 1))
	p1_combo_label.visible = false
	add_child(p1_combo_label)

	var p2_qi_back := ColorRect.new()
	p2_qi_back.position = Vector2(520, 128)
	p2_qi_back.size = Vector2(260, 8)
	p2_qi_back.color = Color(0.05, 0.05, 0.05, 0.85)
	add_child(p2_qi_back)

	p2_qi_bar = ColorRect.new()
	p2_qi_bar.position = p2_qi_back.position
	p2_qi_bar.size = p2_qi_back.size
	p2_qi_bar.color = Color(0.15, 0.35, 1.0, 0.95)
	add_child(p2_qi_bar)

	var p2_energy_back := ColorRect.new()
	p2_energy_back.position = Vector2(520, 140)
	p2_energy_back.size = Vector2(260, 7)
	p2_energy_back.color = Color(0.05, 0.05, 0.05, 0.85)
	add_child(p2_energy_back)

	p2_energy_bar = ColorRect.new()
	p2_energy_bar.position = p2_energy_back.position
	p2_energy_bar.size = p2_energy_back.size
	p2_energy_bar.color = Color(1.0, 0.9, 0.2, 0.95)
	add_child(p2_energy_bar)

	p2_qi_label = Label.new()
	p2_qi_label.position = Vector2(480, 150)
	p2_qi_label.size = Vector2(300, 22)
	p2_qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_qi_label.add_theme_font_size_override("font_size", 13)
	p2_qi_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(p2_qi_label)

	p2_combo_label = Label.new()
	p2_combo_label.position = Vector2(360, 118)
	p2_combo_label.size = Vector2(150, 42)
	p2_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_combo_label.add_theme_font_size_override("font_size", 24)
	p2_combo_label.add_theme_color_override("font_color", Color(1, 0.95, 0.2, 1))
	p2_combo_label.visible = false
	add_child(p2_combo_label)

	ko_label = Label.new()
	ko_label.position = Vector2(250, 220)
	ko_label.size = Vector2(300, 90)
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_label.add_theme_font_size_override("font_size", 64)
	ko_label.add_theme_color_override("font_color", Color(1, 0.15, 0.05, 1))
	ko_label.visible = false
	add_child(ko_label)


func spawn_fighters() -> void:
	if GameData.p1_character == "aizen":
		p1 = ManifestFighter.new()
		game_layer.add_child(p1)
		p1.position = P1_START_POS
		p1.ground_y = GROUND_Y
		p1.scale = Vector2(ORIGINAL_FIGHTER_SCALE, ORIGINAL_FIGHTER_SCALE)
		p1.z_index = 10
		p1.setup("res://assets/characters/aizen/aizen_game_manifest.json")
		p1.frame_event.connect(_on_p1_frame_event)
	else:
		create_placeholder_player(GameData.p1_character, P1_START_POS)

	if GameData.p2_character == "aizen":
		p2 = ManifestFighter.new()
		game_layer.add_child(p2)
		p2.position = P2_START_POS
		p2.ground_y = GROUND_Y
		p2.scale = Vector2(ORIGINAL_FIGHTER_SCALE, ORIGINAL_FIGHTER_SCALE)
		p2.z_index = 10
		p2.setup("res://assets/characters/aizen/aizen_game_manifest.json")
		p2.set_facing(-1)
	else:
		p2 = create_placeholder_player(GameData.p2_character, P2_START_POS)

	spawn_effect_players()


func spawn_effect_players() -> void:
	p1_effect = EffectPlayer.new()
	p1_effect.z_index = 20
	game_layer.add_child(p1_effect)
	p1_effect.setup("res://assets/characters/aizen/aizen_effect_manifest.json")

	common_effects = CommonEffectLayer.new()
	common_effects.z_index = 80
	game_layer.add_child(common_effects)

	bisha_effect = BishaEffectPlayer.new()
	add_child(bisha_effect)
	bisha_effect.z_index = 100

	create_shine_overlay()


func create_shine_overlay() -> void:
	if shine_overlay != null:
		return
	shine_overlay = ColorRect.new()
	shine_overlay.name = "OriginalShineOverlay"
	shine_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shine_overlay.color = Color(1, 1, 1, 0)
	shine_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine_overlay.z_index = 190
	add_child(shine_overlay)


func create_placeholder_player(char_id: String, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = char_id
	label.position = pos - Vector2(60, 100)
	label.size = Vector2(160, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.set_meta("ground_pos", pos)
	if game_layer != null:
		game_layer.add_child(label)
	else:
		add_child(label)
	return label


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		return

	if ORIGINAL_DEV_KEYS_ENABLED and Input.is_key_pressed(KEY_H):
		if not has_meta("h_down"):
			set_meta("h_down", true)
			attack_debug_enabled = not attack_debug_enabled
			if not attack_debug_enabled:
				clear_original_attack_box()
	else:
		if has_meta("h_down"):
			remove_meta("h_down")

	update_original_visual_feedback(delta)
	update_round_intro(delta)
	update_ko_sequence(delta)

	if p1 == null:
		return

	if hit_stop_timer > 0.0:
		hit_stop_timer = maxf(0.0, hit_stop_timer - delta)
		update_hp_ui()
		update_resource_ui()
		update_original_camera(delta)
		return

	update_attacker_follow_target()
	update_original_attack_box()
	update_target_hurt_box()
	update_p1_hurt_box()
	update_pending_hit_target_check()
	check_active_hit_target()
	update_p2_test_attack_box()
	update_hp_ui()
	# 先更新 combo 计时，再刷新 HUD；否则 combo 归零后的这一帧仍会把上一帧 HITS 贴图写回去。
	update_combo_timers(delta)
	update_resource_ui()
	update_fight_timer(delta)
	check_ko_state()
	if fight_input_lock_timer > 0.0:
		update_original_camera(delta)
		return
	if p1 != null and not bool(p1.get("in_air")):
		p1_air_skill_ready = false
		p1_air_bisha_ready = false
	handle_p1_input(delta)
	clamp_fighters_to_original_map_bounds()
	if ORIGINAL_DEV_KEYS_ENABLED:
		handle_p2_debug_input()
	update_original_camera(delta)



func update_original_camera(_delta: float, immediate: bool = false) -> void:
	if game_layer == null or p1 == null or p2 == null:
		return
	var p1_focus := _camera_focus_point(p1, P1_START_POS)
	var p2_focus := _camera_focus_point(p2, P2_START_POS)
	var left_focus := minf(p1_focus.x, p2_focus.x)
	var right_focus := maxf(p1_focus.x, p2_focus.x)
	var up_focus := minf(p1_focus.y, p2_focus.y)
	var down_focus := maxf(p1_focus.y, p2_focus.y)
	var distance_x: float = maxf(1.0, right_focus - left_focus)
	var distance_y: float = maxf(1.0, down_focus - up_focus)
	var zoom_x: float = ORIGINAL_GAME_SIZE.x / distance_x * ORIGINAL_CAMERA_MARGIN_RATE
	var zoom_y: float = ORIGINAL_GAME_SIZE.y / distance_y * ORIGINAL_CAMERA_MARGIN_RATE
	var original_logic_zoom: float = clampf(minf(zoom_x, zoom_y), ORIGINAL_CAMERA_AUTO_ZOOM_MIN, ORIGINAL_CAMERA_AUTO_ZOOM_MAX)
	var target_zoom: float = maxf(0.001, original_logic_zoom * GODOT_XIANSHI_CAMERA_VISUAL_SCALE)

	var focus_center := Vector2((left_focus + right_focus) * 0.5, (up_focus + down_focus) * 0.5)
	var view_size := ORIGINAL_GAME_SIZE / target_zoom
	var target_rect := Rect2(Vector2.ZERO, view_size)
	target_rect.position.x = focus_center.x - view_size.x * 0.5
	target_rect.position.y = focus_center.y - view_size.y * 0.5 - ORIGINAL_CAMERA_OFFSET_Y

	# 对齐 GameCamera.setStageBounds(new Rectangle(0, -1000, stageSize.x, stageSize.y)) 的边界修正。
	var min_x := ORIGINAL_MAP_LEFT
	var max_x := maxf(min_x, ORIGINAL_MAP_RIGHT - view_size.x)
	var min_y := -1000.0 * target_zoom
	var max_y := maxf(min_y, ORIGINAL_MAP_BOTTOM - view_size.y)
	target_rect.position.x = clampf(target_rect.position.x, min_x, max_x)
	target_rect.position.y = clampf(target_rect.position.y, min_y, max_y)

	if immediate:
		camera_zoom = target_zoom
		camera_rect = target_rect
	else:
		camera_zoom += (target_zoom - camera_zoom) / ORIGINAL_CAMERA_TWEEN_SPEED
		camera_rect.position += (target_rect.position - camera_rect.position) / ORIGINAL_CAMERA_TWEEN_SPEED
		camera_rect.size = ORIGINAL_GAME_SIZE / camera_zoom

	game_layer.scale = Vector2(camera_zoom, camera_zoom)
	game_layer.position = -camera_rect.position * camera_zoom
	update_original_front_layer()


func update_original_front_layer() -> void:
	if map_front_sprite == null:
		return
	# 对齐 MapMain.render(gameX, gameY, zoom)：
	#   gx = gameX; gy = gameY + bottom;
	#   frontLayer.x = gx * 0.1 + _defaultFrontPos.x;
	#   frontLayer.y = max(_defaultFrontPos.y, gy * 0.1 + _defaultFrontPos.y)。
	# GameStage.render() 传入的是 map.render(-rect.x, -rect.y, zoom)，这里 camera_rect.position 对应 rect.x/y。
	var game_x := -camera_rect.position.x
	var game_y := -camera_rect.position.y
	var yy := (game_y + ORIGINAL_MAP_BOTTOM) * 0.1 + ORIGINAL_XIANSHI_FRONT_DEFAULT_POS.y
	if yy < ORIGINAL_XIANSHI_FRONT_DEFAULT_POS.y:
		yy = ORIGINAL_XIANSHI_FRONT_DEFAULT_POS.y
	map_front_sprite.position = Vector2(game_x * 0.1 + ORIGINAL_XIANSHI_FRONT_DEFAULT_POS.x, yy)
	_update_xianshi_front_optical()


func _build_xianshi_front_layer_children() -> void:
	if map_front_sprite == null:
		return
	# 子元件坐标来自 xianshi.swf / DefineSprite_18 的 PlaceObject2 Matrix。
	# char15 = DefineSprite_15，电线杆；char17 = DefineSprite_17，前景栏杆块。
	_add_xianshi_front_child("front_pole_left", "res://assets/maps/xianshi_layers/front_pole.png", Vector2(-270.95, 0.0))
	_add_xianshi_front_child("front_pole_right", "res://assets/maps/xianshi_layers/front_pole.png", Vector2(247.15, 0.0))
	_add_xianshi_front_child("front_fence_1", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(-138.95, 181.6))
	_add_xianshi_front_child("front_fence_2", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(-201.5, 181.6))
	_add_xianshi_front_child("front_fence_3", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(-13.45, 181.6))
	_add_xianshi_front_child("front_fence_4", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(-76.0, 181.6))
	_add_xianshi_front_child("front_fence_5", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(461.05, 181.6))
	_add_xianshi_front_child("front_fence_6", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(398.5, 181.6))
	_add_xianshi_front_child("front_fence_7", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(586.55, 181.6))
	_add_xianshi_front_child("front_fence_8", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(524.0, 181.6))
	_add_xianshi_front_child("front_fence_9", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(-473.45, 181.6))
	_add_xianshi_front_child("front_fence_10", "res://assets/maps/xianshi_layers/front_fence.png", Vector2(-536.0, 181.6))


func _add_xianshi_front_child(child_name: String, texture_path: String, local_pos: Vector2) -> void:
	var tex: Texture2D = load(texture_path)
	if tex == null:
		push_warning("xianshi front 子元件加载失败：" + texture_path)
		return
	var sp := Sprite2D.new()
	sp.name = child_name
	sp.texture = tex
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = local_pos
	map_front_sprite.add_child(sp)


func _update_xianshi_front_optical() -> void:
	if map_front_sprite == null:
		return
	var areas: Array[Rect2] = []
	areas.append(get_p1_hurt_rect())
	areas.append(get_target_hurt_rect())
	for child in map_front_sprite.get_children():
		if not (child is Sprite2D):
			continue
		var sp := child as Sprite2D
		if sp.texture == null:
			continue
		var child_rect := Rect2(map_front_sprite.position + sp.position, sp.texture.get_size())
		var hit := false
		for area in areas:
			if child_rect.intersects(area, true):
				hit = true
				break
		# 原版 MapMain.renderOptical：d.alpha = checkHitGameSprite(...) ? 0.5 : 1。
		sp.modulate.a = ORIGINAL_FRONT_OPTICAL_ALPHA if hit else 1.0


func _camera_focus_point(node: Variant, fallback: Vector2) -> Vector2:
	var pos := get_node_ground_pos(node, fallback)
	# ManifestFighter 的 Node2D y 是 normalized Sprite 的注册点；原版 camera focus 应接近角色脚底/地面点。
	return Vector2(pos.x, pos.y + ORIGINAL_FIGHTER_FOOT_OFFSET_Y)


func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - camera_rect.position) * camera_zoom


func start_round_intro() -> void:
	round_intro_timer = ROUND_INTRO_TOTAL_TIME
	fight_input_lock_timer = ROUND_INTRO_FIGHT_TIME
	round_intro_phase = -1
	game_time_left = float(DEMO_GAME_TIME_MAX)
	time_over_finished = false
	ko_score_added = false
	if fight_hud != null:
		if fight_hud.has_method("fad_in"):
			fight_hud.call("fad_in", true)
		if fight_hud.has_method("qibar_fad_in"):
			fight_hud.call("qibar_fad_in", true)
		if fight_hud.has_method("show_round_start"):
			fight_hud.call("show_round_start", 1)
		if fight_hud.has_method("set_time_left"):
			fight_hud.call("set_time_left", DEMO_GAME_TIME_MAX, not game_time_enabled)
	print("原版 FightUI.showStart：start label frame=9，fight_in=54，fight=57，complete=87。")


func update_round_intro(delta: float) -> void:
	if fight_input_lock_timer > 0.0:
		fight_input_lock_timer = maxf(0.0, fight_input_lock_timer - delta)
	if round_intro_timer <= 0.0:
		return
	round_intro_timer = maxf(0.0, round_intro_timer - delta)
	var elapsed: float = ROUND_INTRO_TOTAL_TIME - round_intro_timer
	var new_phase: int = 0
	if elapsed >= ROUND_INTRO_FIGHT_TIME:
		new_phase = 2
	elif elapsed >= ROUND_INTRO_FIGHT_IN_TIME:
		new_phase = 1
	else:
		new_phase = 0
	if new_phase != round_intro_phase:
		round_intro_phase = new_phase
		if fight_hud != null:
			if new_phase == 0 and fight_hud.has_method("show_round_start"):
				fight_hud.call("show_round_start", 1)
			elif new_phase == 1 and fight_hud.has_method("show_fight_in"):
				fight_hud.call("show_fight_in")
			elif new_phase == 2 and fight_hud.has_method("show_fight"):
				fight_hud.call("show_fight")
	if round_intro_timer <= 0.0 and fight_hud != null and fight_hud.has_method("hide_center_message"):
		fight_hud.call("hide_center_message")


func update_fight_timer(delta: float) -> void:
	if not game_time_enabled:
		if fight_hud != null and fight_hud.has_method("set_time_left"):
			fight_hud.call("set_time_left", 0, true)
		return
	if ko_finished or time_over_finished or fight_input_lock_timer > 0.0:
		return
	game_time_left = maxf(0.0, game_time_left - delta)
	if fight_hud != null and fight_hud.has_method("set_time_left"):
		fight_hud.call("set_time_left", int(ceil(game_time_left)), false)
	if game_time_left <= 0.0:
		start_time_over_sequence()


func update_ko_sequence(delta: float) -> void:
	if not ko_finished:
		return
	if ko_winner_shown:
		return
	if ko_sequence_timer > 0.0:
		ko_sequence_timer = maxf(0.0, ko_sequence_timer - delta)
		return

	# phase 1 -> phase 2: 原版 500ms 后播放 ko / timeover / drawgame。 
	if ko_anim_phase == 1:
		ko_anim_phase = 2
		if ko_timeover:
			ko_sequence_timer = TIMEOVER_ANIM_TIME
			if fight_hud != null and fight_hud.has_method("show_timeover"):
				fight_hud.call("show_timeover")
		else:
			ko_sequence_timer = KO_ANIM_TIME
			if fight_hud != null and fight_hud.has_method("show_ko"):
				fight_hud.call("show_ko")
			var ko_sound: String = "res://assets/sfx/snd_ko.mp3"
			if _is_currently_bisha_ko():
				ko_sound = "res://assets/sfx/snd_ko_bs.mp3"
			AudioManager.play_sfx(ko_sound, -2.0)
		if fight_hud != null and fight_hud.has_method("qibar_fad_out"):
			fight_hud.call("qibar_fad_out", true)
		return

	# phase 2 -> draw/winner delay: 对应 Event.COMPLETE 后 _playOver=true。
	if ko_anim_phase == 2:
		if ko_draw_game:
			ko_anim_phase = 3
			ko_sequence_timer = DRAWGAME_ANIM_TIME
			if fight_hud != null and fight_hud.has_method("show_drawgame"):
				fight_hud.call("show_drawgame")
			return
		ko_anim_phase = 3
		ko_sequence_timer = WINNER_DELAY_AFTER_TIMEOVER if ko_timeover else WINNER_DELAY_AFTER_KO
		return

	# phase 3 -> winner/done。
	if ko_anim_phase == 3:
		ko_winner_shown = true
		ko_anim_phase = 4
		if ko_draw_game or ko_winner_id == 0:
			if fight_hud != null and fight_hud.has_method("show_drawgame"):
				fight_hud.call("show_drawgame")
			return
		if fight_hud != null and fight_hud.has_method("show_winner"):
			fight_hud.call("show_winner", ko_winner_id, ko_perfect)


func start_time_over_sequence() -> void:
	if ko_finished:
		return
	time_over_finished = true
	ko_finished = true
	ko_timeover = true
	ko_anim_phase = 1
	ko_sequence_timer = 0.0
	ko_winner_shown = false
	var p1_hp_now: float = get_fighter_hp(p1)
	var p2_hp_now: float = get_fighter_hp(p2)
	ko_draw_game = absf(p1_hp_now - p2_hp_now) < 0.01
	ko_winner_id = 0
	ko_perfect = false
	if not ko_draw_game:
		if p1_hp_now > p2_hp_now:
			ko_winner_id = 1
			ko_perfect = p1_hp_now >= get_fighter_hp_max(p1)
		else:
			ko_winner_id = 2
			ko_perfect = p2_hp_now >= get_fighter_hp_max(p2)
	print("TIME OVER: p1_hp=", p1_hp_now, " p2_hp=", p2_hp_now, " winner=", ko_winner_id, " draw=", ko_draw_game)


func _is_currently_bisha_ko() -> bool:
	if p1 != null:
		var a1: String = String(p1.get("current_action"))
		if a1.begins_with("super"):
			return true
	if p2 != null:
		var a2: String = String(p2.get("current_action"))
		if a2.begins_with("super"):
			return true
	return false



func clamp_fighters_to_original_map_bounds() -> void:
	clamp_fighter_to_original_map_bounds(p1)
	clamp_fighter_to_original_map_bounds(p2)


func clamp_fighter_to_original_map_bounds(fighter: Variant) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	if not (fighter is Node2D):
		return
	var node := fighter as Node2D
	var min_x := ORIGINAL_MAP_LEFT + ORIGINAL_FIGHTER_BOUND_MARGIN_X
	var max_x := ORIGINAL_MAP_RIGHT - ORIGINAL_FIGHTER_BOUND_MARGIN_X
	# 对齐原版 line_left / line_right 的效果：到地图边缘后不再继续向外移动。
	# 这样当 camera 已经被 GameCamera 边界夹住时，角色不会继续走出 800x600 可见画面。
	node.position.x = clampf(node.position.x, min_x, max_x)


func handle_p1_input(delta: float) -> void:
	if ko_finished:
		return

	var j_pressed: bool = Input.is_key_pressed(KEY_J)
	var k_pressed: bool = Input.is_key_pressed(KEY_K)
	var l_pressed: bool = Input.is_key_pressed(KEY_L)
	var u_pressed: bool = Input.is_key_pressed(KEY_U)
	var i_pressed: bool = Input.is_key_pressed(KEY_I)
	var t_pressed: bool = ORIGINAL_DEV_KEYS_ENABLED and Input.is_key_pressed(KEY_T)

	var j_just: bool = j_pressed and not prev_j_pressed
	var k_just: bool = k_pressed and not prev_k_pressed
	var l_just: bool = l_pressed and not prev_l_pressed
	var u_just: bool = u_pressed and not prev_u_pressed
	var i_just: bool = i_pressed and not prev_i_pressed
	var t_just: bool = t_pressed and not prev_t_pressed

	prev_j_pressed = j_pressed
	prev_k_pressed = k_pressed
	prev_l_pressed = l_pressed
	prev_u_pressed = u_pressed
	prev_i_pressed = i_pressed
	prev_t_pressed = t_pressed

	if t_just:
		debug_fill_qi_energy()

	# 原版 FighterKeyCtrler.defense() = down。这里只在 S 单独按住时进入防御，避免影响 S+J / S+U / S+I。
	var pure_down_defense: bool = Input.is_key_pressed(KEY_S) and not (j_pressed or u_pressed or i_pressed or k_pressed or l_pressed)
	if p1.current_action == "defend" and not pure_down_defense:
		p1.play_action("defend_recover")
	elif pure_down_defense and p1.can_ground_action():
		p1.play_action("defend")
		return

	# 先处理一次性动作键，避免按住 A/D 时把技能/攻击覆盖成 walk。
	if k_just:
		handle_jump_input()

	if l_just:
		handle_dash_input()

	if j_just:
		handle_attack_input()

	if u_just:
		handle_skill_input()

	if i_just:
		handle_bisha_input()


	# A / D：只在地面空闲时切 walk；攻击/技能/必杀动作中不覆盖当前动画。
	if p1.can_ground_action():
		if Input.is_key_pressed(KEY_A):
			p1.position.x -= move_speed * delta
			clamp_fighter_to_original_map_bounds(p1)
			p1.set_facing(-1)
			if p1.current_action != "walk":
				p1.play_action("walk")
		elif Input.is_key_pressed(KEY_D):
			p1.position.x += move_speed * delta
			clamp_fighter_to_original_map_bounds(p1)
			p1.set_facing(1)
			if p1.current_action != "walk":
				p1.play_action("walk")
		elif p1.current_action != "idle":
			p1.play_action("idle")


func handle_p2_debug_input() -> void:
	if not ORIGINAL_DEV_KEYS_ENABLED:
		return
	var p_pressed: bool = Input.is_key_pressed(KEY_P)
	var p_just: bool = p_pressed and not prev_p_pressed
	prev_p_pressed = p_pressed

	if not p_just:
		return

	if p1 == null or p2 == null:
		return

	if not p2.has_method("play_action"):
		print("P2 test attack skipped: P2 不是 ManifestFighter。")
		return

	if p2.has_method("can_ground_action") and not bool(p2.call("can_ground_action")):
		print("P2 test attack skipped: P2 当前不能地面行动。")
		return

	var p1_pos: Vector2 = get_node_ground_pos(p1, P1_START_POS)
	var p2_pos: Vector2 = get_node_ground_pos(p2, P2_START_POS)
	var face_to_p1: int = 1 if p1_pos.x >= p2_pos.x else -1

	if p2.has_method("set_facing"):
		p2.call("set_facing", face_to_p1)

	p2.call("play_action", "atk1")
	p2_test_attack_has_hit = false
	p2_test_attack_key = ""
	print("P2 test attack: 原版 J/砍1 -> k1atm -> HitVO k1，用于验证 P1 S+J setHurtAction。")


func handle_jump_input() -> void:
	p1.start_jump()


func handle_dash_input() -> void:
	if not p1.can_ground_action():
		return

	p1.play_action("dash")
	p1.position.x += dash_distance * p1.facing
	clamp_fighter_to_original_map_bounds(p1)


func handle_attack_input() -> void:
	var up_pressed: bool = Input.is_key_pressed(KEY_W)
	var down_pressed: bool = Input.is_key_pressed(KEY_S)

	# 空中 J：原版 attackAIR，蓝染对应“跳砍”。
	if p1.in_air:
		p1_air_skill_ready = false
		p1_air_bisha_ready = false
		p1.start_air_attack()
		return

	# 原版“砍技2_CHK”在全局帧 608 同时调用：
	#   setAttack("砍4_QK")
	#   setSkill2("砍技2_1")
	# 因此进入 CHK 且到达原版衔接窗口后：
	#   再按 J 进入 砍4_QK / atk4_extra
	#   再按 W+J 进入 砍技2_1 / attack_skill2_1
	if p1.current_action == "attack_skill2_check" and p1.frame_index >= 11 and p1.frame_index < 18:
		if up_pressed and attack_skill2_1_ready:
			p1.play_action("attack_skill2_1")
			attack_skill2_1_ready = false
			attack_skill2_next_attack_ready = false
			return

		if not up_pressed and not down_pressed and attack_skill2_next_attack_ready:
			p1.play_action("atk4_extra")
			attack_skill2_next_attack_ready = false
			return

	# 地面 S+J：原版 skill1() = down + attack，对应“砍技1”。
	# 注意：砍技1本体是反击准备，真正攻击动作是被打时转入“砍技1_HA”。
	if down_pressed and p1.can_ground_action():
		p1.play_action("attack_skill1")
		return

	# 地面 W+J：原版 skill2() = up + attack，对应“砍技2”。
	if up_pressed and p1.can_ground_action():
		attack_skill2_1_ready = false
		attack_skill2_next_attack_ready = false
		p1.play_action("attack_skill2")
		return

	# 地面 J 连段。窗口按蓝染 mc_023 时间轴 setAttack / endAct 校正。
	if p1.current_action == "atk1" and p1.frame_index >= 7 and p1.frame_index < 13:
		p1.play_action("atk2")
		return

	if p1.current_action == "atk2" and p1.frame_index >= 8 and p1.frame_index < 13:
		p1.play_action("atk3")
		return

	if p1.current_action == "atk3" and p1.frame_index >= 11 and p1.frame_index < 17:
		p1.play_action("atk4")
		return

	if p1.current_action == "atk4_extra" and p1.frame_index >= 8 and p1.frame_index < 14:
		p1.play_action("atk5")
		return

	if p1.can_ground_action():
		p1.play_action("atk1")


func handle_skill_input() -> void:
	var up_pressed: bool = Input.is_key_pressed(KEY_W)
	var down_pressed: bool = Input.is_key_pressed(KEY_S)

	# 空中 U：原版 skillAIR，蓝染对应“跳招”。
	# 跳砍第 9 帧 setSkillAIR 后，即使 jump_attack 还没播完，也允许接空中 U。
	if p1.in_air and (not p1.is_busy() or p1_air_skill_ready):
		p1_air_skill_ready = false
		p1_air_bisha_ready = false
		p1.play_action("air_skill")
		return

	# “砍4_QK”第 8-13 帧原版 setZhao1()，允许接 U → 招1。
	if p1.current_action == "atk4_extra" and p1.frame_index >= 8 and p1.frame_index < 14:
		p1.play_action("skill1")
		return

	if not p1.can_ground_action():
		return

	# 原版 FighterKeyCtrler：
	# U      = zhao1()，对应“招1”
	# S + U  = zhao2()，对应“招2”
	# W + U  = zhao3()，对应“招3”
	# 注意：这里不再手动播放 leihoupao 临时特效，后续要从 XFL 的 addAttacker / hitbox 继续还原。
	if down_pressed:
		p1.play_action("skill2")
	elif up_pressed:
		p1.play_action("skill3")
	else:
		p1.play_action("skill1")


func handle_bisha_input() -> void:
	var up_pressed: bool = Input.is_key_pressed(KEY_W)
	var down_pressed: bool = Input.is_key_pressed(KEY_S)

	# 空中 I：原版 bishaAIR，对应“空中必杀”。
	# 跳砍第 9 帧 setBishaAIR 后，即使 jump_attack 还没播完，也允许接空中 I。
	if p1.in_air and (not p1.is_busy() or p1_air_bisha_ready):
		if not try_use_p1_qi(100.0, "空中必杀 / super_air"):
			return
		p1_air_skill_ready = false
		p1_air_bisha_ready = false
		p1.play_action("super_air")
		return

	if not p1.can_ground_action():
		return

	# 原版 FighterKeyCtrler：
	# I      = bisha()，对应“必杀”，Aizen_1 + XG_bs
	# W + I  = bishaUP()，对应“上必杀”，Aizen_1 + XG_bs
	# S + I  = bishaSUPER()，对应“超必杀”，Aizen_2 + XG_cbs
	if down_pressed:
		if try_use_p1_qi(300.0, "超必杀 / super_special"):
			p1.play_action("super_special")
	elif up_pressed:
		if try_use_p1_qi(100.0, "上必杀 / super_up"):
			p1.play_action("super_up")
	else:
		if try_use_p1_qi(100.0, "普通必杀 / super"):
			p1.play_action("super")


func _on_p1_frame_event(action_name: String, event_data: Dictionary) -> void:
	var relative_frame: int = int(event_data.get("relative_frame", -1))

	for call_data in event_data.get("calls", []):
		var raw_call: Dictionary = call_data
		var semantic: Dictionary = raw_call.get("semantic", {})

		if semantic.is_empty():
			handle_aizen_raw_call_event(action_name, relative_frame, raw_call)
			continue

		handle_aizen_semantic_event(action_name, relative_frame, semantic)




func _nullable_number_to_float(value: Variant, fallback: float = 0.0) -> float:
	if value == null:
		return fallback
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	var text: String = String(value).strip_edges()
	if text == "" or text.to_lower() == "null" or text.to_lower() == "nan":
		return fallback
	return float(text)


func parse_add_attacker_follow_offset(args_raw: String, fallback: Vector2) -> Vector2:
	# 原版 addAttacker params 直接来自 mc_023.xml，例如：
	# addAttacker("bsmc",{x:{followTarget:true,offset:0},y:{followTarget:true,offset:-25},applyG:false})
	# 旧解析器会把 object 参数按逗号切碎，所以这里直接从 args_raw 重新读取 x/y offset。
	return Vector2(
		parse_axis_offset_from_add_attacker_args(args_raw, "x", fallback.x),
		parse_axis_offset_from_add_attacker_args(args_raw, "y", fallback.y)
	)


func parse_axis_offset_from_add_attacker_args(args_raw: String, axis: String, fallback: float) -> float:
	var marker_text: String = axis + ":{"
	var start: int = args_raw.find(marker_text)
	if start < 0:
		return fallback

	var end: int = args_raw.find("}", start)
	if end < 0:
		return fallback

	var block: String = args_raw.substr(start, end - start)
	var offset_marker: String = "offset:"
	var offset_pos: int = block.find(offset_marker)
	if offset_pos < 0:
		return fallback

	var number_start: int = offset_pos + offset_marker.length()
	var number_end: int = block.find(",", number_start)
	if number_end < 0:
		number_end = block.length()

	var value_text: String = block.substr(number_start, number_end - number_start).strip_edges()
	if value_text == "":
		return fallback

	return float(value_text)


func handle_aizen_raw_call_event(action_name: String, relative_frame: int, raw_call: Dictionary) -> void:
	# 原版 XFL 时间轴里 addAttacker 脚本目前保留在 calls 的 raw method 中，
	# 不再只靠 action_name + relative_frame 硬编码兜底。
	# 已确认：
	# - super frame 40 / mc_023 global frame 804: addAttacker("bsmc", {x:followTarget, y:followTarget-25, applyG:false})
	# - skill3 frame 6 / mc_023 global frame 680: addAttacker("zh3mc", {applyG:false})
	var object_name: String = String(raw_call.get("object", ""))
	var method_name: String = String(raw_call.get("method", ""))

	if object_name != "mc_ctrler" or method_name != "addAttacker":
		return

	var args: Array = raw_call.get("args", [])
	if args.is_empty():
		return

	var attacker_name: String = String(args[0])

	if attacker_name == "bsmc":
		var args_raw: String = String(raw_call.get("args_raw", ""))
		var raw_offset: Vector2 = parse_add_attacker_follow_offset(args_raw, BSMC_ORIGINAL_TARGET_OFFSET)
		print("原版 raw addAttacker 触发：bsmc followTarget offset=", raw_offset, " applyG=false action=", action_name, " frame=", relative_frame)
		play_p1_attacker_at_target("bsmc", raw_offset, 1.0)
		active_original_hitbox = "bsmc"
	elif attacker_name == "zh3mc":
		print("原版 raw addAttacker 触发：zh3mc applyG=false matrix=", ZH3MC_MC023_INSTANCE_MATRIX, " action=", action_name, " frame=", relative_frame)
		# 视觉 PNG 仍使用当前 FFDec 导出层的锚点；攻击面继续使用 ZH3ATM_RECT，
		# 该矩形已经由 mc_023 zh3mc Matrix + mc_015 zh3atm Matrix 推导，不手写猜测。
		play_p1_attacker_at_self("zh3mc", Vector2.ZERO, 1.0)
		active_original_hitbox = "zh3mc"


func handle_aizen_semantic_event(action_name: String, relative_frame: int, semantic: Dictionary) -> void:
	var event_type: String = String(semantic.get("type", ""))

	match event_type:
		"super_effect_start":
			var original_face_id: String = String(semantic.get("effect_name", ""))
			var is_super: bool = semantic.get("is_super", false) == true

			print("Bisha start:", original_face_id, " is_super=", is_super, " action=", action_name, " frame=", relative_frame)

			if bisha_effect != null:
				# 原版 EffectCtrler.bisha(target) 的通用光效位置是 target.x, target.y - 50。
				# 当前 BishaEffectPlayer 是 HUD/屏幕层节点，所以必须先在世界坐标中加 -50，再转换到屏幕坐标；
				# 不能在屏幕层直接减 50，否则 camera zoom != 1 时高度会与原版不一致。
				var bisha_target_screen: Vector2 = world_to_screen(p1.position)
				var bisha_current_target_screen: Vector2 = world_to_screen(get_p1_target_ground_pos())
				var bisha_xg_screen: Vector2 = world_to_screen(p1.position + Vector2(0.0, -50.0))
				bisha_effect.play_bisha(is_super, original_face_id, bisha_target_screen, p1.facing, bisha_current_target_screen, bisha_xg_screen)

		"super_effect_end":
			print("Bisha end action=", action_name, " frame=", relative_frame)

			if bisha_effect != null:
				bisha_effect.end_bisha()

		"effect":
			var effect_method: String = String(semantic.get("effect_method", ""))

			if effect_method == "shine":
				play_original_shine_event(action_name, relative_frame, semantic)

			elif effect_method == "dash":
				play_original_dash_effect(action_name, relative_frame)

			else:
				print("原版 effect 事件暂未接入 action=", action_name, " frame=", relative_frame, " method=", effect_method)

		"end_action":
			# 原版 endAct()：_action.clearAction(); actionState=FREEZE; setSteelBody(false)。
			print("原版 endAct 触发 action=", action_name, " frame=", relative_frame)
			if p1 != null and p1.has_method("set_steel_body"):
				p1.set_steel_body(false, false)
			if action_name == "jump_attack" or action_name == "air_skill" or action_name == "super_air":
				if p1 != null and p1.has_method("unlock_original_action"):
					p1.unlock_original_action()

		"return_idle":
			print("原版 idle() 触发 action=", action_name, " frame=", relative_frame)
			p1_air_skill_ready = false
			p1_air_bisha_ready = false
			attack_skill2_1_ready = false
			attack_skill2_next_attack_ready = false
			if p1 != null and p1.has_method("clear_original_timeline_states"):
				p1.clear_original_timeline_states()
			if p1 != null and p1.has_method("return_to_neutral_from_timeline"):
				p1.return_to_neutral_from_timeline()

		"hit_target_check":
			# 原版 FighterMcCtrler.setHitTarget(checker, action)：
			#   _action.hitTargetChecker = checker
			#   _action.hitTarget = action
			# 当前 manifest 里事件字段来自解析器，常见键名是 hit_mc / success_label；
			# 老补丁曾经只读取 checker / target_action，导致必须靠硬编码兜底。
			var checker_name: String = String(semantic.get("checker", semantic.get("hit_mc", "")))
			var target_label: String = String(semantic.get("target_action", semantic.get("success_label", "")))
			var target_action: String = map_original_label_to_action(target_label)
			if target_action == "":
				target_action = target_label

			print("原版 setHitTarget 触发 action=", action_name, " frame=", relative_frame, " checker=", checker_name, " target=", target_label, " -> ", target_action)
			if checker_name != "" and target_action != "":
				pending_hit_target_checker = checker_name
				pending_hit_target_action = target_action
				pending_hit_target_enabled = true

		"set_hurt_action":
			# 原版 FighterMcCtrler.setHurtAction(action)：
			# 被打时不扣血，优先 doAction(hurtAction)。蓝染 S+J 砍技1 在这里转入 砍技1_HA。
			var hurt_label: String = String(semantic.get("target_label", ""))
			var hurt_action: String = map_original_label_to_action(hurt_label)
			if hurt_action == "":
				hurt_action = hurt_label
			print("原版 setHurtAction 触发 action=", action_name, " frame=", relative_frame, " target=", hurt_label, " -> ", hurt_action)
			if hurt_action != "" and p1 != null and p1.has_method("set_original_hurt_action"):
				p1.set_original_hurt_action(hurt_action)

		"add_qi":
			# 原版 FighterMcCtrler.addQi(qi) 直接调用 fighter.addQi(qi)。
			var qi_value: float = float(semantic.get("value", 0.0))
			print("原版 addQi 触发 action=", action_name, " frame=", relative_frame, " value=", qi_value)
			if qi_value > 0.0 and p1 != null and p1.has_method("add_qi"):
				p1.add_qi(qi_value)

		"steel_body":
			# 原版 FighterMcCtrler.setSteelBody(v, isSuper=false)：
			# 进入钢体后被普通攻击命中不打断当前动作，按 doSteelHurt 结算减伤和 energy 消耗。
			var steel_enabled: bool = semantic.get("enabled", false) == true
			var steel_super: bool = semantic.get("is_super", false) == true
			print("原版 setSteelBody 触发 action=", action_name, " frame=", relative_frame, " enabled=", steel_enabled, " super=", steel_super)
			if p1 != null and p1.has_method("set_steel_body"):
				p1.set_steel_body(steel_enabled, steel_super)

		"enable_skill":
			var enable_method: String = String(semantic.get("method", ""))

			if enable_method == "setSkillAIR":
				p1_air_skill_ready = true
				print("原版 setSkillAIR 触发：跳砍后允许接空中 U / 跳招")

			elif enable_method == "setSkill2":
				var skill2_label: String = String(semantic.get("target_label", ""))
				var skill2_action: String = map_original_label_to_action(skill2_label)
				print("原版 setSkill2 触发 action=", action_name, " frame=", relative_frame, " target=", skill2_label, " -> ", skill2_action)
				if skill2_action == "attack_skill2_1":
					attack_skill2_1_ready = true

		"enable_next_attack":
			# 原版 setAttack("砍4_QK")：把下一次 J 的 attack 动作改为 砍4_QK。
			var attack_label: String = String(semantic.get("target_label", ""))
			var attack_action: String = map_original_label_to_action(attack_label)
			print("原版 setAttack 触发 action=", action_name, " frame=", relative_frame, " target=", attack_label, " -> ", attack_action)
			if attack_action == "atk4_extra":
				attack_skill2_next_attack_ready = true

		"enable_super":
			var enable_method_super: String = String(semantic.get("method", ""))
			if enable_method_super == "setBishaAIR":
				p1_air_bisha_ready = true
				print("原版 setBishaAIR 触发：跳砍后允许接空中 I / 空中必杀")

		"teleport_or_move_to_target":
			var offset_x_value: Variant = semantic.get("x", null)
			var offset_y_value: Variant = semantic.get("y", null)
			var auto_turn: bool = semantic.get("auto_turn", false) == true
			move_p1_to_current_target(offset_x_value, offset_y_value, auto_turn)

		"apply_gravity":
			var apply_g: bool = semantic.get("enabled", true) == true
			if p1 != null and p1.has_method("set_apply_gravity_enabled"):
				p1.set_apply_gravity_enabled(apply_g)
			print("原版 isApplyG 触发 action=", action_name, " frame=", relative_frame, " enabled=", apply_g)

		"movement":
			handle_original_movement_event(action_name, relative_frame, semantic)

		"dash_or_stop":
			handle_original_dash_or_stop_event(action_name, relative_frame, semantic)

		"add_attacker":
			var attacker_name: String = String(semantic.get("attacker", ""))
			if attacker_name == "bsmc":
				play_p1_attacker_at_target("bsmc", BSMC_ORIGINAL_TARGET_OFFSET, 1.0)
				active_original_hitbox = "bsmc"
			elif attacker_name == "zh3mc":
				play_p1_attacker_at_self("zh3mc", Vector2.ZERO, 1.0)
				active_original_hitbox = "zh3mc"

		_:
			pass

	# addAttacker 仍在 handle_aizen_raw_call_event() 按原始 XFL raw call 处理；
	# 这里不再用 action_name + relative_frame 硬编码 setHitTarget / setHurtAction / setSkill2。
	# 这些事件已经由上面的 semantic 分支直接读取 manifest 中的原始 XFL 解析字段。


func map_original_label_to_action(label_name: String) -> String:
	if label_name == "上必杀_HIT":
		return "super_up_hit"
	if label_name == "招2_CHK":
		return "skill2_check"
	if label_name == "砍技2_CHK":
		return "attack_skill2_check"
	if label_name == "砍技2_1":
		return "attack_skill2_1"
	if label_name == "砍技1_HA":
		return "attack_skill1_extra"
	return ""


func create_attack_debug_layer() -> void:
	attack_debug_layer = Control.new()
	attack_debug_layer.name = "OriginalAttackBoxDebug"
	attack_debug_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_debug_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	attack_debug_layer.z_index = 80
	add_child(attack_debug_layer)

	attack_debug_box = ColorRect.new()
	attack_debug_box.name = "AttackBox"
	attack_debug_box.color = Color(1.0, 0.0, 0.0, 0.28)
	attack_debug_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_debug_box.visible = false
	attack_debug_layer.add_child(attack_debug_box)

	attack_debug_label = Label.new()
	attack_debug_label.name = "AttackBoxLabel"
	attack_debug_label.add_theme_font_size_override("font_size", 14)
	attack_debug_label.add_theme_color_override("font_color", Color(1, 0.1, 0.1, 1))
	attack_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_debug_label.visible = false
	attack_debug_layer.add_child(attack_debug_label)

	target_hurt_debug_box = ColorRect.new()
	target_hurt_debug_box.name = "TargetHurtBox"
	target_hurt_debug_box.color = Color(0.0, 1.0, 0.2, 0.22)
	target_hurt_debug_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hurt_debug_box.visible = false
	attack_debug_layer.add_child(target_hurt_debug_box)

	target_hurt_debug_label = Label.new()
	target_hurt_debug_label.name = "TargetHurtBoxLabel"
	target_hurt_debug_label.add_theme_font_size_override("font_size", 14)
	target_hurt_debug_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
	target_hurt_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hurt_debug_label.visible = false
	attack_debug_layer.add_child(target_hurt_debug_label)

	p2_attack_debug_box = ColorRect.new()
	p2_attack_debug_box.name = "P2AttackBox"
	p2_attack_debug_box.color = Color(1.0, 0.55, 0.0, 0.30)
	p2_attack_debug_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p2_attack_debug_box.visible = false
	attack_debug_layer.add_child(p2_attack_debug_box)

	p2_attack_debug_label = Label.new()
	p2_attack_debug_label.name = "P2AttackBoxLabel"
	p2_attack_debug_label.add_theme_font_size_override("font_size", 14)
	p2_attack_debug_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.05, 1))
	p2_attack_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p2_attack_debug_label.visible = false
	attack_debug_layer.add_child(p2_attack_debug_label)

	p1_hurt_debug_box = ColorRect.new()
	p1_hurt_debug_box.name = "P1HurtBox"
	p1_hurt_debug_box.color = Color(0.0, 0.7, 1.0, 0.22)
	p1_hurt_debug_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p1_hurt_debug_box.visible = false
	attack_debug_layer.add_child(p1_hurt_debug_box)

	p1_hurt_debug_label = Label.new()
	p1_hurt_debug_label.name = "P1HurtBoxLabel"
	p1_hurt_debug_label.add_theme_font_size_override("font_size", 14)
	p1_hurt_debug_label.add_theme_color_override("font_color", Color(0.25, 0.85, 1, 1))
	p1_hurt_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p1_hurt_debug_label.visible = false
	attack_debug_layer.add_child(p1_hurt_debug_label)


func clear_original_attack_box() -> void:
	active_original_hitbox = ""
	current_attack_world_rect = Rect2()
	current_attack_label = ""
	current_hit_vo_id = ""
	active_attacker_has_hit = false
	active_attack_key = ""
	if attack_debug_box != null:
		attack_debug_box.visible = false
	if attack_debug_label != null:
		attack_debug_label.visible = false


func make_directed_rect(base_pos: Vector2, local_rect: Rect2, direct: int) -> Rect2:
	# 对应原版 FighterAttacker.getCurrentRect():
	# newRect.x = rect.x * direct + _x; if direct < 0: newRect.x -= rect.width; newRect.y = rect.y + _y
	var result := Rect2()
	if direct >= 0:
		result.position.x = base_pos.x + local_rect.position.x
	else:
		result.position.x = base_pos.x - local_rect.position.x - local_rect.size.x
	result.position.y = base_pos.y + local_rect.position.y
	result.size = local_rect.size
	return result


func draw_original_attack_box(rect: Rect2, label_text: String) -> void:
	if not attack_debug_enabled:
		return
	if attack_debug_box == null:
		return

	attack_debug_box.visible = true
	attack_debug_box.position = rect.position
	attack_debug_box.size = rect.size

	if attack_debug_label != null:
		attack_debug_label.visible = true
		attack_debug_label.text = label_text + "  " + str(rect)
		attack_debug_label.position = rect.position + Vector2(0, -20)


func set_current_attack_box(rect: Rect2, label_text: String, hit_vo_id: String, attack_key: String = "") -> void:
	var key: String = attack_key
	if key == "":
		key = label_text + ":" + hit_vo_id

	# 原版同一个攻击动作中不同显示对象名会映射到不同 HitVO。
	# 这里按 attack_key 重置命中标记，避免 k5 命中后 k52 或 bs1 命中后 bs 永远打不出来。
	if key != active_attack_key:
		active_attack_key = key
		active_attacker_has_hit = false

	current_attack_world_rect = rect
	current_attack_label = label_text
	current_hit_vo_id = hit_vo_id
	draw_original_attack_box(rect, label_text + " -> HitVO:" + hit_vo_id)


func hide_current_attack_box_for_empty_frame() -> void:
	current_attack_world_rect = Rect2()
	current_attack_label = ""
	current_hit_vo_id = ""
	if attack_debug_box != null:
		attack_debug_box.visible = false
	if attack_debug_label != null:
		attack_debug_label.visible = false


func clear_target_hurt_box() -> void:
	if target_hurt_debug_box != null:
		target_hurt_debug_box.visible = false
	if target_hurt_debug_label != null:
		target_hurt_debug_label.visible = false


func clear_p2_attack_box() -> void:
	if p2_attack_debug_box != null:
		p2_attack_debug_box.visible = false
	if p2_attack_debug_label != null:
		p2_attack_debug_label.visible = false
	p2_test_attack_key = ""
	p2_test_attack_has_hit = false


func clear_p1_hurt_box() -> void:
	if p1_hurt_debug_box != null:
		p1_hurt_debug_box.visible = false
	if p1_hurt_debug_label != null:
		p1_hurt_debug_label.visible = false


func update_target_hurt_box() -> void:
	if not attack_debug_enabled:
		clear_target_hurt_box()
		return
	if target_hurt_debug_box == null:
		return
	if p2 == null:
		clear_target_hurt_box()
		return

	var rect := get_target_hurt_rect()
	target_hurt_debug_box.visible = true
	target_hurt_debug_box.position = rect.position
	target_hurt_debug_box.size = rect.size

	if target_hurt_debug_label != null:
		target_hurt_debug_label.visible = true
		target_hurt_debug_label.text = "p2 / bdmn  " + str(rect)
		target_hurt_debug_label.position = rect.position + Vector2(0, -20)


func update_p1_hurt_box() -> void:
	if not attack_debug_enabled:
		clear_p1_hurt_box()
		return
	if p1_hurt_debug_box == null:
		return
	if p1 == null:
		clear_p1_hurt_box()
		return

	var rect: Rect2 = get_p1_hurt_rect()
	p1_hurt_debug_box.visible = true
	p1_hurt_debug_box.position = rect.position
	p1_hurt_debug_box.size = rect.size

	if p1_hurt_debug_label != null:
		p1_hurt_debug_label.visible = true
		p1_hurt_debug_label.text = "p1 / bdmn  " + str(rect)
		p1_hurt_debug_label.position = rect.position + Vector2(0, -20)


func get_main_attack_hit_window(action_name: String, frame: int) -> Dictionary:
	# 全局帧到相对帧换算：
	# 砍1 start=165, k1atm=167-168 -> relative 2-3。
	# 砍2 start=186, k2atm=188-189 -> relative 2-3。
	# 砍3 start=204, k3atm=210-212 -> relative 6-8。
	# 砍4_QK start=240, k4atm=241-243 -> relative 1-3。
	# 砍5 start=264, k5atm=269-273, k52atm=276-278 -> relative 5-9, 12-14。
	if action_name == "atk1" and frame >= 2 and frame <= 3:
		return {"rect": K1ATM_RECT, "label": "atk1 / k1atm", "hit": "k1", "key": "atk1:k1"}

	if action_name == "atk2" and frame >= 2 and frame <= 3:
		return {"rect": K2ATM_RECT, "label": "atk2 / k2atm", "hit": "k2", "key": "atk2:k2"}

	if action_name == "atk3" and frame >= 6 and frame <= 8:
		return {"rect": K3ATM_RECT, "label": "atk3 / k3atm", "hit": "k3", "key": "atk3:k3"}

	if action_name == "atk4_extra":
		if frame >= 1 and frame <= 2:
			return {"rect": K4ATM_RECT_A, "label": "atk4_extra / k4atm", "hit": "k4", "key": "atk4_extra:k4"}
		if frame == 3:
			return {"rect": K4ATM_RECT_B, "label": "atk4_extra / k4atm", "hit": "k4", "key": "atk4_extra:k4"}

	if action_name == "atk5":
		if frame >= 5 and frame <= 7:
			return {"rect": K5ATM_RECT_A, "label": "atk5 / k5atm", "hit": "k5", "key": "atk5:k5"}
		if frame >= 8 and frame <= 9:
			return {"rect": K5ATM_RECT_B, "label": "atk5 / k5atm", "hit": "k5", "key": "atk5:k5"}
		if frame >= 12 and frame <= 14:
			return {"rect": K52ATM_RECT, "label": "atk5 / k52atm", "hit": "k52", "key": "atk5:k52"}

	# 空中 J / 跳砍 start=78，tkatm global=81-84 -> relative 3-6。
	if action_name == "jump_attack":
		if frame >= 3 and frame <= 4:
			return {"rect": TKATM_RECT_A, "label": "jump_attack / tkatm", "hit": "tk", "key": "jump_attack:tk"}
		if frame >= 5 and frame <= 6:
			return {"rect": TKATM_RECT_B, "label": "jump_attack / tkatm", "hit": "tk", "key": "jump_attack:tk"}

	# 空中 U / 跳招 start=103，tzatm global=118-127 -> relative 15-24。
	if action_name == "air_skill":
		if frame >= 15 and frame <= 16:
			return {"rect": TZATM_RECT_A, "label": "air_skill / tzatm", "hit": "tz", "key": "air_skill:tz"}
		if frame >= 17 and frame <= 18:
			return {"rect": TZATM_RECT_B, "label": "air_skill / tzatm", "hit": "tz", "key": "air_skill:tz"}
		if frame >= 19 and frame <= 24:
			return {"rect": TZATM_RECT_C, "label": "air_skill / tzatm", "hit": "tz", "key": "air_skill:tz"}

	# 空中 I / 空中必杀 start=1126，kbsatm global=1148-1150 -> relative 22-24。
	if action_name == "super_air" and frame >= 22 and frame <= 24:
		return {"rect": KBSATM_RECT, "label": "super_air / kbsatm", "hit": "kbs", "key": "super_air:kbs"}

	# W+I / 上必杀 start=877：sbs1atm global=921-923 -> relative 44-46。
	# 第 48 帧 justHitToPlay("sbs1", "上必杀_HIT") 会根据这个命中跳入 super_up_hit。
	if action_name == "super_up" and frame >= 44 and frame <= 46:
		return {"rect": SBS1ATM_RECT_A, "label": "super_up / sbs1atm", "hit": "sbs1", "key": "super_up:sbs1"}

	# 上必杀_HIT start=946，多段瞬移斩。
	if action_name == "super_up_hit":
		if frame >= 4 and frame <= 6:
			return {"rect": SBS1ATM_RECT_B, "label": "super_up_hit / sbs1atm", "hit": "sbs1", "key": "super_up_hit:sbs1a"}
		if frame >= 16 and frame <= 18:
			return {"rect": SBS1ATM_RECT_C, "label": "super_up_hit / sbs1atm", "hit": "sbs1", "key": "super_up_hit:sbs1b"}
		if frame >= 29 and frame <= 31:
			return {"rect": SBS2ATM_RECT, "label": "super_up_hit / sbs2atm", "hit": "sbs2", "key": "super_up_hit:sbs2"}
		if frame >= 46 and frame <= 48:
			return {"rect": SBS3ATM_RECT, "label": "super_up_hit / sbs3atm", "hit": "sbs3", "key": "super_up_hit:sbs3"}
		if frame >= 58 and frame <= 60:
			return {"rect": SBS1ATM_RECT_D, "label": "super_up_hit / sbs1atm", "hit": "sbs1", "key": "super_up_hit:sbs1c"}
		if frame >= 76 and frame <= 78:
			return {"rect": SBS4ATM_RECT_A, "label": "super_up_hit / sbs4atm", "hit": "sbs4", "key": "super_up_hit:sbs4a"}
		if frame >= 95 and frame <= 97:
			return {"rect": SBS4ATM_RECT_B, "label": "super_up_hit / sbs4atm", "hit": "sbs4", "key": "super_up_hit:sbs4b"}
		if frame == 120:
			return {"rect": SBSATM_RECT_A, "label": "super_up_hit / sbsatm", "hit": "sbs", "key": "super_up_hit:sbs_a"}
		if frame == 121:
			return {"rect": SBSATM_RECT_B, "label": "super_up_hit / sbsatm", "hit": "sbs", "key": "super_up_hit:sbs_b"}
		if frame == 122:
			return {"rect": SBSATM_RECT_C, "label": "super_up_hit / sbsatm", "hit": "sbs", "key": "super_up_hit:sbs_c"}

	# S+I / 超必杀 start=1197：cbs2atm global=1247-1375, cbsatm global=1376-1379。
	# cbs2 是长时间持续攻击面；这里按 10 帧一个 key 允许多段命中，避免只命中一次。
	if action_name == "super_special":
		if frame >= 50 and frame <= 178:
			var cbs2_tick: int = int(floor(float(frame - 50) / 10.0))
			return {"rect": CBS2ATM_RECT, "label": "super_special / cbs2atm", "hit": "cbs2", "key": "super_special:cbs2:" + str(cbs2_tick)}
		if frame >= 179 and frame <= 182:
			return {"rect": CBSATM_RECT, "label": "super_special / cbsatm", "hit": "cbs", "key": "super_special:cbs"}

	# 招1 start=506，zh1atm global=511/513/515/517 -> relative 5-12。
	if action_name == "skill1":
		if frame >= 5 and frame <= 6:
			return {"rect": ZH1ATM_RECT_A, "label": "skill1 / zh1atm", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 7 and frame <= 8:
			return {"rect": ZH1ATM_RECT_B, "label": "skill1 / zh1atm", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 9 and frame <= 10:
			return {"rect": ZH1ATM_RECT_C, "label": "skill1 / zh1atm", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 11 and frame <= 12:
			return {"rect": ZH1ATM_RECT_D, "label": "skill1 / zh1atm", "hit": "zh1", "key": "skill1:zh1"}

	# 招2_CHK start=362，zh2atm global=362-367 -> relative 0-5。
	if action_name == "skill2_check" and frame >= 0 and frame <= 5:
		return {"rect": ZH2ATM_RECT, "label": "skill2_check / zh2atm", "hit": "zh2", "key": "skill2_check:zh2"}

	# 砍技1_HA start=448，kj1atm global=458-460 -> relative 10-12。
	if action_name == "attack_skill1_extra" and frame >= 10 and frame <= 12:
		return {"rect": KJ1ATM_RECT, "label": "attack_skill1_extra / kj1atm", "hit": "kj1", "key": "attack_skill1_extra:kj1"}

	# 砍技2_CHK start=597，kj21atm global=599-601 -> relative 2-4。
	if action_name == "attack_skill2_check" and frame >= 2 and frame <= 4:
		return {"rect": KJ21ATM_RECT, "label": "attack_skill2_check / kj21atm", "hit": "kj21", "key": "attack_skill2_check:kj21"}

	# 砍技2_1 start=626，kj2atm global=636-638 -> relative 10-12。
	if action_name == "attack_skill2_1" and frame >= 10 and frame <= 12:
		return {"rect": KJ2ATM_RECT, "label": "attack_skill2_1 / kj2atm", "hit": "kj2", "key": "attack_skill2_1:kj2"}

	return {}


func update_main_attack_box() -> bool:
	if p1 == null:
		return false

	var data: Dictionary = get_main_attack_hit_window(p1.current_action, p1.frame_index)
	if data.is_empty():
		return false

	var local_rect: Rect2 = data.get("rect", Rect2())
	var label_text: String = String(data.get("label", ""))
	var hit_vo_id: String = String(data.get("hit", ""))
	var attack_key: String = String(data.get("key", ""))
	var world_rect: Rect2 = make_directed_rect(p1.position, local_rect, p1.facing)
	active_original_hitbox = "main_attack"
	set_current_attack_box(world_rect, label_text, hit_vo_id, attack_key)
	return true


func get_hit_target_checker_rect(checker_name: String) -> Rect2:
	if checker_name == "kj2_chkm":
		return make_directed_rect(p1.position, KJ2_CHKM_RECT, p1.facing)
	if checker_name == "zh2_chkm":
		return make_directed_rect(p1.position, ZH2_CHKM_RECT, p1.facing)
	return Rect2()


func update_pending_hit_target_check() -> void:
	if not pending_hit_target_enabled:
		return
	if p1 == null or p2 == null:
		return

	# setHitTarget 只在对应原动作持续期间生效。
	var expected_action: String = ""
	if pending_hit_target_checker == "kj2_chkm":
		expected_action = "attack_skill2"
	elif pending_hit_target_checker == "zh2_chkm":
		expected_action = "skill2"

	if expected_action != "" and p1.current_action != expected_action:
		pending_hit_target_enabled = false
		pending_hit_target_checker = ""
		pending_hit_target_action = ""
		return

	var checker_rect: Rect2 = get_hit_target_checker_rect(pending_hit_target_checker)
	if checker_rect.size == Vector2.ZERO:
		return

	if attack_debug_enabled:
		draw_original_attack_box(checker_rect, "CHECK " + pending_hit_target_checker + " -> " + pending_hit_target_action)

	var hurt_rect: Rect2 = get_target_hurt_rect()
	if not checker_rect.intersects(hurt_rect, true):
		return

	print("原版 setHitTarget 命中：", pending_hit_target_checker, " -> ", pending_hit_target_action)
	pending_hit_target_enabled = false
	pending_hit_target_checker = ""
	var next_action: String = pending_hit_target_action
	pending_hit_target_action = ""
	p1.play_action(next_action)


func update_original_attack_box() -> void:
	if update_main_attack_box():
		return

	if active_original_hitbox == "":
		hide_current_attack_box_for_empty_frame()
		return

	if active_original_hitbox == "main_attack":
		clear_original_attack_box()
		return

	if p1_effect == null or not p1_effect.playing:
		clear_original_attack_box()
		return

	if active_original_hitbox == "bsmc":
		if p1_effect.current_effect != "bsmc":
			clear_original_attack_box()
			return

		# mc_021：第 2-48 帧是 bs1atm，第 49-52 帧是 bsatm；其他帧没有攻击面。
		# Godot frame_index 从 0 开始，这里直接按导出的 MovieClip 帧号范围做调试。
		var local_rect: Rect2
		var label_text := ""
		var hit_vo_id := ""

		if p1_effect.frame_index >= 2 and p1_effect.frame_index <= 48:
			local_rect = BS1ATM_RECT
			label_text = "bsmc / bs1atm"
			hit_vo_id = "bs1"
		elif p1_effect.frame_index >= 49 and p1_effect.frame_index <= 52:
			local_rect = BSATM_RECT
			label_text = "bsmc / bsatm"
			hit_vo_id = "bs"
		else:
			hide_current_attack_box_for_empty_frame()
			return

		var attacker_origin: Vector2 = active_attacker_original_origin
		var world_rect := make_directed_rect(attacker_origin, local_rect, active_attacker_facing)
		set_current_attack_box(world_rect, label_text, hit_vo_id, "bsmc:" + hit_vo_id)
		return

	if active_original_hitbox == "zh3mc":
		if p1_effect.current_effect != "zh3mc":
			clear_original_attack_box()
			return

		# mc_015 内部 zh3atm：根据 main timeline zh3mc Matrix(tx=28.15, ty=-3466.3)
		# 与内部 mc_024 Matrix 推导出的世界局部矩形。它非常高，这是原版 AI/攻击面，不等于视觉贴图大小。
		var world_rect := make_directed_rect(active_attacker_original_origin, ZH3ATM_RECT, active_attacker_facing)
		set_current_attack_box(world_rect, "zh3mc / zh3atm", "zh3", "zh3mc:zh3")
		return


func get_fighter_hp(node) -> float:
	if node != null:
		var v: Variant = node.get("hp")
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return float(v)
	return 1000.0


func get_fighter_hp_max(node) -> float:
	if node != null:
		var v: Variant = node.get("hp_max")
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return float(v)
	return 1000.0


func update_hp_ui() -> void:
	var p1_hp: float = get_fighter_hp(p1)
	var p1_max: float = maxf(1.0, get_fighter_hp_max(p1))
	var p2_hp: float = get_fighter_hp(p2)
	var p2_max: float = maxf(1.0, get_fighter_hp_max(p2))

	if p1_hp_bar != null:
		var p1_ratio: float = clampf(p1_hp / p1_max, 0.0, 1.0)
		p1_hp_bar.size.x = 260.0 * p1_ratio
	if p2_hp_bar != null:
		var p2_ratio: float = clampf(p2_hp / p2_max, 0.0, 1.0)
		var w: float = 260.0 * p2_ratio
		p2_hp_bar.size.x = w
		p2_hp_bar.position.x = 780.0 - w

	if p1_hp_label != null:
		p1_hp_label.text = "P1 HP " + str(int(p1_hp)) + " / " + str(int(p1_max))
	if p2_hp_label != null:
		p2_hp_label.text = "P2 HP " + str(int(p2_hp)) + " / " + str(int(p2_max))


func get_node_facing(node) -> int:
	if node == null:
		return -p1.facing if p1 != null else -1

	if node is Node2D:
		# ManifestFighter.gd 有 facing 变量；placeholder label 没有。
		var v: Variant = (node as Node2D).get("facing")
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return 1 if int(v) >= 0 else -1

	# P2 默认面向 P1。
	return -p1.facing if p1 != null else -1


func get_node_ground_pos(node, fallback_pos: Vector2) -> Vector2:
	if node != null:
		if node is Node2D:
			return (node as Node2D).position
		if node is Control and (node as Control).has_meta("ground_pos"):
			return (node as Control).get_meta("ground_pos")
	return fallback_pos


func get_p1_hurt_rect() -> Rect2:
	var target_pos: Vector2 = get_node_ground_pos(p1, P1_START_POS)
	var target_direct: int = get_node_facing(p1)
	return make_directed_rect(target_pos, BDMN_DEFAULT_HURT_RECT, target_direct)


func get_target_hurt_rect() -> Rect2:
	var target_pos: Vector2 = get_node_ground_pos(p2, P2_START_POS)
	var target_direct: int = get_node_facing(p2)
	return make_directed_rect(target_pos, BDMN_DEFAULT_HURT_RECT, target_direct)


func draw_p2_attack_box(rect: Rect2, label_text: String) -> void:
	if not attack_debug_enabled:
		return
	if p2_attack_debug_box == null:
		return

	p2_attack_debug_box.visible = true
	p2_attack_debug_box.position = rect.position
	p2_attack_debug_box.size = rect.size

	if p2_attack_debug_label != null:
		p2_attack_debug_label.visible = true
		p2_attack_debug_label.text = label_text + "  " + str(rect)
		p2_attack_debug_label.position = rect.position + Vector2(0, -20)


func update_p2_test_attack_box() -> void:
	if p2 == null or p1 == null:
		clear_p2_attack_box()
		return

	if not p2.has_method("play_action"):
		clear_p2_attack_box()
		return

	var action_name: String = String(p2.get("current_action"))
	var frame: int = int(p2.get("frame_index"))

	# 当前只接 P2 测试 J 的原版砍1窗口：atk1 第 2-3 帧，k1atm -> HitVO k1。
	if action_name != "atk1" or frame < 2 or frame > 3:
		if action_name != "atk1":
			clear_p2_attack_box()
		return

	var key: String = "p2:atk1:k1"
	if key != p2_test_attack_key:
		p2_test_attack_key = key
		p2_test_attack_has_hit = false

	var p2_pos: Vector2 = get_node_ground_pos(p2, P2_START_POS)
	var p2_direct: int = get_node_facing(p2)
	var attack_rect: Rect2 = make_directed_rect(p2_pos, K1ATM_RECT, p2_direct)
	draw_p2_attack_box(attack_rect, "P2 atk1 / k1atm -> HitVO:k1")

	if p2_test_attack_has_hit:
		return

	var p1_hurt_rect: Rect2 = get_p1_hurt_rect()
	if not attack_rect.intersects(p1_hurt_rect, true):
		return

	p2_test_attack_has_hit = true
	var hit_vo: Dictionary = AIZEN_HIT_VO.get("k1", {})
	print("P2 HIT: atk1 / k1atm -> p1 bdmn; HitVO=k1 data=", hit_vo, " attack=", attack_rect, " hurt=", p1_hurt_rect)

	var hit_result: Dictionary = {}
	if p1 != null and p1.has_method("apply_original_hit"):
		hit_result = p1.apply_original_hit(hit_vo, p2_direct)
	var old_rect: Rect2 = current_attack_world_rect
	current_attack_world_rect = attack_rect
	after_p2_hit_target(hit_vo, hit_result)
	current_attack_world_rect = old_rect


func check_active_hit_target() -> void:
	if active_original_hitbox == "":
		return
	if active_attacker_has_hit:
		return
	if current_attack_world_rect.size == Vector2.ZERO:
		return
	if p2 == null:
		return

	var hurt_rect := get_target_hurt_rect()
	if not current_attack_world_rect.intersects(hurt_rect, true):
		return

	active_attacker_has_hit = true
	p1_last_hit_vo_id = current_hit_vo_id
	p1_last_hit_action = String(p1.get("current_action")) if p1 != null else ""
	var hit_vo: Dictionary = AIZEN_HIT_VO.get(current_hit_vo_id, {})
	print("HIT: ", current_attack_label, " -> p2 bdmn; HitVO=", current_hit_vo_id,
		" data=", hit_vo, " attack=", current_attack_world_rect, " hurt=", hurt_rect)

	# 对应原版流程：target.beHit(hitVO, hitRect)，attacker.hit(hitVO, target)。
	# 当前先实现核心：伤害、hurtType、hitx/hity、hurtTime。防御、连击计数、得分、特效仍待接。
	var hit_result: Dictionary = {}
	if p2 != null and p2.has_method("apply_original_hit"):
		hit_result = p2.apply_original_hit(hit_vo, p1.facing)
	after_p1_hit_target(hit_vo, hit_result)


func get_node_float_property(node, property_name: String, fallback: float) -> float:
	if node != null:
		var v: Variant = node.get(property_name)
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return float(v)
	return fallback


func set_node_float_property(node, property_name: String, value: float) -> void:
	if node != null and (node.has_method("add_qi") or node.has_method("use_qi")):
		node.set(property_name, value)


func try_use_p1_qi(cost: float, label_text: String) -> bool:
	if p1 == null or not p1.has_method("use_qi"):
		return true
	if p1.call("use_qi", cost):
		print("原版必杀气消耗：", label_text, " cost=", cost, " qi=", get_node_float_property(p1, "qi", 0.0))
		return true
	print("气不足，不能释放 ", label_text, "；需要 ", cost, "，当前 qi=", get_node_float_property(p1, "qi", 0.0), "。按 T 可临时充满气用于测试。")
	return false


func debug_fill_qi_energy() -> void:
	if not ORIGINAL_DEV_KEYS_ENABLED:
		return
	if p1 != null:
		set_node_float_property(p1, "qi", 300.0)
		set_node_float_property(p1, "fzqi", 100.0)
		set_node_float_property(p1, "energy", 100.0)
	if p2 != null:
		set_node_float_property(p2, "qi", 300.0)
		set_node_float_property(p2, "fzqi", 100.0)
		set_node_float_property(p2, "energy", 100.0)


func is_bisha_hitvo(hit_vo: Dictionary) -> bool:
	var hit_id: String = String(hit_vo.get("id", ""))
	return hit_id in ["bs", "bs1", "sbs", "sbs1", "sbs2", "sbs3", "sbs4", "cbs", "cbs2", "kbs"]


func add_qi_on_hit(attacker, target, hit_vo: Dictionary) -> void:
	var power: float = float(hit_vo.get("power", 0.0))
	if attacker != null and attacker.has_method("add_qi") and not is_bisha_hitvo(hit_vo):
		attacker.call("add_qi", minf(QI_HIT_MAX, power * 0.16))
	if target != null and target.has_method("add_qi"):
		target.call("add_qi", minf(QI_HURT_MAX, power * 0.085))


func add_score_by_hit(hit_vo: Dictionary, current_hits: int) -> int:
	# 对应 GameLogic.addScoreByHitTarget 的简化复刻：基础分=power，必杀翻倍，破防/击飞加分，连击加成。
	var base_score: int = int(hit_vo.get("power", 0))
	var score: int = base_score
	if is_bisha_hitvo(hit_vo):
		score = base_score * 2
	if hit_vo.get("isBreakDef", false) == true:
		score += 200
	if int(hit_vo.get("hurtType", 0)) == 1:
		score += 200
	if current_hits < 4:
		score += current_hits * 50
	else:
		score += current_hits * 100
	return score


func after_p1_hit_target(hit_vo: Dictionary, hit_result: Dictionary) -> void:
	var result: String = String(hit_result.get("result", ""))
	play_original_hit_feedback(hit_vo, current_attack_world_rect, result, p1.facing)
	if result == "dead" or result == "counter" or result == "defense" or result == "steel" or result == "ignored":
		return
	add_qi_on_hit(p1, p2, hit_vo)
	p1_combo_count += 1
	p1_combo_timer = COMBO_RESET_TIME
	p2_combo_count = 0
	p2_combo_timer = 0.0
	p1_score += add_score_by_hit(hit_vo, p1_combo_count)


func after_p2_hit_target(hit_vo: Dictionary, hit_result: Dictionary) -> void:
	var result: String = String(hit_result.get("result", ""))
	var p2_face: int = int(p2.get("facing")) if p2 != null else -1
	play_original_hit_feedback(hit_vo, current_attack_world_rect, result, p2_face)
	if result == "dead" or result == "counter" or result == "defense" or result == "steel" or result == "ignored":
		return
	add_qi_on_hit(p2, p1, hit_vo)
	p2_combo_count += 1
	p2_combo_timer = COMBO_RESET_TIME
	p1_combo_count = 0
	p1_combo_timer = 0.0
	p2_score += add_score_by_hit(hit_vo, p2_combo_count)


func play_original_hit_feedback(hit_vo: Dictionary, hit_rect: Rect2, result: String, facing: int) -> void:
	if hit_rect.size == Vector2.ZERO:
		hit_rect = Rect2(get_node_ground_pos(p2, P2_START_POS) - Vector2(20, 60), Vector2(40, 80))

	if result == "defense":
		if common_effects != null:
			common_effects.play_defense_effect(hit_vo, hit_rect, facing)
		flash_shine(Color(1, 1, 1, 0.12), 0.10)
		start_original_shake(0.0, 2.0, 0.08)
		print("原版 doDefenseEffect: hitType=", hit_vo.get("hitType", 0), " rect=", hit_rect)
		return

	if result == "steel":
		# 原版 EffectCtrler.doSteelHitEffect(hitvo, hitRect, target)：
		#   KAN / KAN_HEAVY -> steel_hit_kan  -> XG_kan
		#   DA  / DA_HEAVY  -> steel_hit_qdj  -> XG_qdj
		#   其它 hitType    -> steel_hit_mfdj -> XG_mfdj
		# EffectModel.initSteelHitEffect：sound=snd_hit_steel, freeze=400, blendMode=ADD, shine alpha=0.2, randRotate=true。
		if common_effects != null and common_effects.has_method("play_steel_hit_effect"):
			common_effects.play_steel_hit_effect(hit_vo, hit_rect, facing)
		flash_shine(Color(1, 1, 1, 0.20), 0.12)
		# 原版 freeze(400) 会转成 400/1000*FPS_GAME 帧；当前 Godot hit_stop_timer 以秒计，先严格按 0.40s 对齐。
		hit_stop_timer = maxf(hit_stop_timer, 0.40)
		print("原版 doSteelHitEffect: hitType=", hit_vo.get("hitType", 0), " rect=", hit_rect)
		return

	if result == "break_defense":
		if common_effects != null:
			common_effects.play_break_defense(hit_rect, facing)
		flash_shine(Color(1, 1, 1, 0.22), 0.18)
		start_original_shake(6.0, 0.0, 0.28)
		hit_stop_timer = maxf(hit_stop_timer, 0.10)
		print("原版 break_def: rect=", hit_rect)
		return

	if result == "counter" or result == "dead":
		return

	if common_effects != null:
		common_effects.play_hit_effect(hit_vo, hit_rect, facing)

	var hit_type: int = int(hit_vo.get("hitType", 0))
	if hit_type in [3, 5, 6, 7, 8, 9]:
		flash_shine(Color(1, 1, 1, 0.18), 0.14)
		start_original_shake(0.0, 6.0, 0.22)
		hit_stop_timer = maxf(hit_stop_timer, 0.08)
	else:
		hit_stop_timer = maxf(hit_stop_timer, 0.035)


func flash_shine(color: Color, duration: float) -> void:
	if shine_overlay == null:
		return
	shine_overlay.color = color
	shine_alpha = color.a
	shine_overlay.set_meta("duration", duration)


func start_original_shake(pow_x: float, pow_y: float, duration: float) -> void:
	shake_timer = maxf(shake_timer, duration)
	shake_power = Vector2(pow_x, pow_y)


func update_original_visual_feedback(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer = maxf(0.0, shake_timer - delta)
		var sx: float = 0.0
		var sy: float = 0.0
		if shake_power.x != 0.0:
			sx = sin(Time.get_ticks_msec() * 0.07) * shake_power.x
		if shake_power.y != 0.0:
			sy = sin(Time.get_ticks_msec() * 0.09) * shake_power.y
		position = Vector2(sx, sy)
	else:
		position = Vector2.ZERO

	if shine_overlay != null and shine_overlay.color.a > 0.0:
		var dur: float = float(shine_overlay.get_meta("duration", 0.12))
		var lose: float = delta / maxf(0.01, dur)
		var c: Color = shine_overlay.color
		c.a = maxf(0.0, c.a - lose)
		shine_overlay.color = c


func update_combo_timers(delta: float) -> void:
	if p1_combo_timer > 0.0:
		p1_combo_timer = maxf(0.0, p1_combo_timer - delta)
		if p1_combo_timer <= 0.0:
			p1_combo_count = 0
	if p2_combo_timer > 0.0:
		p2_combo_timer = maxf(0.0, p2_combo_timer - delta)
		if p2_combo_timer <= 0.0:
			p2_combo_count = 0


func update_bar(bar: ColorRect, right_aligned_x: float, full_width: float, ratio: float, right_aligned: bool) -> void:
	if bar == null:
		return
	var width: float = full_width * clampf(ratio, 0.0, 1.0)
	bar.size.x = width
	if right_aligned:
		bar.position.x = right_aligned_x + full_width - width


func update_resource_ui() -> void:
	if fight_hud != null and fight_hud.has_method("set_camera_state"):
		fight_hud.call("set_camera_state", camera_rect, camera_zoom)
	if fight_hud != null and fight_hud.has_method("update_state"):
		fight_hud.call("update_state", p1, p2, p1_score, p2_score, p1_combo_count, p2_combo_count)
	if fight_hud != null and fight_hud.has_method("set_time_left"):
		fight_hud.call("set_time_left", int(ceil(game_time_left)), not game_time_enabled)
	var p1_qi: float = get_node_float_property(p1, "qi", 0.0)
	var p1_qi_max: float = maxf(1.0, get_node_float_property(p1, "qi_max", 300.0))
	var p2_qi: float = get_node_float_property(p2, "qi", 0.0)
	var p2_qi_max: float = maxf(1.0, get_node_float_property(p2, "qi_max", 300.0))
	var p1_energy: float = get_node_float_property(p1, "energy", 100.0)
	var p1_energy_max: float = maxf(1.0, get_node_float_property(p1, "energy_max", 100.0))
	var p2_energy: float = get_node_float_property(p2, "energy", 100.0)
	var p2_energy_max: float = maxf(1.0, get_node_float_property(p2, "energy_max", 100.0))

	update_bar(p1_qi_bar, 20.0, 260.0, p1_qi / p1_qi_max, false)
	update_bar(p1_energy_bar, 20.0, 260.0, p1_energy / p1_energy_max, false)
	update_bar(p2_qi_bar, 520.0, 260.0, p2_qi / p2_qi_max, true)
	update_bar(p2_energy_bar, 520.0, 260.0, p2_energy / p2_energy_max, true)

	if p1_qi_label != null:
		p1_qi_label.text = "P1 QI " + str(int(p1_qi)) + "/" + str(int(p1_qi_max)) + "  EN " + str(int(p1_energy)) + "/" + str(int(p1_energy_max)) + "  SCORE " + str(p1_score)
	if p2_qi_label != null:
		p2_qi_label.text = "P2 SCORE " + str(p2_score) + "  QI " + str(int(p2_qi)) + "/" + str(int(p2_qi_max)) + "  EN " + str(int(p2_energy)) + "/" + str(int(p2_energy_max))
	if p1_combo_label != null:
		p1_combo_label.visible = p1_combo_count >= 2
		p1_combo_label.text = str(p1_combo_count) + " HIT"
	if p2_combo_label != null:
		p2_combo_label.visible = p2_combo_count >= 2
		p2_combo_label.text = str(p2_combo_count) + " HIT"



func add_original_ko_score() -> void:
	# 对应 GameLogic.addScoreByKO：必杀 KO +2000；满血胜利 +20000，否则 +3000。
	if ko_score_added:
		return
	ko_score_added = true
	if ko_draw_game or ko_winner_id == 0:
		return
	var bonus: int = 0
	var last_hit_id: String = p1_last_hit_vo_id if ko_winner_id == 1 else p2_last_hit_vo_id
	if AIZEN_HIT_VO.has(last_hit_id) and is_bisha_hitvo(AIZEN_HIT_VO[last_hit_id]):
		bonus += 2000
	bonus += 20000 if ko_perfect else 3000
	if ko_winner_id == 1:
		p1_score += bonus
	else:
		p2_score += bonus
	print("原版 KO score bonus winner=", ko_winner_id, " bonus=", bonus)

func check_ko_state() -> void:
	if ko_finished:
		return
	var p1_hp_now: float = get_fighter_hp(p1)
	var p2_hp_now: float = get_fighter_hp(p2)
	if p1_hp_now > 0.0 and p2_hp_now > 0.0:
		return
	ko_finished = true
	ko_timeover = false
	ko_draw_game = false
	ko_winner_shown = false
	ko_anim_phase = 1
	ko_sequence_timer = KO_PRE_DELAY_TIME
	ko_winner_id = 0
	ko_perfect = false
	if p1_hp_now <= 0.0 and p2_hp_now <= 0.0:
		ko_winner_id = 0
		ko_draw_game = true
	elif p2_hp_now <= 0.0:
		ko_winner_id = 1
		ko_perfect = p1_hp_now >= get_fighter_hp_max(p1)
	elif p1_hp_now <= 0.0:
		ko_winner_id = 2
		ko_perfect = p2_hp_now >= get_fighter_hp_max(p2)

	# 原版 playKO：先 doEffectById("hit_end")、shine、shake，并播放 snd_over_hit；500ms 后才进入 ko label。
	AudioManager.play_sfx("res://assets/sfx/snd_over_hit.mp3", -2.0)
	hit_stop_timer = maxf(hit_stop_timer, 0.06)
	start_original_shake(5.0, 0.0, 1.5)
	flash_shine(Color(1.0, 1.0, 1.0, 0.5), 0.35)
	if fight_hud != null and fight_hud.has_method("hide_center_message"):
		fight_hud.call("hide_center_message")
	if p1_hp_now <= 0.0 and p1 != null and p1.has_method("play_action"):
		p1.play_action("lose")
	elif p1 != null and p1.has_method("play_action"):
		p1.play_action("win")
	if p2_hp_now <= 0.0 and p2 != null and p2.has_method("play_action"):
		p2.play_action("lose")
	elif p2 != null and p2.has_method("play_action"):
		p2.play_action("win")
	add_original_ko_score()
	print("KO pre-delay: p1_hp=", p1_hp_now, " p2_hp=", p2_hp_now, " winner=", ko_winner_id, " perfect=", ko_perfect, " score=", p1_score, "/", p2_score)



func move_p1_to_current_target(offset_x_value: Variant, offset_y_value: Variant, auto_turn: bool) -> void:
	if p1 == null:
		return
	if p2 == null:
		return

	var target_pos: Vector2 = get_p1_target_ground_pos()
	var has_x: bool = _original_number_is_present(offset_x_value)
	var has_y: bool = _original_number_is_present(offset_y_value)
	var offset_x: float = _nullable_number_to_float(offset_x_value, 0.0)
	var offset_y: float = _nullable_number_to_float(offset_y_value, 0.0)

	# 对应 FighterCtrler.moveToTarget(x, y, setDirect)：
	# if x != null: fighter.x = target.x + Number(x) * fighter.direct
	#   但当 x > 0 且目标接近地图左右边缘时，原版会改到目标另一侧，避免越界。
	# if y != null: fighter.y = target.y + Number(y)
	if has_x:
		var fx: float = target_pos.x + offset_x * float(p1.facing)
		if offset_x > 0.0:
			if target_pos.x < offset_x:
				fx = target_pos.x + offset_x
			elif target_pos.x > ORIGINAL_MAP_RIGHT - offset_x:
				fx = target_pos.x - offset_x
		p1.position.x = fx

	if has_y:
		p1.position.y = target_pos.y + offset_y

	clamp_fighter_to_original_map_bounds(p1)
	if p1.has_method("set_air_state_from_position"):
		p1.set_air_state_from_position()
	if auto_turn and p1.has_method("set_facing"):
		var new_direct: int = 1 if p1.position.x < target_pos.x else -1
		p1.set_facing(new_direct)
	print("原版 moveToTarget 触发：x=", offset_x_value, " y=", offset_y_value, " autoTurn=", auto_turn, " has_x=", has_x, " has_y=", has_y, " new_pos=", p1.position)


func _original_number_is_present(value: Variant) -> bool:
	if value == null:
		return false
	if typeof(value) == TYPE_STRING:
		var s: String = String(value).strip_edges().to_lower()
		return s != "" and s != "null" and s != "nan"
	return true


func _original_args_number(args: Array, index: int, fallback: float = 0.0) -> float:
	if index < 0 or index >= args.size():
		return fallback
	return _nullable_number_to_float(args[index], fallback)


func play_original_shine_event(action_name: String, relative_frame: int, semantic: Dictionary) -> void:
	# FighterEffectCtrler.shine(color=0xFFFFFF)：白色 alpha=0.3；非白色 alpha=0.2。
	# Aizen 时间轴中当前解析到的是 shine()，没有显式 color，因此使用白色 0.3。
	var color_value: int = int(semantic.get("color", 0xFFFFFF))
	var alpha: float = ORIGINAL_SHINE_WHITE_ALPHA if color_value == 0xFFFFFF else ORIGINAL_SHINE_COLORED_ALPHA
	var r: float = float((color_value >> 16) & 0xFF) / 255.0
	var g: float = float((color_value >> 8) & 0xFF) / 255.0
	var b: float = float(color_value & 0xFF) / 255.0
	flash_shine(Color(r, g, b, alpha), ORIGINAL_SHINE_DURATION)
	print("原版 shine 触发 action=", action_name, " frame=", relative_frame, " color=", color_value, " alpha=", alpha)


func play_original_dash_effect(action_name: String, relative_frame: int) -> void:
	# FighterEffectCtrler.dash()：地面 doEffectById("dash", fighter.x, fighter.y, direct)，空中用 dash_air。
	# EffectModel.as 中 dash/dash_air 分别对应 XG_rush / XG_rush_air，二者声音均为 snd_dash_air。
	var is_air: bool = p1 != null and bool(p1.get("in_air"))
	var effect_id: String = "dash_air" if is_air else "dash"
	if common_effects != null and common_effects.has_method("play_dash_effect"):
		common_effects.play_dash_effect(p1.position, p1.facing, is_air)
		print("原版 dash effect 触发 action=", action_name, " frame=", relative_frame, " effect=", effect_id)
	elif _common_effect_exists(effect_id):
		common_effects.play_effect(effect_id, p1.position, p1.facing, 1.0, false)
		AudioManager.play_effect_sfx("snd_dash_air")
		print("原版 dash effect 触发 action=", action_name, " frame=", relative_frame, " effect=", effect_id)
	else:
		print("原版 dash effect 触发但资源未接入：", effect_id, " action=", action_name, " frame=", relative_frame)

func _common_effect_exists(effect_id: String) -> bool:
	if common_effects == null:
		return false
	var manifest_value: Variant = common_effects.get("manifest")
	if typeof(manifest_value) != TYPE_DICTIONARY:
		return false
	var effects: Dictionary = (manifest_value as Dictionary).get("effects", {}) as Dictionary
	return effects.has(effect_id)


func handle_original_movement_event(action_name: String, relative_frame: int, semantic: Dictionary) -> void:
	var method_name: String = String(semantic.get("method", ""))
	var args: Array = semantic.get("args", []) as Array
	match method_name:
		"move":
			# FighterMcCtrler.move(x,y)：x *= direct；setVelocity(x,y)。原版 velocity 是按帧推进，Godot 这里换算成每秒。
			var vx: float = _original_args_number(args, 0, 0.0) * float(p1.facing) * 30.0
			var vy: float = _original_args_number(args, 1, 0.0) * 30.0
			_apply_original_velocity(vx, vy)
			print("原版 move 触发 action=", action_name, " frame=", relative_frame, " velocity=", Vector2(vx, vy))
		"movePercent":
			# movePercent(x,y)：move(fighter.speed*x, fighter.speed*y)。当前 Godot 的 fighter.speed 等价使用 move_speed。
			var vx_percent: float = move_speed * _original_args_number(args, 0, 0.0) * float(p1.facing)
			var vy_percent: float = move_speed * _original_args_number(args, 1, 0.0)
			_apply_original_velocity(vx_percent, vy_percent)
			print("原版 movePercent 触发 action=", action_name, " frame=", relative_frame, " velocity=", Vector2(vx_percent, vy_percent))
		"damping":
			# FighterMcCtrler.damping(x,y)：当前 ManifestFighter 只实现水平阻尼；y 阻尼暂不冒充。
			var damping_x: float = absf(_original_args_number(args, 0, 0.0)) * 30.0 * 30.0
			_apply_original_damping(damping_x)
			print("原版 damping 触发 action=", action_name, " frame=", relative_frame, " damping_x=", damping_x)
		"dampingPercent":
			var damping_percent_x: float = absf(move_speed * _original_args_number(args, 0, 0.0)) * 30.0
			_apply_original_damping(damping_percent_x)
			print("原版 dampingPercent 触发 action=", action_name, " frame=", relative_frame, " damping_x=", damping_percent_x)
		_:
			print("原版 movement 事件暂未接入 action=", action_name, " frame=", relative_frame, " data=", semantic)


func handle_original_dash_or_stop_event(action_name: String, relative_frame: int, semantic: Dictionary) -> void:
	var method_name: String = String(semantic.get("method", ""))
	var args: Array = semantic.get("args", []) as Array
	match method_name:
		"dash":
			var speed_plus: float = _original_args_number(args, 0, 3.0)
			if p1 != null and p1.has_method("apply_original_dash_motion"):
				p1.apply_original_dash_motion(speed_plus, move_speed)
			print("原版 mc_ctrler.dash 触发 action=", action_name, " frame=", relative_frame, " speedPlus=", speed_plus)
		"dashStop":
			var lose_percent: float = _original_args_number(args, 0, 0.5)
			if p1 != null and p1.has_method("apply_original_dash_stop"):
				p1.apply_original_dash_stop(lose_percent)
			print("原版 mc_ctrler.dashStop 触发 action=", action_name, " frame=", relative_frame, " losePercent=", lose_percent)
		"stopMove":
			if p1 != null and p1.has_method("stop_original_motion"):
				p1.stop_original_motion()
			print("原版 stopMove 触发 action=", action_name, " frame=", relative_frame)
		_:
			print("原版 dash_or_stop 事件暂未接入 action=", action_name, " frame=", relative_frame, " data=", semantic)


func _apply_original_velocity(vx: float, vy: float) -> void:
	if p1 == null:
		return
	if p1.has_method("set_original_velocity"):
		p1.set_original_velocity(vx, vy)


func _apply_original_damping(damping_x: float) -> void:
	if p1 == null:
		return
	if p1.has_method("set_original_damping"):
		p1.set_original_damping(damping_x)


func play_p1_effect(effect_name: String, offset: Vector2, effect_scale: float = 1.0) -> void:
	if p1 == null:
		return

	if p1_effect == null:
		return

	var pos: Vector2 = p1.position + offset
	p1_effect.play_effect(effect_name, pos, p1.facing, effect_scale)


func get_p1_target_ground_pos() -> Vector2:
	# 对应原版 FighterMain.getCurrentTarget()。
	# 当前课程 Demo 只有 P1 蓝染与 P2 蓝染，因此 currentTarget 固定为 P2。
	return get_node_ground_pos(p2, P2_START_POS)


func _reset_active_attacker_state() -> void:
	active_attacker_follow_target = false
	active_attacker_effect_name = ""
	active_attacker_offset = Vector2.ZERO
	active_attacker_original_origin = Vector2.ZERO
	active_attacker_facing = 1
	active_attacker_has_hit = false


func _attacker_visual_position_from_origin() -> Vector2:
	# Step10：EffectPlayer 根据 aizen_effect_manifest.json 的 visual_offset 移动 Sprite2D。
	# BattlePlaceholder 中的 EffectPlayer Node2D 位置必须保持为原版 FighterAttacker 世界原点。
	return active_attacker_original_origin


func play_p1_attacker_at_target(effect_name: String, target_offset: Vector2, effect_scale: float = 1.0) -> void:
	if p1 == null:
		return

	if p1_effect == null:
		return

	# 对应原版 addAttacker("bsmc", {x:{followTarget:true,offset:0}, y:{followTarget:true,offset:-25}})。
	# original_origin 是 FighterAttacker 的世界原点；FFDec PNG 视觉注册点由 EffectPlayer / manifest 处理。
	active_attacker_follow_target = true
	active_attacker_effect_name = effect_name
	active_attacker_offset = target_offset
	active_attacker_original_origin = get_p1_target_ground_pos() + target_offset
	active_attacker_facing = p1.facing
	active_attacker_has_hit = false

	p1_effect.play_effect(effect_name, _attacker_visual_position_from_origin(), active_attacker_facing, effect_scale)


func play_p1_attacker_at_self(effect_name: String, self_offset: Vector2, effect_scale: float = 1.0) -> void:
	if p1 == null:
		return

	if p1_effect == null:
		return

	# 对应原版 addAttacker("zh3mc", {applyG:false})：创建时以当前 fighter 原点为 attacker 原点，
	# 后续不 follow fighter / currentTarget。视觉偏移由 EffectPlayer / manifest 处理。
	active_attacker_follow_target = false
	active_attacker_effect_name = effect_name
	active_attacker_offset = self_offset
	active_attacker_original_origin = p1.position
	active_attacker_facing = p1.facing
	active_attacker_has_hit = false

	p1_effect.play_effect(effect_name, active_attacker_original_origin + self_offset, active_attacker_facing, effect_scale, true)


func update_attacker_follow_target() -> void:
	if not active_attacker_follow_target:
		return

	if p1_effect == null:
		_reset_active_attacker_state()
		return

	if not p1_effect.playing or p1_effect.current_effect != active_attacker_effect_name:
		_reset_active_attacker_state()
		return

	# 对应原版 FighterAttacker.renderFollowTarget():
	# x = target.x + offsetX * direct; y = target.y + offsetY。
	# 这里更新的是 original_origin；视觉修正仍然只作用于 FFDec PNG 画布。
	active_attacker_original_origin = get_p1_target_ground_pos() + active_attacker_offset
	p1_effect.position = _attacker_visual_position_from_origin()
