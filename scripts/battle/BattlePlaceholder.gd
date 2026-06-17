extends Control

const ManifestFighter = preload("res://scripts/character/ManifestFighter.gd")
const EffectPlayer = preload("res://scripts/character/EffectPlayer.gd")
const BishaEffectPlayer = preload("res://scripts/character/BishaEffectPlayer.gd")
const CommonEffectLayer = preload("res://scripts/character/CommonEffectLayer.gd")
const ShadowEffectLayer = preload("res://scripts/character/ShadowEffectLayer.gd")
const FightHud = preload("res://scripts/ui/FightHud.gd")

var p1
var p2
var p1_effect
var bisha_effect
var common_effects: CommonEffectLayer
var shadow_effects: ShadowEffectLayer

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
# Step27 Hotfix：
# Step25 直接对齐视觉脚底 -> 过低；Step26 用 106.125px 仍偏低。
# 这次把“通用技能/攻击特效”的 SWF 注册点修正为 70px：位于 Godot centered Sprite 原点与脚底之间，
# 对应原版 hit / addAttacker 通常围绕角色上半身/刀光，而不是压到脚下。
# L 瞬步烟尘单独用脚底对齐，不复用这个 70px。
const ORIGINAL_SWF_IDLE_BOTTOM_FROM_REGISTRATION: float = 26.10
const ORIGINAL_SWF_EFFECT_Y_FROM_GODOT_ORIGIN: float = 70.0
# hit / defense / steel / break_def 等公共命中特效只修正视觉高度，不改变实际碰撞框。
const ORIGINAL_HIT_EFFECT_VISUAL_Y_CORRECTION: float = ORIGINAL_SWF_EFFECT_Y_FROM_GODOT_ORIGIN
# XG_rush / dash 的 PNG bbox 底部比纹理中心低约 7px；为了让灰尘底部贴角色脚底，origin 用 foot - 7。
const ORIGINAL_DASH_DUST_FRAME_BOTTOM_FROM_CENTER: float = 7.0
const ORIGINAL_DASH_EFFECT_Y_FROM_GODOT_ORIGIN: float = ORIGINAL_FIGHTER_FOOT_OFFSET_Y - ORIGINAL_DASH_DUST_FRAME_BOTTOM_FROM_CENTER
# 原版 FighterMain.speed=6；瞬步 timeline 为 dash(4) -> dashStop()，不能再手动瞬移 180px。
const ORIGINAL_FIGHTER_SPEED_PER_FRAME: float = 6.0
const ORIGINAL_DASH_INPUT_MANUAL_DISTANCE: float = 0.0
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

# Step22-24：输入响应优化。
# 原版 Flash 每帧轮询键位，玩家提前几帧按下 J/U/I/K/L 也会在动作窗口到达时立即被 renderFloorAction/renderAirAction 消化。
# 这里加入 0.12s 输入缓冲，减少“按键已经按下但角色等到下一次窗口才响应”的体感延迟。
const ORIGINAL_INPUT_BUFFER_TIME: float = 0.12
var p1_attack_buffer_timer: float = 0.0
var p1_skill_buffer_timer: float = 0.0
var p1_bisha_buffer_timer: float = 0.0
var p1_jump_buffer_timer: float = 0.0
var p1_dash_buffer_timer: float = 0.0

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

# Step17：原版 moveTarget / setCross。
# MoveTargetParamVO.as: speed number -> speed * GameConfig.SPEED_PLUS；默认 FPS_GAME=60，所以 SPEED_PLUS=30/60=0.5。
# Aizen mc_023.xml: throw2 frame 734: moveTarget({followmc:"move_mc",speed:5});
# move_mc 实例在 frame 734 的 Matrix tx=31.3, ty=-43.5。
const ORIGINAL_GAME_RENDER_FPS: float = 60.0
const ORIGINAL_SPEED_PLUS_DEFAULT: float = 0.5
const ORIGINAL_THROW2_MOVE_MC_LOCAL_POS := Vector2(31.3, -43.5)
const ORIGINAL_FIGHTER_BODY_SEPARATION_X: float = 54.0
var original_move_target_active: bool = false
var original_move_target_follow_mc_name: String = ""
var original_move_target_fixed_pos: Vector2 = Vector2.ZERO
var original_move_target_has_fixed_x: bool = false
var original_move_target_has_fixed_y: bool = false
var original_move_target_speed_per_frame: Vector2 = Vector2.ZERO
var original_move_target_has_speed: bool = false
var original_move_target_target: Variant = null

# Step18：原版 catch / throw 入口。
# FighterMcCtrler.allowCatch(): 目标不能处于 HURT_ING，双方 body 贴边 disX < 2，脚底 y 差 disY < 1，且必须朝向目标。
# 当前 Godot ManifestFighter 的 Node2D.position 是脚底/地面点，body 宽度用 Step17 分离距离 54px 对齐。
const ORIGINAL_CATCH_BODY_WIDTH: float = ORIGINAL_FIGHTER_BODY_SEPARATION_X
const ORIGINAL_CATCH_BODY_HEIGHT: float = 80.0
const ORIGINAL_CATCH_MAX_GAP_X: float = 2.0
const ORIGINAL_CATCH_MAX_GAP_Y: float = 1.0
var p1_catch1_ready: bool = true
var p1_catch2_ready: bool = true
var original_catch_target: Variant = null
var original_core_battle_audit_printed: bool = false
var original_final_stage_audit_printed: bool = false
# Step19-21：核心战斗整合状态。
# 防御/破防/KO/时间结束都只锁战斗层，不全局暂停 HUD/音频。
var original_round_end_actions_applied: bool = false

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

	# 蓝染投技。DOMDocument.xml defineAction:
	# sh1/sh2 为 CATCH 判定，命中后目标进入抓取受击；sh12/sh22 是投技后续伤害。
	"sh1": {"id":"sh1", "power":0, "powerRate":1.0, "hitType":11, "hitx":0, "hity":0, "hurtTime":1000, "hurtType":0, "isBreakDef":true, "isReal":false, "isApplyG":true},
	"sh12": {"id":"sh12", "power":50, "powerRate":1.0, "hitType":6, "hitx":-7, "hity":1, "hurtTime":1000, "hurtType":0, "isBreakDef":false, "isReal":false, "isApplyG":true},
	"sh2": {"id":"sh2", "power":0, "powerRate":1.0, "hitType":11, "hitx":0, "hity":0, "hurtTime":1000, "hurtType":0, "isBreakDef":true, "isReal":false, "isApplyG":true},
	"sh22": {"id":"sh22", "power":150, "powerRate":1.0, "hitType":5, "hitx":10, "hity":-5, "hurtTime":0, "hurtType":1, "isBreakDef":false, "isReal":false, "isApplyG":true},

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

# 第 18 步：蓝染投技攻击面。
# throw1: sh1atm global 709-711, sh12atm global 715-717。
# throw2: sh1atm global 730-732 映射 HitVO sh2，sh22atm global 746-748。
const SH1ATM_THROW1_RECT := Rect2(Vector2(4.05, -31.40), Vector2(33.45, 54.69))
const SH12ATM_RECT := Rect2(Vector2(-36.80, -43.95), Vector2(91.72, 58.28))
const SH1ATM_THROW2_RECT := Rect2(Vector2(1.80, -25.90), Vector2(30.64, 43.85))
const SH22ATM_RECT := Rect2(Vector2(2.80, -62.95), Vector2(115.39, 89.12))


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
var qi_hint_label: Label
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
# 旧 shake_timer / shake_power 保留为兼容字段，Step14 起实际震动改为 EffectCtrler.as 的 hold + pow + lose 模型。
var shake_timer: float = 0.0
var shake_power: Vector2 = Vector2.ZERO
# EffectCtrler.as:
#   startShake(sx,sy) -> _shakeHoldX/Y
#   shake(powX,powY,time) -> _shakePowX/Y + _shakeLoseX/Y
#   renderShakeX/Y 每帧交替方向，并每 2 帧衰减一次 pow。
var original_shake_hold: Vector2 = Vector2.ZERO
var original_shake_pow: Vector2 = Vector2.ZERO
var original_shake_lose: Vector2 = Vector2.ZERO
var original_shake_direct: Vector2 = Vector2(1.0, 1.0)
var original_shake_frame_x: int = 0
var original_shake_frame_y: int = 0
var original_shake_offset: Vector2 = Vector2.ZERO
var original_shake_accumulator: float = 0.0
const ORIGINAL_SHAKE_FPS: float = 30.0
const ORIGINAL_SHAKE_DEFAULT_TIME: float = 0.5
# EffectCtrler.slowDown / GameCtrler.slow 的局部化实现：
# 原版 slow(rate) 会把角色主逻辑速度除以 rate、动画 FPS 改为 30/rate、特效动画 gap 改为 30/rate。
# Godot 侧不使用 Engine.time_scale，避免 HUD、音频、KO 流程被全局拖慢；只给战斗对象/特效对象注入 original_time_scale。
const ORIGINAL_SLOW_DEFAULT_RATE: float = 1.5
var original_slow_active: bool = false
var original_slow_rate: float = 1.0
var original_slow_time_left: float = 0.0
var original_slow_has_auto_resume: bool = false
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
# Step40：禁用旧 KO/Winner 黑底序列，使用自建结算菜单。
var round_end_menu: Control
var round_end_menu_title: Label
var round_end_menu_subtitle: Label
var round_end_menu_shown: bool = false
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
# 原版 setZhao1()：允许下一次 U 走招1。当前只在对应窗口内置位，使用后清空。
var p1_zhao1_ready: bool = false

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
	audit_original_core_battle_once()
	audit_original_final_stage_once()


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

	create_world_backfill_background()

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

	# 小字提示：课程演示/测试用。按 P 只补满双方 qi，不改 HP/energy/fzqi，避免影响防御/破防测试。
	qi_hint_label = Label.new()
	qi_hint_label.name = "QiFillHintLabel"
	qi_hint_label.position = Vector2(250, 72)
	qi_hint_label.size = Vector2(300, 18)
	qi_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qi_hint_label.add_theme_font_size_override("font_size", 12)
	qi_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 0.92))
	qi_hint_label.text = "按“p”补满怒气"
	qi_hint_label.z_index = 205
	qi_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(qi_hint_label)

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

	create_round_end_menu()

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

	shadow_effects = ShadowEffectLayer.new()
	shadow_effects.name = "OriginalShadowEffectLayer"
	shadow_effects.z_index = 9
	game_layer.add_child(shadow_effects)

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

	update_original_slow_down(delta)
	update_original_visual_feedback(delta)
	update_round_intro(delta)
	update_ko_sequence(delta)
	if ko_finished or original_round_end_actions_applied:
		force_clear_bisha_after_round_end()
		force_hide_legacy_blackout_layers()
		if ko_anim_phase == 4 and not round_end_menu_shown:
			show_round_end_menu()
	# 原版 EffectCtrler.renderAnimate() 每帧 render ShadowEffectView。
	# 即使当前 hit-stop 锁住战斗输入，残影自身仍继续衰减。
	# ShadowEffectLayer 是 Node2D 子节点，会自动 _process；这里不需要手动 tick。

	if p1 == null:
		return

	if hit_stop_timer > 0.0:
		hit_stop_timer = maxf(0.0, hit_stop_timer - delta)
		update_hp_ui()
		update_resource_ui()
		update_original_camera(delta)
		return

	update_attacker_follow_target()
	update_original_move_target(delta * get_original_slow_time_scale())
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
	handle_p1_input(delta * get_original_slow_time_scale())
	resolve_original_cross_collision()
	clamp_fighters_to_original_map_bounds()
	force_reapply_original_world_locked_positions()
	if ORIGINAL_DEV_KEYS_ENABLED:
		handle_p2_debug_input()
	update_original_camera(delta)




func force_reapply_original_world_locked_positions() -> void:
	# Step33：本帧最后兜底，确保 U/招1 这类原版无根移动动作不会被父级逻辑或碰撞分离再次移动。
	if p1 != null and p1.has_method("force_reapply_original_no_world_move_anchor"):
		p1.force_reapply_original_no_world_move_anchor()
	if p2 != null and p2.has_method("force_reapply_original_no_world_move_anchor"):
		p2.force_reapply_original_no_world_move_anchor()


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
		var camera_tween_speed: float = ORIGINAL_CAMERA_TWEEN_SPEED * original_slow_rate if original_slow_active else ORIGINAL_CAMERA_TWEEN_SPEED
		camera_zoom += (target_zoom - camera_zoom) / camera_tween_speed
		camera_rect.position += (target_rect.position - camera_rect.position) / camera_tween_speed
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

	# Step40：旧 startKO / winner 序列会留下 663x466 黑底贴图。
	# KO 流程只保留音效和短延迟，然后显示自建菜单，不再调用 FightHud.show_ko/show_winner/show_timeover/show_drawgame。
	force_clear_bisha_after_round_end()
	force_hide_legacy_blackout_layers()

	if ko_winner_shown:
		if not round_end_menu_shown:
			show_round_end_menu()
		return

	if ko_sequence_timer > 0.0:
		ko_sequence_timer = maxf(0.0, ko_sequence_timer - delta)
		return

	if ko_anim_phase == 1:
		ko_anim_phase = 2
		ko_sequence_timer = 0.45 if ko_timeover else 0.55
		hide_fight_hud_center_message()

		if not ko_timeover:
			var ko_sound: String = "res://assets/sfx/snd_ko.mp3"
			if _is_currently_bisha_ko():
				ko_sound = "res://assets/sfx/snd_ko_bs.mp3"
			AudioManager.play_sfx(ko_sound, -2.0)

		if fight_hud != null and fight_hud.has_method("qibar_fad_out"):
			fight_hud.call("qibar_fad_out", true)
		return

	if ko_anim_phase == 2:
		ko_anim_phase = 3
		ko_sequence_timer = 0.25
		hide_fight_hud_center_message()
		return

	if ko_anim_phase == 3:
		ko_winner_shown = true
		ko_anim_phase = 4
		hide_fight_hud_center_message()
		force_hide_legacy_blackout_layers()
		show_round_end_menu()
		return



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
	force_clear_bisha_after_round_end()
	apply_original_round_end_actions("timeover")
	print("TIME OVER: p1_hp=", p1_hp_now, " p2_hp=", p2_hp_now, " winner=", ko_winner_id, " draw=", ko_draw_game)


func _is_currently_bisha_ko() -> bool:
	if p1 != null:
		var a1: String = str(p1.get("current_action"))
		if a1.begins_with("super"):
			return true
	if p2 != null:
		var a2: String = str(p2.get("current_action"))
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
	var p_pressed: bool = Input.is_key_pressed(KEY_P)
	var t_pressed: bool = ORIGINAL_DEV_KEYS_ENABLED and Input.is_key_pressed(KEY_T)

	var j_just: bool = j_pressed and not prev_j_pressed
	var k_just: bool = k_pressed and not prev_k_pressed
	var l_just: bool = l_pressed and not prev_l_pressed
	var u_just: bool = u_pressed and not prev_u_pressed
	var i_just: bool = i_pressed and not prev_i_pressed
	var p_just: bool = p_pressed and not prev_p_pressed
	var t_just: bool = t_pressed and not prev_t_pressed

	prev_j_pressed = j_pressed
	prev_k_pressed = k_pressed
	prev_l_pressed = l_pressed
	prev_u_pressed = u_pressed
	prev_i_pressed = i_pressed
	prev_p_pressed = p_pressed
	prev_t_pressed = t_pressed

	update_p1_input_buffers(delta, j_just, k_just, l_just, u_just, i_just)

	if p_just:
		fill_both_players_qi()

	if t_just:
		debug_fill_qi_energy()

	# 原版 FighterKeyCtrler.defense() = down。这里只在 S 单独按住时进入防御，避免影响 S+J / S+U / S+I。
	var pure_down_defense: bool = Input.is_key_pressed(KEY_S) and not (j_pressed or u_pressed or i_pressed or k_pressed or l_pressed)
	if p1.current_action == "defend" and not pure_down_defense:
		p1.play_action("defend_recover")
	elif pure_down_defense and p1.can_ground_action():
		p1.play_action("defend")
		return

	# 原版 renderFloorAction：只有按住朝向目标的移动方向，并且 catch1/catch2 输入成立时，才允许 doCatch。
	# Step22-24：改为吃输入缓冲，提前几帧按下也能在可行动第一帧立即触发。
	if p1 != null and p1.can_ground_action():
		if p1_attack_buffer_timer > 0.0 and try_original_catch_input("throw1", "catch1"):
			p1_attack_buffer_timer = 0.0
			return
		if p1_skill_buffer_timer > 0.0 and try_original_catch_input("throw2", "catch2"):
			p1_skill_buffer_timer = 0.0
			return

	# 先处理一次性动作键，避免按住 A/D 时把技能/攻击覆盖成 walk。
	# 这里不再只看 just_pressed，而是使用 0.12s buffer，提升连招/技能衔接响应。
	try_execute_p1_buffered_actions()

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


func update_p1_input_buffers(delta: float, j_just: bool, k_just: bool, l_just: bool, u_just: bool, i_just: bool) -> void:
	p1_attack_buffer_timer = maxf(0.0, p1_attack_buffer_timer - delta)
	p1_skill_buffer_timer = maxf(0.0, p1_skill_buffer_timer - delta)
	p1_bisha_buffer_timer = maxf(0.0, p1_bisha_buffer_timer - delta)
	p1_jump_buffer_timer = maxf(0.0, p1_jump_buffer_timer - delta)
	p1_dash_buffer_timer = maxf(0.0, p1_dash_buffer_timer - delta)

	if j_just:
		p1_attack_buffer_timer = ORIGINAL_INPUT_BUFFER_TIME
	if u_just:
		p1_skill_buffer_timer = ORIGINAL_INPUT_BUFFER_TIME
	if i_just:
		p1_bisha_buffer_timer = ORIGINAL_INPUT_BUFFER_TIME
	if k_just:
		p1_jump_buffer_timer = ORIGINAL_INPUT_BUFFER_TIME
	if l_just:
		p1_dash_buffer_timer = ORIGINAL_INPUT_BUFFER_TIME


func _did_p1_action_change(before_action: String, before_frame: int) -> bool:
	if p1 == null:
		return false
	return str(p1.current_action) != before_action or int(p1.frame_index) != before_frame


func try_execute_one_p1_buffer(buffer_name: String) -> bool:
	if p1 == null:
		return false
	var before_action: String = str(p1.current_action)
	var before_frame: int = int(p1.frame_index)

	match buffer_name:
		"jump":
			handle_jump_input()
		"dash":
			handle_dash_input()
		"attack":
			handle_attack_input()
		"skill":
			handle_skill_input()
		"bisha":
			handle_bisha_input()
		_:
			return false

	return _did_p1_action_change(before_action, before_frame)


func try_execute_p1_buffered_actions() -> void:
	# 优先级按原版常用输入：跳/瞬步先改变移动状态，再处理攻击、招、必杀。
	if p1_jump_buffer_timer > 0.0 and try_execute_one_p1_buffer("jump"):
		p1_jump_buffer_timer = 0.0
		return
	if p1_dash_buffer_timer > 0.0 and try_execute_one_p1_buffer("dash"):
		p1_dash_buffer_timer = 0.0
		return
	if p1_attack_buffer_timer > 0.0 and try_execute_one_p1_buffer("attack"):
		p1_attack_buffer_timer = 0.0
		return
	if p1_skill_buffer_timer > 0.0 and try_execute_one_p1_buffer("skill"):
		p1_skill_buffer_timer = 0.0
		return
	if p1_bisha_buffer_timer > 0.0 and try_execute_one_p1_buffer("bisha"):
		p1_bisha_buffer_timer = 0.0
		return


func clear_p1_input_buffers() -> void:
	p1_attack_buffer_timer = 0.0
	p1_skill_buffer_timer = 0.0
	p1_bisha_buffer_timer = 0.0
	p1_jump_buffer_timer = 0.0
	p1_dash_buffer_timer = 0.0


func fill_both_players_qi() -> void:
	# 按“p”补满怒气：只补满 qi，不改 HP / energy / fzqi，避免干扰防御、破防和 KO 测试。
	if p1 != null:
		set_node_float_property(p1, "qi", get_node_float_property(p1, "qi_max", 300.0))
	if p2 != null:
		set_node_float_property(p2, "qi", get_node_float_property(p2, "qi_max", 300.0))
	if fight_hud != null and fight_hud.has_method("qibar_fad_in"):
		fight_hud.call("qibar_fad_in", true)
	update_resource_ui()
	print("按 P：P1/P2 怒气已补满。P1 qi=", get_node_float_property(p1, "qi", 0.0), " P2 qi=", get_node_float_property(p2, "qi", 0.0))


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

	# 原版“瞬步”不是直接把角色平移 180px；mc_023 瞬步帧为：
	# frame 28: parent.$mc_ctrler.dash(4)
	# frame 33: parent.$mc_ctrler.dashStop()
	# 所以这里只切动作，让时间轴 dash/dashStop 事件驱动位移，避免“过远 + 滑动”。
	p1.play_action("dash")
	if ORIGINAL_DASH_INPUT_MANUAL_DISTANCE != 0.0:
		p1.position.x += ORIGINAL_DASH_INPUT_MANUAL_DISTANCE * p1.facing
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
			p1_zhao1_ready = false
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

	# 原版 setZhao1()：时间轴置位后，下一次 U 允许接“招1”。
	# 旧逻辑用 action+frame 硬编码；Step15 改为吃 manifest 里的 enable_zhao 事件。
	if p1_zhao1_ready:
		p1_zhao1_ready = false
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
	var text: String = str(value).strip_edges()
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
	# 原版 XFL 时间轴里部分 effect_ctrler 事件目前没有 semantic 字段，必须直接处理 raw call。
	# 这里处理：
	# - mc_ctrler.addAttacker("bsmc" / "zh3mc")
	# - effect_ctrler.shadow(r,g,b)
	# - effect_ctrler.endShadow()
	var object_name: String = str(raw_call.get("object", ""))
	var method_name: String = str(raw_call.get("method", ""))
	var args: Array = raw_call.get("args", []) as Array

	if object_name == "effect_ctrler":
		match method_name:
			"shadow":
				var r: int = int(_raw_args_number(args, 0, 0.0))
				var g: int = int(_raw_args_number(args, 1, 0.0))
				var b: int = int(_raw_args_number(args, 2, 0.0))
				start_p1_shadow(r, g, b)
				print("原版 shadow 触发 action=", action_name, " frame=", relative_frame, " color=", Vector3(r, g, b))
			"endShadow":
				end_p1_shadow()
				print("原版 endShadow 触发 action=", action_name, " frame=", relative_frame)
			"shake":
				play_fighter_effect_shake_event(action_name, relative_frame, args)
			"startShake":
				start_fighter_effect_hold_shake_event(action_name, relative_frame, args)
			"endShake":
				end_fighter_effect_hold_shake_event(action_name, relative_frame)
			"playSoundHit1":
				play_original_timeline_asset_sound("se_hit1", action_name, relative_frame)
			"playSoundHit2":
				play_original_timeline_asset_sound("se_hit2", action_name, relative_frame)
			"walk":
				play_original_walk_sound(action_name, relative_frame)
			"slowDown":
				play_original_slow_down_event(action_name, relative_frame, args)
			"slowDownResume":
				play_original_slow_down_resume_event(action_name, relative_frame)
			_:
				pass
		return

	if object_name == "fighter_ctrler":
		match method_name:
			"moveOnce":
				move_p1_once_by_original_args(action_name, relative_frame, args)
			"setDirectToTarget":
				face_p1_current_target(action_name, relative_frame)
			"setCross":
				var cross_enabled: bool = args.size() > 0 and bool(args[0])
				set_p1_cross_enabled(cross_enabled, action_name, relative_frame)
			_:
				pass
		return

	if object_name == "mc_ctrler" and method_name == "moveTarget":
		var move_args_raw: String = str(raw_call.get("args_raw", ""))
		handle_original_move_target_event(action_name, relative_frame, {"args_raw": move_args_raw})
		return

	if object_name != "mc_ctrler" or method_name != "addAttacker":
		return

	if args.is_empty():
		return

	var attacker_name: String = str(args[0])

	if attacker_name == "bsmc":
		var args_raw: String = str(raw_call.get("args_raw", ""))
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
	var event_type: String = str(semantic.get("type", ""))

	match event_type:
		"super_effect_start":
			if ko_finished or original_round_end_actions_applied:
				force_clear_bisha_after_round_end()
				print("Bisha start ignored after round end action=", action_name, " frame=", relative_frame)
				return

			var original_face_id: String = str(semantic.get("effect_name", ""))
			var is_super: bool = semantic.get("is_super", false) == true

			print("Bisha start:", original_face_id, " is_super=", is_super, " action=", action_name, " frame=", relative_frame)

			if bisha_effect != null:
				# 原版 EffectCtrler.bisha(target) 的通用光效位置是 target.x, target.y - 50。
				# 当前 BishaEffectPlayer 是 HUD/屏幕层节点，所以必须先在世界坐标中加 -50，再转换到屏幕坐标；
				# 不能在屏幕层直接减 50，否则 camera zoom != 1 时高度会与原版不一致。
				# 原版 EffectCtrler.bisha(target)：普通角色特效按 target.x / target.y，XG_bs/XG_cbs 按 target.y - 50。
				# 这里 target.y 先从 Godot 纹理中心换算为 SWF fighter 注册点，否则必杀光效会整体飘在人物上方。
				var bisha_caster_origin: Vector2 = get_p1_original_effect_origin()
				var bisha_target_origin: Vector2 = get_p1_target_original_effect_origin()
				var bisha_target_screen: Vector2 = world_to_screen(bisha_caster_origin)
				var bisha_current_target_screen: Vector2 = world_to_screen(bisha_target_origin)
				var bisha_xg_screen: Vector2 = world_to_screen(bisha_caster_origin + Vector2(0.0, -50.0))
				bisha_effect.play_bisha(is_super, original_face_id, bisha_target_screen, p1.facing, bisha_current_target_screen, bisha_xg_screen)

		"super_effect_end":
			print("Bisha end action=", action_name, " frame=", relative_frame)

			if bisha_effect != null:
				bisha_effect.end_bisha()

		"effect":
			var effect_method: String = str(semantic.get("effect_method", ""))

			if effect_method == "shine":
				play_original_shine_event(action_name, relative_frame, semantic)

			elif effect_method == "dash":
				play_original_dash_effect(action_name, relative_frame)

			elif effect_method == "walk":
				play_original_walk_sound(action_name, relative_frame)

			elif effect_method == "slowDown":
				var slow_args: Array = semantic.get("args", []) as Array
				play_original_slow_down_event(action_name, relative_frame, slow_args)

			elif effect_method == "slowDownResume":
				play_original_slow_down_resume_event(action_name, relative_frame)

			elif effect_method == "shake":
				var shake_args: Array = semantic.get("args", []) as Array
				play_fighter_effect_shake_event(action_name, relative_frame, shake_args)

			elif effect_method == "startShake":
				var hold_args: Array = semantic.get("args", []) as Array
				start_fighter_effect_hold_shake_event(action_name, relative_frame, hold_args)

			elif effect_method == "endShake":
				end_fighter_effect_hold_shake_event(action_name, relative_frame)

			else:
				print("原版 effect 事件暂未接入 action=", action_name, " frame=", relative_frame, " method=", effect_method)

		"end_action":
			# 原版 endAct()：_action.clearAction(); actionState=FREEZE; setSteelBody(false)。
			# FighterMcCtrler.doAction/idle/doHurt 都会调用 effectCtrler.endShadow()。
			print("原版 endAct 触发 action=", action_name, " frame=", relative_frame)
			end_p1_shadow()
			if p1 != null and p1.has_method("set_steel_body"):
				p1.set_steel_body(false, false)
			clear_original_move_target_binding("endAct")
			clear_original_catch_target("endAct")
			if action_name == "jump_attack" or action_name == "air_skill" or action_name == "super_air":
				if p1 != null and p1.has_method("unlock_original_action"):
					p1.unlock_original_action()

		"return_idle":
			print("原版 idle() 触发 action=", action_name, " frame=", relative_frame)
			end_p1_shadow()
			p1_air_skill_ready = false
			p1_air_bisha_ready = false
			attack_skill2_1_ready = false
			attack_skill2_next_attack_ready = false
			clear_original_move_target_binding("idle")
			clear_original_catch_target("idle")
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
			var checker_name: String = str(semantic.get("checker", semantic.get("hit_mc", "")))
			var target_label: String = str(semantic.get("target_action", semantic.get("success_label", "")))
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
			var hurt_label: String = str(semantic.get("target_label", ""))
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
			var enable_method: String = str(semantic.get("method", ""))

			if enable_method == "setSkillAIR":
				p1_air_skill_ready = true
				print("原版 setSkillAIR 触发：跳砍后允许接空中 U / 跳招")

			elif enable_method == "setSkill2":
				var skill2_label: String = str(semantic.get("target_label", ""))
				var skill2_action: String = map_original_label_to_action(skill2_label)
				print("原版 setSkill2 触发 action=", action_name, " frame=", relative_frame, " target=", skill2_label, " -> ", skill2_action)
				if skill2_action == "attack_skill2_1":
					attack_skill2_1_ready = true

		"enable_next_attack":
			# 原版 setAttack("砍4_QK")：把下一次 J 的 attack 动作改为 砍4_QK。
			var attack_label: String = str(semantic.get("target_label", ""))
			var attack_action: String = map_original_label_to_action(attack_label)
			print("原版 setAttack 触发 action=", action_name, " frame=", relative_frame, " target=", attack_label, " -> ", attack_action)
			if attack_action == "atk4_extra":
				attack_skill2_next_attack_ready = true

		"enable_zhao":
			# 原版 setZhao1()：当前攻击窗口中允许接 U -> 招1。
			p1_zhao1_ready = true
			print("原版 setZhao1 触发 action=", action_name, " frame=", relative_frame)

		"set_cross":
			var cross_enabled_sem: bool = semantic.get("enabled", false) == true
			set_p1_cross_enabled(cross_enabled_sem, action_name, relative_frame)

		"face_target":
			face_p1_current_target(action_name, relative_frame)

		"air_move":
			var air_move_enabled: bool = semantic.get("enabled", false) == true
			if p1 != null and p1.has_method("set_air_move_enabled"):
				p1.set_air_move_enabled(air_move_enabled)
			else:
				p1.set_meta("original_air_move_enabled", air_move_enabled)
			print("原版 setAirMove 触发 action=", action_name, " frame=", relative_frame, " enabled=", air_move_enabled)

		"if_last_hit_play":
			handle_original_just_hit_to_play(action_name, relative_frame, semantic)

		"stop_animation":
			if p1 != null and p1.has_method("stop_original_animation"):
				p1.stop_original_animation()
			print("原版 stop() 触发 action=", action_name, " frame=", relative_frame)

		"move_target":
			handle_original_move_target_event(action_name, relative_frame, semantic)

		"loop_action":
			# 当前动作循环由 manifest loop 字段处理；这里仅记录原版 loop(label)。
			print("原版 loop 事件记录 action=", action_name, " frame=", relative_frame, " target=", semantic.get("target_label", ""))

		"enable_super":
			var enable_method_super: String = str(semantic.get("method", ""))
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
			var attacker_name: String = str(semantic.get("attacker", ""))
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



func start_p1_shadow(r: int = 0, g: int = 0, b: int = 0) -> void:
	# FighterEffectCtrler.shadow(r,g,b) -> EffectCtrler.startShadow(_targetDisplay,r,g,b)。
	if shadow_effects == null or p1 == null:
		return
	shadow_effects.start_shadow(p1, r, g, b)


func end_p1_shadow() -> void:
	# 原版 endShadow() 只停止继续新增残影；已有残影继续按 alphaLose 衰减。
	if shadow_effects == null:
		return
	shadow_effects.end_shadow()


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

	# 投技：throw1/throw2。
	# throw1 start≈708: sh1atm relative 1-3；sh12atm relative 7-9。
	if action_name == "throw1":
		if frame >= 1 and frame <= 3:
			return {"rect": SH1ATM_THROW1_RECT, "label": "throw1 / sh1atm", "hit": "sh1", "key": "throw1:sh1"}
		if frame >= 7 and frame <= 9:
			return {"rect": SH12ATM_RECT, "label": "throw1 / sh12atm", "hit": "sh12", "key": "throw1:sh12"}

	# throw2 start≈729: sh1atm relative 1-3 -> HitVO sh2；sh22atm relative 17-19。
	if action_name == "throw2":
		if frame >= 1 and frame <= 3:
			return {"rect": SH1ATM_THROW2_RECT, "label": "throw2 / sh1atm", "hit": "sh2", "key": "throw2:sh2"}
		if frame >= 17 and frame <= 19:
			return {"rect": SH22ATM_RECT, "label": "throw2 / sh22atm", "hit": "sh22", "key": "throw2:sh22"}

	# Step36：招1 / U 的视觉闪电距离与命中判定对齐。
	# 原版 SWF 的解决方式不是按“雷电图片”另写一套范围，而是在同一个 FighterMain 时间轴里放 zh1atm：
	#   global 511/513/515/517 四组 zh1atm Matrix 逐段变长，和可见雷电同用 FighterMain 注册点/facing。
	# 当前 Godot actions_game/skill1 导出帧中，真正可见的雷电从 frame 17 左右开始；
	# 旧逻辑仍用 relative 5-12，导致“判定距离”和“看到的雷电距离”错位。
	# 这里保留原版 ZH1ATM_RECT_A/B/C/D 的距离矩阵，只把激活帧映射到当前导出帧里的可见雷电阶段。
	if action_name == "skill1":
		if frame >= 17 and frame <= 18:
			return {"rect": ZH1ATM_RECT_A, "label": "skill1 / zh1atm visual-phase A", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 19 and frame <= 20:
			return {"rect": ZH1ATM_RECT_B, "label": "skill1 / zh1atm visual-phase B", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 21 and frame <= 24:
			return {"rect": ZH1ATM_RECT_C, "label": "skill1 / zh1atm visual-phase C", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 25 and frame <= 28:
			return {"rect": ZH1ATM_RECT_D, "label": "skill1 / zh1atm visual-phase D", "hit": "zh1", "key": "skill1:zh1"}
		if frame >= 29 and frame <= 30:
			return {"rect": ZH1ATM_RECT_B, "label": "skill1 / zh1atm visual-phase shrink", "hit": "zh1", "key": "skill1:zh1"}

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
	var label_text: String = str(data.get("label", ""))
	var hit_vo_id: String = str(data.get("hit", ""))
	var attack_key: String = str(data.get("key", ""))
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

	var action_name: String = str(p2.get("current_action"))
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

	p2_last_hit_vo_id = "k1"
	p2_last_hit_action = action_name
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
	p1_last_hit_action = str(p1.get("current_action")) if p1 != null else ""
	var hit_vo: Dictionary = AIZEN_HIT_VO.get(current_hit_vo_id, {})
	print("HIT: ", current_attack_label, " -> p2 bdmn; HitVO=", current_hit_vo_id,
		" data=", hit_vo, " attack=", current_attack_world_rect, " hurt=", hurt_rect)

	# 对应原版流程：target.beHit(hitVO, hitRect)，attacker.hit(hitVO, target)。
	# 当前先实现核心：伤害、hurtType、hitx/hity、hurtTime。防御、连击计数、得分、特效仍待接。
	var hit_result: Dictionary = {}
	if p2 != null and p2.has_method("apply_original_hit"):
		hit_result = p2.apply_original_hit(hit_vo, p1.facing)
	if str(hit_result.get("result", "")) == "catch":
		original_catch_target = p2
		if p2 != null and p2.has_method("set_original_caught_by_throw"):
			p2.set_original_caught_by_throw(true)
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
	var hit_id: String = str(hit_vo.get("id", ""))
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
	var result: String = str(hit_result.get("result", ""))
	play_original_hit_feedback(hit_vo, current_attack_world_rect, result, p1.facing)
	if result == "dead" or result == "counter" or result == "defense" or result == "steel" or result == "ignored" or result == "catch":
		return
	add_qi_on_hit(p1, p2, hit_vo)
	p1_combo_count += 1
	p1_combo_timer = COMBO_RESET_TIME
	p2_combo_count = 0
	p2_combo_timer = 0.0
	p1_score += add_score_by_hit(hit_vo, p1_combo_count)


func after_p2_hit_target(hit_vo: Dictionary, hit_result: Dictionary) -> void:
	var result: String = str(hit_result.get("result", ""))
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
		hit_rect = Rect2(get_p2_original_effect_origin() - Vector2(20, 60), Vector2(40, 80))

	var effect_hit_rect: Rect2 = get_original_swf_effect_hit_rect(hit_rect)

	if result == "defense":
		if common_effects != null:
			common_effects.play_defense_effect(hit_vo, effect_hit_rect, facing)
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
			common_effects.play_steel_hit_effect(hit_vo, effect_hit_rect, facing)
		flash_shine(Color(1, 1, 1, 0.20), 0.12)
		# 原版 freeze(400) 会转成 400/1000*FPS_GAME 帧；当前 Godot hit_stop_timer 以秒计，先严格按 0.40s 对齐。
		hit_stop_timer = maxf(hit_stop_timer, 0.40)
		print("原版 doSteelHitEffect: hitType=", hit_vo.get("hitType", 0), " rect=", hit_rect)
		return

	if result == "catch":
		# EffectModel.initHitEffect: HitType.CATCH -> xg_catch_hit, freeze=400, sound=snd_hit_cache。
		if common_effects != null:
			common_effects.play_hit_effect(hit_vo, effect_hit_rect, facing)
		hit_stop_timer = maxf(hit_stop_timer, 0.40)
		flash_shine(Color(1, 1, 1, 0.18), 0.12)
		print("原版 catch hit: hitType=", hit_vo.get("hitType", 0), " rect=", hit_rect)
		return

	if result == "break_defense":
		if common_effects != null:
			common_effects.play_break_defense(effect_hit_rect, facing)
		flash_shine(Color(1, 1, 1, 0.22), 0.18)
		start_original_shake(6.0, 0.0, 0.28)
		hit_stop_timer = maxf(hit_stop_timer, 0.10)
		print("原版 break_def: rect=", hit_rect)
		return

	if result == "counter" or result == "dead":
		return

	if common_effects != null:
		common_effects.play_hit_effect(hit_vo, effect_hit_rect, facing)

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
	# EffectCtrler.shake(powX,powY,time:int ms) 的 Godot 秒制入口。
	# powX/powY 为 0 时不影响该轴；已有 pow 时按原版 += abs(pow)/2 叠加。
	var time_sec: float = duration
	if time_sec <= 0.0:
		time_sec = ORIGINAL_SHAKE_DEFAULT_TIME

	if pow_x != 0.0:
		if original_shake_pow.x == 0.0:
			original_shake_direct.x = 1.0 if pow_x > 0.0 else -1.0
			original_shake_pow.x = absf(pow_x)
			original_shake_frame_x = 0
		else:
			original_shake_pow.x += absf(pow_x) / 2.0

	if pow_y != 0.0:
		if original_shake_pow.y == 0.0:
			original_shake_direct.y = 1.0 if pow_y > 0.0 else -1.0
			original_shake_pow.y = absf(pow_y)
			original_shake_frame_y = 0
		else:
			original_shake_pow.y += absf(pow_y) / 2.0

	var frame_count: float = maxf(1.0, time_sec * ORIGINAL_SHAKE_FPS)
	original_shake_lose.x = maxf(1.0, ceil(original_shake_pow.x / frame_count)) if original_shake_pow.x > 0.0 else 0.0
	original_shake_lose.y = maxf(1.0, ceil(original_shake_pow.y / frame_count)) if original_shake_pow.y > 0.0 else 0.0
	print("原版 EffectCtrler.shake: pow=(", pow_x, ",", pow_y, ") duration=", time_sec, " lose=", original_shake_lose)


func start_original_hold_shake(pow_x: float, pow_y: float) -> void:
	# EffectCtrler.startShake(sx,sy)：保持震动，不自动衰减，直到 endShake。
	original_shake_hold = Vector2(pow_x, pow_y)
	if pow_x != 0.0:
		original_shake_direct.x = 1.0 if pow_x > 0.0 else -1.0
	if pow_y != 0.0:
		original_shake_direct.y = 1.0 if pow_y > 0.0 else -1.0
	print("原版 EffectCtrler.startShake: hold=", original_shake_hold)


func end_original_hold_shake() -> void:
	# EffectCtrler.endShake()：清除 hold 并把 stage x/y 归零；临时 shake pow 不被强制清除。
	original_shake_hold = Vector2.ZERO
	original_shake_offset = Vector2.ZERO
	position = Vector2.ZERO
	print("原版 EffectCtrler.endShake")


func play_fighter_effect_shake_event(action_name: String, relative_frame: int, args: Array) -> void:
	# FighterEffectCtrler.shake(powX=0,powY=3,time=0):
	#   var pow = Math.max(powX, powY)
	#   EffectCtrler.I.shake(0, pow * 2, time * 1000)
	var pow_x: float = _raw_args_number(args, 0, 0.0)
	var pow_y: float = _raw_args_number(args, 1, 3.0)
	var time_sec: float = _raw_args_number(args, 2, 0.0)
	var pow_value: float = maxf(pow_x, pow_y)
	start_original_shake(0.0, pow_value * 2.0, time_sec)
	print("原版 fighter shake 触发 action=", action_name, " frame=", relative_frame, " args=", args, " final=(0,", pow_value * 2.0, ") time=", time_sec)


func start_fighter_effect_hold_shake_event(action_name: String, relative_frame: int, args: Array) -> void:
	# FighterEffectCtrler.startShake(powX=0,powY=3) -> EffectCtrler.startShake(powX,powY)
	var pow_x: float = _raw_args_number(args, 0, 0.0)
	var pow_y: float = _raw_args_number(args, 1, 3.0)
	start_original_hold_shake(pow_x, pow_y)
	print("原版 fighter startShake 触发 action=", action_name, " frame=", relative_frame, " args=", args)


func end_fighter_effect_hold_shake_event(action_name: String, relative_frame: int) -> void:
	end_original_hold_shake()
	print("原版 fighter endShake 触发 action=", action_name, " frame=", relative_frame)


func update_original_visual_feedback(delta: float) -> void:
	render_original_shake(delta)

	if shine_overlay != null and shine_overlay.color.a > 0.0:
		var dur: float = float(shine_overlay.get_meta("duration", 0.12))
		var lose: float = delta / maxf(0.01, dur)
		var c: Color = shine_overlay.color
		c.a = maxf(0.0, c.a - lose)
		shine_overlay.color = c


func render_original_shake(delta: float) -> void:
	# 原版 EffectCtrler.renderShakeX/Y 每帧执行；这里按 30fps 步进，避免 60fps 下衰减过快。
	original_shake_accumulator += delta
	var step: float = 1.0 / ORIGINAL_SHAKE_FPS
	var guard: int = 0
	while original_shake_accumulator >= step and guard < 4:
		original_shake_accumulator -= step
		render_original_shake_x_step()
		render_original_shake_y_step()
		guard += 1

	position = original_shake_offset


func render_original_shake_x_step() -> void:
	var shake_x: float = original_shake_hold.x + original_shake_pow.x
	if shake_x > 0.0:
		original_shake_offset.x = shake_x * original_shake_direct.x

		if original_shake_pow.x > 0.0 and original_shake_frame_x % 2 == 0:
			original_shake_pow.x -= original_shake_lose.x
			if original_shake_pow.x < original_shake_lose.x:
				original_shake_pow.x = 0.0
				original_shake_offset.x = 0.0
				original_shake_frame_x = 0
				original_shake_lose.x = 0.0
				return

		original_shake_frame_x += 1
		original_shake_direct.x *= -1.0
	else:
		original_shake_offset.x = 0.0


func render_original_shake_y_step() -> void:
	var shake_y: float = original_shake_hold.y + original_shake_pow.y
	if shake_y > 0.0:
		original_shake_offset.y = shake_y * original_shake_direct.y

		if original_shake_pow.y > 0.0 and original_shake_frame_y % 2 == 0:
			original_shake_pow.y -= original_shake_lose.y
			if original_shake_pow.y < original_shake_lose.y:
				original_shake_pow.y = 0.0
				original_shake_offset.y = 0.0
				original_shake_frame_y = 0
				original_shake_lose.y = 0.0
				return

		original_shake_frame_y += 1
		original_shake_direct.y *= -1.0
	else:
		original_shake_offset.y = 0.0


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




func audit_original_core_battle_once() -> void:
	if original_core_battle_audit_printed:
		return
	original_core_battle_audit_printed = true
	print("Step19-21 core battle audit: defense/break/catch/KO enabled; Aizen HitVO count=", AIZEN_HIT_VO.size())


func audit_original_final_stage_once() -> void:
	if original_final_stage_audit_printed:
		return
	original_final_stage_audit_printed = true
	print("Step22-24 final audit: input buffer/P-fill/effect-height/sound-state timeline cleanup enabled.")
	print("Step20 attack windows covered: atk1-5, jump_attack, air_skill, skill1/2/3, attack_skill1/2, super/super_up/super_air/super_special, throw1/throw2, bsmc, zh3mc")




func create_world_backfill_background() -> void:
	# Step42：兜底填充世界背景。
	# Step40 曾把 z_index 设为 -10000，低于 Godot 4 的 CANVAS_ITEM_Z_MIN，导致调试器连续报错。
	# 这里只需要放在 map_sprite / player / front 下面，-100 已足够，且不会触发 RenderingServer 报错。
	if game_layer == null:
		return
	var tex: Texture2D = load("res://assets/maps/xianshi_layers/bg_stage.png")
	if tex == null:
		tex = load("res://assets/maps/xianshi.png")
	if tex == null:
		return

	var backfill := Node2D.new()
	backfill.name = "WorldBackfillBgStage"
	backfill.z_index = -100
	backfill.set_meta("keep_background_backfill", true)
	game_layer.add_child(backfill)

	for ix: int in range(-2, 4):
		for iy: int in range(-1, 2):
			var sp := Sprite2D.new()
			sp.name = "WorldBackfillBgTile"
			sp.texture = tex
			sp.centered = false
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(float(ix) * 800.0, float(iy) * 600.0)
			sp.z_index = 0
			backfill.add_child(sp)


func create_round_end_menu() -> void:
	if round_end_menu != null:
		return

	round_end_menu = Control.new()
	round_end_menu.name = "RoundEndMenu"
	round_end_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_end_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	round_end_menu.z_index = 1000
	round_end_menu.visible = false
	round_end_menu.set_meta("keep_round_end_ui", true)
	add_child(round_end_menu)

	var panel := Panel.new()
	panel.name = "RoundEndPanel"
	panel.position = Vector2(230, 180)
	panel.size = Vector2(340, 240)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("keep_round_end_ui", true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.88)
	style.border_color = Color(0.85, 0.78, 0.38, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	round_end_menu.add_child(panel)

	round_end_menu_title = Label.new()
	round_end_menu_title.name = "RoundEndTitle"
	round_end_menu_title.position = Vector2(20, 18)
	round_end_menu_title.size = Vector2(300, 34)
	round_end_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_end_menu_title.add_theme_font_size_override("font_size", 28)
	round_end_menu_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.36, 1.0))
	round_end_menu_title.text = "战斗结束"
	panel.add_child(round_end_menu_title)

	round_end_menu_subtitle = Label.new()
	round_end_menu_subtitle.name = "RoundEndSubtitle"
	round_end_menu_subtitle.position = Vector2(20, 55)
	round_end_menu_subtitle.size = Vector2(300, 24)
	round_end_menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_end_menu_subtitle.add_theme_font_size_override("font_size", 16)
	round_end_menu_subtitle.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	round_end_menu_subtitle.text = ""
	panel.add_child(round_end_menu_subtitle)

	var btn_retry := create_round_end_button("再来一局", Vector2(70, 94))
	btn_retry.pressed.connect(Callable(self, "_on_round_end_retry_pressed"))
	panel.add_child(btn_retry)

	var btn_select := create_round_end_button("返回选人", Vector2(70, 140))
	btn_select.pressed.connect(Callable(self, "_on_round_end_character_select_pressed"))
	panel.add_child(btn_select)

	var btn_title := create_round_end_button("返回标题", Vector2(70, 186))
	btn_title.pressed.connect(Callable(self, "_on_round_end_main_menu_pressed"))
	panel.add_child(btn_title)


func create_round_end_button(text_value: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.position = pos
	btn.size = Vector2(200, 34)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 18)
	return btn


func get_round_end_result_text() -> String:
	if ko_draw_game or ko_winner_id == 0:
		return "Draw Game"
	if ko_winner_id == 1:
		return "Winner：P1"
	return "Winner：P2"


func show_round_end_menu() -> void:
	if round_end_menu == null:
		create_round_end_menu()
	if round_end_menu == null:
		return

	round_end_menu_shown = true
	hide_fight_hud_center_message()
	if fight_hud != null:
		fight_hud.visible = false

	round_end_menu.visible = true
	round_end_menu.modulate.a = 1.0
	if round_end_menu_title != null:
		round_end_menu_title.text = "战斗结束"
	if round_end_menu_subtitle != null:
		round_end_menu_subtitle.text = get_round_end_result_text()

	if round_end_menu.get_child_count() > 0:
		var panel_node: Node = round_end_menu.get_child(0)
		if panel_node is Control:
			var panel := panel_node as Control
			for child in panel.get_children():
				if child is Button:
					(child as Button).grab_focus()
					break


func hide_fight_hud_center_message() -> void:
	if fight_hud == null:
		return
	if fight_hud.has_method("stop_all_round_end_animators"):
		fight_hud.call("stop_all_round_end_animators")
	if fight_hud.has_method("hide_center_message"):
		fight_hud.call("hide_center_message")
	if fight_hud.has_method("hide_winner"):
		fight_hud.call("hide_winner")
	if fight_hud.has_method("hide_drawgame"):
		fight_hud.call("hide_drawgame")
	if fight_hud.has_method("hide_ko"):
		fight_hud.call("hide_ko")
	if fight_hud.has_method("hide_timeover"):
		fight_hud.call("hide_timeover")
	if fight_hud.has_method("clear_center_message"):
		fight_hud.call("clear_center_message")
	force_hide_fight_hud_round_end_layers(fight_hud)


func force_hide_fight_hud_round_end_layers(node: Node) -> void:
	if node == null:
		return
	var lower_name: String = node.name.to_lower()
	var is_round_end_layer: bool = lower_name.find("winner") >= 0 or lower_name.find("ko") >= 0 or lower_name.find("draw") >= 0 or lower_name.find("timeover") >= 0 or lower_name.find("startko") >= 0 or lower_name.find("start_ko") >= 0 or lower_name.find("sequence") >= 0
	if is_round_end_layer and node is CanvasItem:
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
		force_hide_fight_hud_round_end_layers(child)


func force_hide_legacy_blackout_layers() -> void:
	force_clear_action_effects_after_round_end()
	if round_end_menu_shown and fight_hud != null:
		fight_hud.visible = false
	force_hide_fight_hud_round_end_layers(fight_hud)
	force_hide_legacy_blackout_layers_recursive(self)


func force_hide_legacy_blackout_layers_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_meta("keep_round_end_ui") and bool(node.get_meta("keep_round_end_ui")):
		return
	if node.has_meta("keep_background_backfill") and bool(node.get_meta("keep_background_backfill")):
		return

	var lower_name: String = node.name.to_lower()
	if node is ColorRect:
		var rect := node as ColorRect
		var c: Color = rect.color
		var black_like: bool = c.r <= 0.08 and c.g <= 0.08 and c.b <= 0.08
		var big_like: bool = rect.size.x >= 160.0 and rect.size.y >= 80.0
		var named_black: bool = lower_name.find("black") >= 0 or lower_name.find("dark") >= 0 or lower_name.find("bisha") >= 0 or lower_name.find("winner") >= 0 or lower_name.find("ko") >= 0 or lower_name.find("draw") >= 0 or lower_name.find("timeover") >= 0 or lower_name.find("startko") >= 0 or lower_name.find("sequence") >= 0
		if black_like and (big_like or named_black):
			rect.visible = false
			rect.modulate.a = 0.0
			rect.color = Color(c.r, c.g, c.b, 0.0)

	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		var named_black_item: bool = lower_name.find("black") >= 0 or lower_name.find("dark") >= 0 or lower_name.find("bisha") >= 0 or lower_name.find("winner") >= 0 or lower_name.find("ko") >= 0 or lower_name.find("draw") >= 0 or lower_name.find("timeover") >= 0 or lower_name.find("startko") >= 0 or lower_name.find("start_ko") >= 0 or lower_name.find("sequence") >= 0
		if named_black_item and (ko_finished or original_round_end_actions_applied):
			canvas_item.visible = false
			canvas_item.modulate.a = 0.0

	for child in node.get_children():
		force_hide_legacy_blackout_layers_recursive(child)


func _on_round_end_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_round_end_character_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")


func _on_round_end_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func force_clear_action_effects_after_round_end() -> void:
	# Step42：KO 结算后停止普通 attacker/effect 层。
	# 黑底问题的主因已确认是 win/lose 动作 PNG 中误烘焙的黑色背景层，
	# 但这里仍兜底关闭 bsmc / zh3mc 等未播放完的特效，避免结算菜单后残留旧技能帧。
	if p1_effect != null:
		if p1_effect.has_method("stop_effect"):
			p1_effect.stop_effect()
		if p1_effect is CanvasItem:
			var item := p1_effect as CanvasItem
			item.visible = false
			item.modulate.a = 0.0
	_reset_active_attacker_state()
	active_original_hitbox = ""
	clear_original_attack_box()


func force_clear_bisha_after_round_end() -> void:
	# Step28：KO 后如果 BishaEffectPlayer 的黑底层残留，会表现为角色后方大块全黑矩形。
	# KO / timeover / round end 期间每帧兜底清理，并禁止后续 super_effect_start 再打开它。
	if bisha_effect == null:
		return
	if bisha_effect.has_method("force_clear_bisha_visuals"):
		bisha_effect.force_clear_bisha_visuals()
	elif bisha_effect.has_method("end_bisha"):
		bisha_effect.end_bisha()
	if bisha_effect is CanvasItem:
		var item := bisha_effect as CanvasItem
		item.visible = false
		item.modulate.a = 0.0


func apply_original_round_end_actions(reason: String) -> void:
	# 原版 FightUI.playKO / timeover 进入结算后，角色动作进入 win / lose，战斗输入锁住。
	if original_round_end_actions_applied:
		return
	original_round_end_actions_applied = true
	clear_p1_input_buffers()
	resume_original_slow_down()
	end_p1_shadow()
	clear_original_move_target_binding(reason)
	force_clear_bisha_after_round_end()
	if ko_draw_game or ko_winner_id == 0:
		return
	if p1 != null and p1.has_method("play_action"):
		p1.play_action("win" if ko_winner_id == 1 else "lose")
	if p2 != null and p2.has_method("play_action"):
		p2.play_action("win" if ko_winner_id == 2 else "lose")
	print("原版 round end action: reason=", reason, " winner=", ko_winner_id)


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
	original_round_end_actions_applied = false
	fight_input_lock_timer = maxf(fight_input_lock_timer, KO_PRE_DELAY_TIME + KO_ANIM_TIME)
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
	# Step21：同时结束 slowDown / shadow / moveTarget，避免 KO 后战斗层继续绑定或慢放。
	resume_original_slow_down()
	end_p1_shadow()
	clear_original_move_target_binding("ko")
	force_clear_bisha_after_round_end()
	var ko_loser: Variant = null
	if p1_hp_now <= 0.0 and p1 != null:
		ko_loser = p1
	elif p2_hp_now <= 0.0 and p2 != null:
		ko_loser = p2
	if ko_loser != null and common_effects != null and common_effects.has_method("play_ko_hit_end"):
		common_effects.play_ko_hit_end(get_original_swf_effect_origin(ko_loser, P2_START_POS), get_node_facing(ko_loser))
	AudioManager.play_sfx("res://assets/sfx/snd_over_hit.mp3", -2.0)
	hit_stop_timer = maxf(hit_stop_timer, 0.06)
	start_original_shake(5.0, 0.0, 1.5)
	flash_shine(Color(1.0, 1.0, 1.0, 0.5), 0.35)
	if fight_hud != null and fight_hud.has_method("hide_center_message"):
		fight_hud.call("hide_center_message")
	apply_original_round_end_actions("ko")
	add_original_ko_score()
	print("KO pre-delay: p1_hp=", p1_hp_now, " p2_hp=", p2_hp_now, " winner=", ko_winner_id, " perfect=", ko_perfect, " score=", p1_score, "/", p2_score)





func handle_original_move_target_event(action_name: String, relative_frame: int, semantic: Dictionary) -> void:
	# FighterMcCtrler.moveTarget(params): params=null 时关闭；否则创建 MoveTargetParamVO 并绑定 _fighter.getCurrentTarget()。
	var args_raw: String = str(semantic.get("args_raw", "")).strip_edges()
	if args_raw == "" or args_raw.to_lower() == "null":
		clear_original_move_target_binding("moveTarget(null) action=" + action_name + " frame=" + str(relative_frame))
		return

	var parsed: Dictionary = parse_original_move_target_params(args_raw)
	original_move_target_active = true
	original_move_target_target = p2
	original_move_target_follow_mc_name = str(parsed.get("followmc", ""))
	original_move_target_fixed_pos = Vector2(float(parsed.get("x", 0.0)), float(parsed.get("y", 0.0)))
	original_move_target_has_fixed_x = parsed.get("has_x", false) == true
	original_move_target_has_fixed_y = parsed.get("has_y", false) == true
	original_move_target_speed_per_frame = parsed.get("speed", Vector2.ZERO)
	original_move_target_has_speed = original_move_target_speed_per_frame.length_squared() > 0.0001

	if original_move_target_target != null and original_move_target_target.has_method("set_original_move_target_bound"):
		original_move_target_target.set_original_move_target_bound(true)
	elif original_move_target_target != null and original_move_target_target.has_method("set_apply_gravity_enabled"):
		original_move_target_target.set_apply_gravity_enabled(false)

	print("原版 moveTarget 开启 action=", action_name, " frame=", relative_frame, " followmc=", original_move_target_follow_mc_name, " fixed=", original_move_target_fixed_pos, " hasXY=", Vector2(1 if original_move_target_has_fixed_x else 0, 1 if original_move_target_has_fixed_y else 0), " speed/frame=", original_move_target_speed_per_frame)


func parse_original_move_target_params(args_raw: String) -> Dictionary:
	# MoveTargetParamVO(params):
	#   x = params.x != undefined ? params.x : 0
	#   y = params.y != undefined ? params.y : 0
	#   followMcName = params.followmc != undefined ? params.followmc : null
	#   speed number -> Point(speed*SPEED_PLUS, speed*SPEED_PLUS)
	var out: Dictionary = {
		"followmc": "",
		"x": 0.0,
		"y": 0.0,
		"has_x": false,
		"has_y": false,
		"speed": Vector2.ZERO
	}
	var raw: String = args_raw.strip_edges()
	out["followmc"] = parse_original_object_string(raw, "followmc", "")
	if raw.find("x:") >= 0:
		out["x"] = parse_original_object_number(raw, "x", 0.0)
		out["has_x"] = true
	if raw.find("y:") >= 0:
		out["y"] = parse_original_object_number(raw, "y", 0.0)
		out["has_y"] = true

	if raw.find("speed:") >= 0:
		var speed_marker_pos: int = raw.find("speed:")
		var speed_tail: String = raw.substr(speed_marker_pos + "speed:".length()).strip_edges()
		if speed_tail.begins_with("{"):
			var sx: float = parse_original_object_number(speed_tail, "x", 0.0) * ORIGINAL_SPEED_PLUS_DEFAULT
			var sy: float = parse_original_object_number(speed_tail, "y", 0.0) * ORIGINAL_SPEED_PLUS_DEFAULT
			out["speed"] = Vector2(sx, sy)
		else:
			var spd: float = parse_original_object_number(raw, "speed", 0.0) * ORIGINAL_SPEED_PLUS_DEFAULT
			out["speed"] = Vector2(spd, spd)
	return out


func parse_original_object_string(raw: String, key: String, fallback: String = "") -> String:
	var marker: String = key + ":"
	var start: int = raw.find(marker)
	if start < 0:
		return fallback
	var value_start: int = start + marker.length()
	while value_start < raw.length() and raw.substr(value_start, 1) == " ":
		value_start += 1
	if value_start >= raw.length():
		return fallback
	if raw.substr(value_start, 1) == "\"":
		var value_end: int = raw.find("\"", value_start + 1)
		if value_end < 0:
			return fallback
		return raw.substr(value_start + 1, value_end - value_start - 1)
	var end: int = raw.find(",", value_start)
	if end < 0:
		end = raw.find("}", value_start)
	if end < 0:
		end = raw.length()
	return raw.substr(value_start, end - value_start).strip_edges()


func parse_original_object_number(raw: String, key: String, fallback: float = 0.0) -> float:
	var marker: String = key + ":"
	var start: int = raw.find(marker)
	if start < 0:
		return fallback
	var value_start: int = start + marker.length()
	var end: int = raw.find(",", value_start)
	if end < 0:
		end = raw.find("}", value_start)
	if end < 0:
		end = raw.length()
	var value_text: String = raw.substr(value_start, end - value_start).strip_edges()
	if value_text == "" or value_text.to_lower() == "null" or value_text.begins_with("{"):
		return fallback
	return float(value_text)


func update_original_move_target(delta: float) -> void:
	if not original_move_target_active:
		return
	if p1 == null or original_move_target_target == null or not is_instance_valid(original_move_target_target):
		clear_original_move_target_binding("target missing")
		return
	if not (original_move_target_target is Node2D):
		clear_original_move_target_binding("target not Node2D")
		return

	var target_node := original_move_target_target as Node2D
	var aim: Vector2 = get_original_move_target_aim()
	if original_move_target_has_speed:
		var step_x: float = original_move_target_speed_per_frame.x * ORIGINAL_GAME_RENDER_FPS * delta
		var step_y: float = original_move_target_speed_per_frame.y * ORIGINAL_GAME_RENDER_FPS * delta
		if step_x > 0.0:
			target_node.position.x = move_toward(target_node.position.x, aim.x, step_x)
		elif original_move_target_has_fixed_x or original_move_target_follow_mc_name != "":
			target_node.position.x = aim.x
		if step_y > 0.0:
			target_node.position.y = move_toward(target_node.position.y, aim.y, step_y)
		elif original_move_target_has_fixed_y or original_move_target_follow_mc_name != "":
			target_node.position.y = aim.y
	else:
		if original_move_target_has_fixed_x or original_move_target_follow_mc_name != "":
			target_node.position.x = aim.x
		if original_move_target_has_fixed_y or original_move_target_follow_mc_name != "":
			target_node.position.y = aim.y

	if target_node.has_method("set_air_state_from_position"):
		target_node.set_air_state_from_position()
	clamp_fighter_to_original_map_bounds(target_node)


func get_original_move_target_aim() -> Vector2:
	if p1 == null:
		return Vector2.ZERO
	if original_move_target_follow_mc_name == "move_mc":
		return p1.position + Vector2(ORIGINAL_THROW2_MOVE_MC_LOCAL_POS.x * float(p1.facing), ORIGINAL_THROW2_MOVE_MC_LOCAL_POS.y)
	var aim: Vector2 = Vector2.ZERO
	if original_move_target_has_fixed_x:
		aim.x = original_move_target_fixed_pos.x
	elif original_move_target_target != null and original_move_target_target is Node2D:
		aim.x = (original_move_target_target as Node2D).position.x
	if original_move_target_has_fixed_y:
		aim.y = original_move_target_fixed_pos.y
	elif original_move_target_target != null and original_move_target_target is Node2D:
		aim.y = (original_move_target_target as Node2D).position.y
	return aim


func clear_original_move_target_binding(reason: String = "") -> void:
	if not original_move_target_active and original_move_target_target == null:
		return
	var target_value: Variant = original_move_target_target
	original_move_target_active = false
	original_move_target_follow_mc_name = ""
	original_move_target_fixed_pos = Vector2.ZERO
	original_move_target_has_fixed_x = false
	original_move_target_has_fixed_y = false
	original_move_target_speed_per_frame = Vector2.ZERO
	original_move_target_has_speed = false
	original_move_target_target = null

	if target_value != null and is_instance_valid(target_value):
		if target_value.has_method("set_original_move_target_bound"):
			target_value.set_original_move_target_bound(false)
		elif target_value.has_method("set_apply_gravity_enabled"):
			target_value.set_apply_gravity_enabled(true)
		if target_value.has_method("set_air_state_from_position"):
			target_value.set_air_state_from_position()
		# MoveTargetParamVO.clear(): 如果目标仍在 HURT_FLYING，moveOnce(0,-5)。这里按 Godot 击飞状态近似对齐。
		if target_value.get("hurt_fly_state") != null and int(target_value.get("hurt_fly_state")) == 1 and target_value is Node2D:
			(target_value as Node2D).position.y -= 5.0
	print("原版 moveTarget 关闭 reason=", reason)



func is_original_world_position_locked(node) -> bool:
	# Step29：原版 U/招1 没有后撤位移。
	# Godot 里地面 skill1/skill2/skill3 会用 original_no_world_move_anchor_active 锁定 FighterMain 世界坐标；
	# 身体分离逻辑不能再把这个角色推出去，否则就会出现“先后撤再回位”的假后撤步。
	if node == null:
		return false
	if node.has_method("is_original_world_position_locked"):
		return bool(node.is_original_world_position_locked())
	var locked_value: Variant = node.get("original_no_world_move_anchor_active")
	if locked_value != null:
		return bool(locked_value)
	return false


func resolve_original_cross_collision() -> void:
	# 原版 FighterMain.isCross=false 时角色身体不能互相穿过；setCross(true) / moveTarget 抓取期间允许穿身。
	if p1 == null or p2 == null:
		return
	if not (p1 is Node2D) or not (p2 is Node2D):
		return
	if original_move_target_active:
		return
	var p1_cross: bool = bool(p1.get("is_cross")) if p1.get("is_cross") != null else false
	var p2_cross: bool = bool(p2.get("is_cross")) if p2.get("is_cross") != null else false
	if p1_cross or p2_cross:
		return

	# Step29：如果任一方正在执行“原版世界坐标锁定”的动作，禁止身体分离推开该角色。
	# 主要修复 U/招1：原版没有 move/movePercent/dash/moveToTarget，不能出现后撤再回位。
	if is_original_world_position_locked(p1) or is_original_world_position_locked(p2):
		return
	var n1 := p1 as Node2D
	var n2 := p2 as Node2D
	if absf(n1.position.y - n2.position.y) > 42.0:
		return
	var dx: float = n2.position.x - n1.position.x
	var dist: float = absf(dx)
	if dist <= 0.001:
		dx = 1.0
		dist = 1.0
	if dist >= ORIGINAL_FIGHTER_BODY_SEPARATION_X:
		return
	var push: float = (ORIGINAL_FIGHTER_BODY_SEPARATION_X - dist)
	var dir: float = 1.0 if dx > 0.0 else -1.0
	var p1_busy: bool = p1.has_method("is_busy") and bool(p1.is_busy())
	var p2_busy: bool = p2.has_method("is_busy") and bool(p2.is_busy())
	if p1_busy and not p2_busy:
		n2.position.x += dir * push
	elif p2_busy and not p1_busy:
		n1.position.x -= dir * push
	else:
		n1.position.x -= dir * push * 0.5
		n2.position.x += dir * push * 0.5
	clamp_fighter_to_original_map_bounds(n1)
	clamp_fighter_to_original_map_bounds(n2)

func get_original_catch_body_rect(node) -> Rect2:
	var pos: Vector2 = get_node_ground_pos(node, Vector2.ZERO)
	return Rect2(Vector2(pos.x - ORIGINAL_CATCH_BODY_WIDTH * 0.5, pos.y - ORIGINAL_CATCH_BODY_HEIGHT), Vector2(ORIGINAL_CATCH_BODY_WIDTH, ORIGINAL_CATCH_BODY_HEIGHT))


func is_original_target_hurt_ing(target) -> bool:
	if target == null:
		return false
	var action_name: String = str(target.get("current_action")) if target.get("current_action") != null else ""
	if action_name == "hurt" or action_name.begins_with("knock"):
		return true
	if target.get("in_hitstun") != null and bool(target.get("in_hitstun")):
		return true
	if target.get("hurt_fly_state") != null and int(target.get("hurt_fly_state")) != 0:
		return true
	return false


func is_original_true_catch_direction() -> bool:
	if p1 == null or p2 == null:
		return false
	var self_left_of_target: bool = p1.position.x < p2.position.x
	var move_right: bool = Input.is_key_pressed(KEY_D)
	var move_left: bool = Input.is_key_pressed(KEY_A)
	return (move_right and self_left_of_target and p1.facing == 1) or (move_left and (not self_left_of_target) and p1.facing == -1)


func allow_original_catch() -> bool:
	# 对齐 FighterMcCtrler.allowCatch()：目标不能处于 HURT_ING；body 贴边 disX < 2；脚底 y 差 < 1；方向必须朝向目标。
	if p1 == null or p2 == null:
		return false
	if is_original_target_hurt_ing(p2):
		return false
	if not is_original_true_catch_direction():
		return false

	var self_body: Rect2 = get_original_catch_body_rect(p1)
	var target_body: Rect2 = get_original_catch_body_rect(p2)
	var dis_x: float = 0.0
	if self_body.position.x < target_body.position.x:
		if p1.facing < 0:
			return false
		dis_x = target_body.position.x - (self_body.position.x + self_body.size.x)
	else:
		if p1.facing > 0:
			return false
		dis_x = self_body.position.x - (target_body.position.x + target_body.size.x)
	var dis_y: float = absf(p1.position.y - p2.position.y)
	return dis_x < ORIGINAL_CATCH_MAX_GAP_X and dis_y < ORIGINAL_CATCH_MAX_GAP_Y


func try_original_catch_input(action_name: String, catch_name: String) -> bool:
	if p1 == null or p2 == null:
		return false
	if not is_original_true_catch_direction():
		return false
	if not allow_original_catch():
		return false
	start_original_catch_action(action_name, catch_name)
	return true


func start_original_catch_action(action_name: String, catch_name: String) -> void:
	# FighterMcCtrler.doCatch(action)：allowCatch() 通过后 doAction(action)，actionState=SKILL_ING。
	original_catch_target = p2
	if p1.has_method("set_facing"):
		p1.set_facing(1 if p2.position.x >= p1.position.x else -1)
	p1.play_action(action_name)
	print("原版 doCatch 触发：", catch_name, " -> ", action_name, " target=", p2, " p1=", p1.position, " p2=", p2.position)


func clear_original_catch_target(reason: String = "") -> void:
	if original_catch_target == null:
		return
	if is_instance_valid(original_catch_target) and original_catch_target.has_method("set_original_caught_by_throw"):
		original_catch_target.set_original_caught_by_throw(false)
	original_catch_target = null
	print("原版 catch target 清理 reason=", reason)

func play_original_timeline_asset_sound(sound_id: String, action_name: String, relative_frame: int) -> void:
	# FighterEffectCtrler.playSoundHit1/2:
	#   playSoundHit1() -> SoundCtrler.playAssetSound("se_hit1")
	#   playSoundHit2() -> SoundCtrler.playAssetSound("se_hit2")
	var mp3_path: String = "res://assets/sfx/effect/" + sound_id + ".mp3"
	if ResourceLoader.exists(mp3_path) or FileAccess.file_exists(mp3_path):
		AudioManager.play_sfx(mp3_path)
	else:
		# 如果用户没有覆盖 mp3 资源，则回落到当前已导出的 effect hit 声音。
		if sound_id == "se_hit1":
			AudioManager.play_effect_sfx("snd_kan1")
		elif sound_id == "se_hit2":
			AudioManager.play_effect_sfx("snd_kan2")
	print("原版 timeline hit sound 触发 action=", action_name, " frame=", relative_frame, " sound=", sound_id)


func play_original_walk_sound(action_name: String, relative_frame: int) -> void:
	# FighterEffectCtrler.walk():
	#   非 ghostStep 时 playAssetSoundRandom("se_step1","se_step2","se_step3")
	var idx: int = 1 + int(randi() % 3)
	var sound_id: String = "se_step" + str(idx)
	var mp3_path: String = "res://assets/sfx/effect/" + sound_id + ".mp3"
	if ResourceLoader.exists(mp3_path) or FileAccess.file_exists(mp3_path):
		AudioManager.play_sfx(mp3_path, -8.0)
	else:
		print("原版 walk sound 缺资源：", sound_id)
	print("原版 walk sound 触发 action=", action_name, " frame=", relative_frame, " sound=", sound_id)


func play_original_slow_down_event(action_name: String, relative_frame: int, args: Array) -> void:
	# FighterEffectCtrler.slowDown(time) -> EffectCtrler.slowDown(1.5, time * 1000)。
	# EffectCtrler.slowDown(rate,time):
	#   GameCtrler.I.slow(rate)
	#   _renderAnimateGap = ceil(FPS_GAME / (30 / rate)) - 1
	#   _slowDownFrame = time * .001 * FPS_GAME；time==0 时不自动恢复。
	var time_sec: float = _raw_args_number(args, 0, 0.0)
	start_original_slow_down(ORIGINAL_SLOW_DEFAULT_RATE, time_sec)
	print("原版 slowDown 触发 action=", action_name, " frame=", relative_frame, " time=", time_sec, " rate=", ORIGINAL_SLOW_DEFAULT_RATE)


func play_original_slow_down_resume_event(action_name: String, relative_frame: int) -> void:
	resume_original_slow_down()
	print("原版 slowDownResume 触发 action=", action_name, " frame=", relative_frame)


func start_original_slow_down(rate: float, time_sec: float) -> void:
	var safe_rate: float = maxf(0.001, rate)
	original_slow_active = true
	original_slow_rate = safe_rate
	original_slow_has_auto_resume = time_sec > 0.0
	original_slow_time_left = maxf(0.0, time_sec)
	apply_original_slow_runtime()


func resume_original_slow_down() -> void:
	if not original_slow_active and original_slow_rate == 1.0:
		return
	original_slow_active = false
	original_slow_rate = 1.0
	original_slow_time_left = 0.0
	original_slow_has_auto_resume = false
	apply_original_slow_runtime()


func update_original_slow_down(delta: float) -> void:
	# 原版 renderSlowDown() 每真实帧递减 _slowDownFrame，慢放自身不再被慢放。
	if not original_slow_active:
		return
	if not original_slow_has_auto_resume:
		return
	original_slow_time_left -= delta
	if original_slow_time_left <= 0.0:
		resume_original_slow_down()


func get_original_slow_time_scale() -> float:
	if not original_slow_active:
		return 1.0
	return 1.0 / maxf(0.001, original_slow_rate)


func apply_original_slow_runtime() -> void:
	var slow_scale: float = get_original_slow_time_scale()
	_set_original_time_scale_on_node(p1, slow_scale)
	_set_original_time_scale_on_node(p2, slow_scale)
	_set_original_time_scale_on_node(p1_effect, slow_scale)
	_set_original_time_scale_on_node(common_effects, slow_scale)
	_set_original_time_scale_on_node(shadow_effects, slow_scale)
	_set_original_time_scale_on_node(bisha_effect, slow_scale)
	print("原版 GameCtrler.slow runtime scale=", slow_scale, " rate=", original_slow_rate, " active=", original_slow_active)


func _set_original_time_scale_on_node(node_value: Variant, slow_scale: float) -> void:
	if node_value == null:
		return
	if not (node_value is Node):
		return
	var n: Node = node_value as Node
	if n.has_method("set_original_time_scale"):
		n.call("set_original_time_scale", slow_scale)


func move_p1_once_by_original_args(action_name: String, relative_frame: int, args: Array) -> void:
	# FighterCtrler.moveOnce(x,y): fighter.x += x * direct; fighter.y += y
	if p1 == null:
		return
	var dx: float = _raw_args_number(args, 0, 0.0)
	var dy: float = _raw_args_number(args, 1, 0.0)
	p1.position.x += dx * float(p1.facing)
	p1.position.y += dy
	clamp_fighter_to_original_map_bounds(p1)
	if p1.has_method("set_air_state_from_position"):
		p1.set_air_state_from_position()
	print("原版 moveOnce 触发 action=", action_name, " frame=", relative_frame, " delta=", Vector2(dx, dy), " new_pos=", p1.position)


func face_p1_current_target(action_name: String, relative_frame: int) -> void:
	# FighterCtrler.setDirectToTarget(): fighter.direct = fighter.x > target.x ? -1 : 1
	if p1 == null or p2 == null:
		return
	if p1.has_method("set_facing"):
		p1.set_facing(-1 if p1.position.x > get_p1_target_ground_pos().x else 1)
	print("原版 setDirectToTarget 触发 action=", action_name, " frame=", relative_frame, " facing=", p1.facing)


func set_p1_cross_enabled(enabled: bool, action_name: String, relative_frame: int) -> void:
	# FighterCtrler.setCross(v): _fighter.isCross = v
	if p1 == null:
		return
	if p1.has_method("set_cross_enabled"):
		p1.set_cross_enabled(enabled)
	else:
		p1.set_meta("original_is_cross", enabled)
	print("原版 setCross 触发 action=", action_name, " frame=", relative_frame, " enabled=", enabled)


func handle_original_just_hit_to_play(action_name: String, relative_frame: int, semantic: Dictionary) -> void:
	# FighterMcCtrler.justHitToPlay(hitId, label, returnIdleOnFail, continueWhenDefended)
	# 蓝染上必杀使用：justHitToPlay("sbs1", "上必杀_HIT", false, false)
	var attack_id: String = str(semantic.get("attack_id", ""))
	var target_label: String = str(semantic.get("target_label", ""))
	var return_idle_on_fail: bool = semantic.get("return_idle_on_fail", false) == true
	var target_action: String = map_original_label_to_action(target_label)
	if target_action == "":
		target_action = target_label

	var matched: bool = attack_id != "" and p1_last_hit_vo_id == attack_id and p1_last_hit_action == action_name
	print("原版 justHitToPlay 检查 action=", action_name, " frame=", relative_frame, " attack_id=", attack_id, " last=", p1_last_hit_vo_id, "/", p1_last_hit_action, " matched=", matched, " target=", target_action)

	if matched and target_action != "" and p1 != null:
		p1.play_action(target_action)
		p1_last_hit_vo_id = ""
		p1_last_hit_action = ""
	elif return_idle_on_fail and p1 != null and p1.has_method("return_to_neutral_from_timeline"):
		p1.return_to_neutral_from_timeline()


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
		var s: String = str(value).strip_edges().to_lower()
		return s != "" and s != "null" and s != "nan"
	return true


func _original_args_number(args: Array, index: int, fallback: float = 0.0) -> float:
	if index < 0 or index >= args.size():
		return fallback
	return _nullable_number_to_float(args[index], fallback)


func _raw_args_number(args: Array, index: int, fallback: float = 0.0) -> float:
	# raw call 处理和 semantic 处理共用同一套 null/NaN 数值规则。
	return _original_args_number(args, index, fallback)


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
	var dash_effect_origin: Vector2 = get_p1_original_dash_dust_origin()
	if common_effects != null and common_effects.has_method("play_dash_effect"):
		common_effects.play_dash_effect(dash_effect_origin, p1.facing, is_air)
		print("原版 dash effect 触发 action=", action_name, " frame=", relative_frame, " effect=", effect_id)
	elif _common_effect_exists(effect_id):
		common_effects.play_effect(effect_id, dash_effect_origin, p1.facing, 1.0, false)
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
	var method_name: String = str(semantic.get("method", ""))
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
	var method_name: String = str(semantic.get("method", ""))
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



func get_original_swf_effect_origin(node: Variant, fallback_pos: Vector2) -> Vector2:
	# 原版 SWF 的 EffectCtrler / addAttacker 使用 FighterMain.x/y 注册点。
	# 当前 Godot ManifestFighter.position 不是这个注册点，而是 centered PNG 的节点原点。
	# Step26 用 mc_023 idle 的真实人物底部 Matrix 反推注册点，避免 Step25 直接对齐脚底导致特效过低。
	var pos: Vector2 = get_node_ground_pos(node, fallback_pos)
	return Vector2(pos.x, pos.y + ORIGINAL_SWF_EFFECT_Y_FROM_GODOT_ORIGIN)


func get_p1_original_effect_origin() -> Vector2:
	return get_original_swf_effect_origin(p1, P1_START_POS)


func get_p1_original_dash_dust_origin() -> Vector2:
	# 原版 FighterEffectCtrler.dash() 在 fighter.x / fighter.y 播放 XG_rush；
	# 当前导出的 XG_rush 是 800x600 画布，烟尘 bbox 底部约为纹理中心 +7px。
	# 因此用 Godot 人物脚底 -7px 作为 EffectPlayer 节点 y，使烟尘底边与脚底持平。
	var pos: Vector2 = get_node_ground_pos(p1, P1_START_POS)
	return Vector2(pos.x, pos.y + ORIGINAL_DASH_EFFECT_Y_FROM_GODOT_ORIGIN)


func get_p2_original_effect_origin() -> Vector2:
	return get_original_swf_effect_origin(p2, P2_START_POS)


func get_p1_target_original_effect_origin() -> Vector2:
	# 当前 Demo 只有 P2 作为 currentTarget。
	return get_p2_original_effect_origin()


func get_original_swf_effect_hit_rect(hit_rect: Rect2) -> Rect2:
	# 只修正视觉特效高度；不改变 current_attack_world_rect / 碰撞判定。
	return Rect2(hit_rect.position + Vector2(0.0, ORIGINAL_HIT_EFFECT_VISUAL_Y_CORRECTION), hit_rect.size)


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



func align_original_skill_effect_height(effect_name: String, origin: Vector2, reference_ground: Vector2, target_offset: Vector2 = Vector2.ZERO) -> Vector2:
	# Step22-24：技能特效高度严格按原版 SWF 时间轴的世界 y 语义对齐。
	# bsmc: addAttacker("bsmc", {y:{followTarget:true, offset:-25}}) -> currentTarget.y - 25。
	# zh3mc: addAttacker("zh3mc", {applyG:false}) -> 创建时以施放者 fighter 原点为 y。
	# bisha: 仍由 super_effect_start 中 world_to_screen(p1.position + Vector2(0,-50)) 处理。
	var aligned: Vector2 = origin
	match effect_name:
		"bsmc":
			aligned.y = reference_ground.y + target_offset.y
		"zh3mc":
			aligned.y = reference_ground.y + target_offset.y
		_:
			pass
	return aligned

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
	var target_origin: Vector2 = get_p1_target_original_effect_origin()
	active_attacker_original_origin = align_original_skill_effect_height(effect_name, target_origin + target_offset, target_origin, target_offset)
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
	var caster_origin: Vector2 = get_p1_original_effect_origin()
	active_attacker_original_origin = align_original_skill_effect_height(effect_name, caster_origin + self_offset, caster_origin, self_offset)
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
	var target_origin: Vector2 = get_p1_target_original_effect_origin()
	active_attacker_original_origin = align_original_skill_effect_height(active_attacker_effect_name, target_origin + active_attacker_offset, target_origin, active_attacker_offset)
	p1_effect.position = _attacker_visual_position_from_origin()
