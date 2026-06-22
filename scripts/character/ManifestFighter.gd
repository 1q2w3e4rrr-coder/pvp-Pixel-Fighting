extends Node2D

signal frame_event(action_name: String, event_data: Dictionary)
signal action_finished(action_name: String)

var sprite: Sprite2D

var manifest_path: String = ""
var manifest: Dictionary = {}

var current_action: String = "idle"
var frame_index: int = 0
var frame_timer: float = 0.0
var fps: float = 30.0

var facing: int = 1

var ground_y: float = 350.0
var velocity_y: float = 0.0
var gravity: float = 1350.0
var jump_speed: float = -620.0
var in_air: bool = false

# 原版 FighterMain.as: jumpTimes=2, airHitTimes=1。
# FighterMcCtrler.doJump / doAirJump 每次真正起跳会让 jumpTimes--；
# doAirAttack / doAirSkill / doAirBisha / doDashAir 会把 jumpTimes 清零。
var original_jump_times_max: int = 2
var original_jump_times_left: int = 2
var original_air_hit_times_max: int = 1
var original_air_hit_times_left: int = 1

var action_locked: bool = false
var fired_event_keys: Dictionary = {}

# Step44：保留 Step43 的原版 HP / qi / energy / HitVO 伤害公式。
# fzqi 辅助气条暂时回退到上个可用版本：当前 Demo 不做 O 支援/换人，避免 HUD 下方出现额外 fzqibar/readymc。
# 依据：GameConfig.FIGHTER_HP_MAX=1000；FighterTester.as 里 fighterHP=2，所以当前 Demo 初始 HP=2000。
# HitVO.getDamage：damage = (power + power * powerAdd / 100) * powerRate。
var hp_max: float = 2000.0
var hp: float = 2000.0
var is_alive: bool = true

# 原版 FighterMain：qi 用于普通必杀/上必杀/空中必杀 100，超必杀 300；初始 qi=0。
var qi: float = 0.0
var qi_max: float = 300.0
# 当前项目按你的要求忽略 O 支援/换人；fzqi 不强行填满，避免显示辅助气条多余部件。
var fzqi: float = 0.0
var fzqi_max: float = 100.0
var energy: float = 100.0
var energy_max: float = 100.0
var energy_overload: bool = false
var energy_add_gap: float = 0.0

# 防御命中/破防的最小实现。原版防御时受击会扣少量 HP、消耗 energy，并短暂停住。
var defense_hold_timer: float = 0.0
var defense_hit_timer: float = 0.0

var velocity_x: float = 0.0
var damping_x: float = 0.0
var hurt_timer: float = 0.0
var in_hitstun: bool = false

# 原版 FighterMain.isAllowBeHit / FighterMcCtrler._beHitGap。
# 受击、防御、钢体命中后会短暂禁止再次被命中，之后按 _beHitGap 恢复。
var is_allow_be_hit: bool = true
var be_hit_gap_timer: float = 0.0

# 原版 FighterMC.playHurtFly / renderHurtFly 的最小状态机。
# 0=无击飞；1=击飞中；2=落地过渡“击飞_落”；3=弹起“击飞_弹”；4=倒地等待起身。
var hurt_fly_state: int = 0
var hurt_fly_delay_timer: float = 0.0
var hurt_fall_timer: float = 0.0
var hurt_down_timer: float = 0.0
var hurt_y_min: float = 0.0
var hurt_is_heavy_down_attack: bool = false
var hurt_fly_hitx: float = 0.0
var hurt_fly_hity: float = 0.0

# 原版 setHurtAction：当前动作被打时不进入普通受击，而是转入指定反击动作。
var original_hurt_action: String = ""
# 原版 FighterMcCtrler.setSteelBody(v, isSuper)：钢体/霸体状态。
# 普通钢体被打时不打断当前动作，按 doSteelHurt 扣 65% 伤害并耗 energy；
# superSteelBody 扣 30% 伤害。遇到必杀/抓取/energyOverLoad 时普通钢体会退回 doHurt。
var is_steel_body: bool = false
var is_super_steel_body: bool = false
var apply_gravity_enabled: bool = true
var is_cross: bool = false
var original_air_move_enabled: bool = false
var original_animation_stopped: bool = false
var original_time_scale: float = 1.0
var original_move_target_bound: bool = false
var original_caught_by_throw: bool = false
# Step27：原版 U/招1 时间轴没有 move / movePercent / dash；为避免 Godot 残留速度或碰撞分离造成“先后撤再回来”，
# 对地面 skill1/skill2/skill3 做动作期间世界坐标锁定。
var original_no_world_move_anchor_active: bool = false
var original_no_world_move_anchor_pos: Vector2 = Vector2.ZERO
# Step19：原版防御/破防审计状态。
var original_last_hit_result: String = ""
var original_last_damage_taken: float = 0.0
# Step67：原版 KO 后败者进入 DEAD，停在击飞_倒，不再自动起身。
var original_round_end_dead_lock: bool = false
var original_round_end_dead_announced: bool = false
# Step68：记录 KO 最后一击攻击者朝向，用于普通受击死亡后继续按原版 hurtFly / playHurtDown 方向处理。
var original_round_end_attacker_facing: int = 1
# Step70：胜利动作是回合结束展示动作，原版 GameEndCtrl 调 winner.win() 后不会再把世界坐标交给移动/碰撞分离。
var original_round_end_winner_hold_lock: bool = false
var original_round_end_winner_hold_position: Vector2 = Vector2.ZERO
var original_guard_break_timer: float = 0.0
var original_can_hurt_break_timer: float = 0.0

# Step49：原版 EffectModel.shock_ing = xg_dian_ing，并由 SpecialEffectView 对目标执行
# targetColorOffset [50, -75, 255]。Godot 侧用 Sprite2D ShaderMaterial 做颜色 offset，
# 避免用普通 modulate 乘色替代。
var original_special_color_active: bool = false
var original_special_color_time_left: float = 0.0
var original_special_color_material: ShaderMaterial
var original_special_color_previous_material: Material

const ORIGINAL_FPS := 30.0
const ORIGINAL_GAME_RENDER_FPS := 60.0
const ORIGINAL_FIGHTER_SPEED_PER_FRAME := 6.0
const HURT_FRAME_OFFSET := 3
const HIT_SPEED_SCALE := 30.0
const DEFENSE_LOSE_HP_RATE := 0.05
const STEEL_BODY_DAMAGE_RATE := 0.65
const SUPER_STEEL_BODY_DAMAGE_RATE := 0.30
const STEEL_BODY_ENERGY_RATE := 0.40
const STEEL_BODY_BREAK_DEF_ENERGY_RATE := 1.00
const SUPER_STEEL_BODY_ENERGY_RATE := 0.20
const ENERGY_ADD_NORMAL_PER_FRAME := 2.0
const ENERGY_ADD_DEFENSE_PER_FRAME := 0.8
const ENERGY_ADD_ATTACKING_PER_FRAME := 1.1
const ENERGY_ADD_OVERLOAD_PER_FRAME := 0.6
const USE_ENERGY_CD := 0.8
const ENERGY_ADD_OVERLOAD_RESUME := 30.0


func setup(path: String) -> void:
	manifest_path = path
	ensure_sprite()
	load_manifest()
	play_action("idle")


func ensure_sprite() -> void:
	if sprite != null:
		return

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func load_manifest() -> void:
	var file := FileAccess.open(manifest_path, FileAccess.READ)

	if file == null:
		push_error("Cannot open manifest: " + manifest_path)
		return

	var text := file.get_as_text()
	var data: Variant = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("Manifest parse failed: " + manifest_path)
		return

	manifest = data
	print("Loaded fighter manifest:", manifest_path)


func play_action(action_name: String) -> void:
	if not manifest.has("actions"):
		return

	if not manifest["actions"].has(action_name):
		print("Action not found:", action_name)
		return

	# Step67：胜利/倒地属于回合结束展示状态。原版 FighterMain.resumeColor()/Bitmap 渲染不会把
	# 前一次 shock_ing ColorTransform 或其他临时材质带进胜利帧；否则透明边缘会被错误显示成黑边。
	if action_name == "win" or action_name == "knock_down" or action_name == "knock_fall" or action_name == "knock_bounce" or action_name == "lose":
		resume_original_special_color()
		if sprite != null:
			sprite.material = null
			sprite.modulate = Color.WHITE

	# Step27/Step53：原版 mc_023 的 招1/招2/招3 没有根移动；超必杀也没有 move/moveToTarget 事件。
	# Step70：win 是 GameEndCtrl 的展示动作，也不应再被玩家移动、剩余 velocity 或碰撞分离改变世界坐标。
	# W+I / 空中 I 仍由原版 moveToTarget 事件控制，不在这里锁死。
	original_no_world_move_anchor_active = false
	if action_name != "win":
		original_round_end_winner_hold_lock = false
	if action_name == "win":
		resume_original_special_color()
		if sprite != null:
			sprite.material = null
			sprite.modulate = Color.WHITE
			sprite.self_modulate = Color.WHITE
		velocity_x = 0.0
		damping_x = 0.0
		velocity_y = 0.0
		original_no_world_move_anchor_active = true
		original_no_world_move_anchor_pos = position
		original_round_end_winner_hold_lock = true
		original_round_end_winner_hold_position = position
	if action_name == "skill1" or action_name == "skill2" or action_name == "skill3" or action_name == "super_special":
		velocity_x = 0.0
		damping_x = 0.0
		if not in_air:
			velocity_y = 0.0
			original_no_world_move_anchor_active = true
			original_no_world_move_anchor_pos = position
	elif action_name.begins_with("super"):
		# 普通 I / W+I / 空中 I 进入必杀时先清掉玩家自由移动残留，后续位移只接受时间轴 moveToTarget。
		velocity_x = 0.0
		damping_x = 0.0

	current_action = action_name
	frame_index = 0
	frame_timer = 0.0
	original_animation_stopped = false
	fired_event_keys.clear()
	original_hurt_action = ""

	var action: Dictionary = manifest["actions"][current_action]
	fps = float(action.get("fps", 30))

	action_locked = not bool(action.get("loop", false))
	if action_name != "super_air":
		apply_gravity_enabled = true

	update_frame()
	emit_events_for_current_frame()


func is_busy() -> bool:
	return action_locked or in_hitstun


func is_grounded() -> bool:
	return not in_air


func can_ground_action() -> bool:
	return is_grounded() and not is_busy()


func can_air_action() -> bool:
	return in_air and not is_busy()


func can_original_air_action() -> bool:
	# 原版 FighterMcCtrler.doAirAttack/doAirSkill/doAirBisha：
	# if (_doingAction == null && _action.airHitTimes <= 0) return;
	# 跳跃/下落本身不应因为 Godot action_locked 而阻止空中 J/U/I。
	return in_air and not in_hitstun and original_air_hit_times_left > 0


func can_original_air_mobility() -> bool:
	# 原版 renderAirAction：doAirJump/doDashAir/doAirMove 在空中动作流程中处理；
	# 不能因为 jump/fall 的 PNG 动作 locked 就完全禁止。
	return in_air and not in_hitstun


func set_facing(new_facing: int) -> void:
	facing = new_facing

	if sprite != null:
		sprite.flip_h = facing < 0


func start_jump() -> void:
	# 原版 FighterMcCtrler：地面 doJump 与空中 doAirJump 共用 jumpTimes。
	# FighterMain.jumpTimes=2，因此 K 后在空中还能再 K 一次。
	# 注意：空中二段跳不能被 jump/fall 的 action_locked 阻止。
	if in_air:
		start_original_air_jump()
		return

	if is_busy():
		return

	in_air = true
	original_jump_times_left = max(0, original_jump_times_max - 1)
	velocity_y = jump_speed
	apply_gravity_enabled = true
	play_action("jump_start")


func start_original_air_jump() -> void:
	if not in_air:
		return
	if original_jump_times_left <= 0:
		return
	if in_hitstun:
		return

	original_jump_times_left -= 1
	velocity_y = jump_speed
	apply_gravity_enabled = true
	play_action("jump")


func can_original_air_dash() -> bool:
	# 原版 doDashAir：if (_action.jumpTimes < 1) return; energy=30; jumpTimes=0。
	# 不能因为 jump/fall 的 action_locked 阻止空中瞬步。
	return in_air and original_jump_times_left >= 1 and not in_hitstun


func try_start_original_air_dash() -> bool:
	if not can_original_air_dash():
		return false
	original_jump_times_left = 0
	velocity_x = 0.0
	damping_x = 0.0
	velocity_y = 0.0
	play_action("dash")
	apply_gravity_enabled = false
	return true


func consume_original_air_action_limits() -> void:
	# 原版 doAirAttack / doAirSkill / doAirBisha 会消耗空中攻击次数并清空 jumpTimes。
	original_air_hit_times_left = 0
	original_jump_times_left = 0


func start_air_attack() -> void:
	if not can_original_air_action():
		return

	original_air_hit_times_left -= 1
	original_jump_times_left = 0
	play_action("jump_attack")


func _process(delta: float) -> void:
	var scaled_delta: float = delta * original_time_scale
	update_energy(scaled_delta)
	update_defense_hold(scaled_delta)
	update_be_hit_gap(scaled_delta)
	update_original_guard_break_timer(scaled_delta)
	update_original_can_hurt_break_timer(scaled_delta)
	update_hurt_timer(scaled_delta)
	update_hurt_fly_state(scaled_delta)
	update_original_special_color(scaled_delta)
	update_animation(scaled_delta)
	update_physics(scaled_delta)
	update_horizontal_motion(scaled_delta)
	apply_original_no_world_move_anchor()


func apply_original_special_color_offset(offset: Vector3, min_time: float = 0.40) -> void:
	# 对照原版 SpecialEffectView.setTarget：把 EffectVO.targetColorOffset 写到目标 FighterMain 的 ColorTransform。
	# 这里 offset 仍使用原版 0..255 的 red/green/blue offset。
	ensure_sprite()
	if original_special_color_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform vec3 color_offset = vec3(0.0, 0.0, 0.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a > 0.0) {
		tex.rgb = clamp(tex.rgb + color_offset, vec3(0.0), vec3(1.0));
	}
	COLOR = tex;
}
"""
		original_special_color_material = ShaderMaterial.new()
		original_special_color_material.shader = shader

	if not original_special_color_active:
		original_special_color_previous_material = sprite.material

	original_special_color_active = true
	original_special_color_time_left = maxf(original_special_color_time_left, min_time)
	original_special_color_material.set_shader_parameter(
		"color_offset",
		Vector3(offset.x / 255.0, offset.y / 255.0, offset.z / 255.0)
	)
	sprite.material = original_special_color_material


func resume_original_special_color() -> void:
	if not original_special_color_active:
		return
	original_special_color_active = false
	original_special_color_time_left = 0.0
	if sprite != null:
		sprite.material = original_special_color_previous_material
	original_special_color_previous_material = null


func update_original_special_color(delta: float) -> void:
	if not original_special_color_active:
		return

	if original_special_color_time_left > 0.0:
		original_special_color_time_left -= delta
		if original_special_color_time_left > 0.0:
			return

	# Step61：一比一修复 P2 Num4 / 招1 命中 P1 后紫色 ColorTransform 永久残留。
	# 原版依据：SpecialEffectView.as::render()
	#   switch (_fighter.actionState) {
	#     HURT_DOWN / HURT_DOWN_TAN / NORMAL:
	#       gotoAndPlay("finish");
	#       _fighter.resumeColor();
	#       break;
	#     default:
	#       setPos(_fighter.x, _fighter.y);
	#   }
	# 也就是说，原版不是等角色动作名必须回到 idle/walk 才恢复颜色，
	# 而是目标脱离 HURT_ING / HURT_FLYING 后进入 NORMAL 或倒地态就恢复。
	# 当前 Godot 旧逻辑只允许 idle/walk/jump/fall 恢复，P2 打 P1 后 P1 可能停在 hurt/defend_recover 等动作名，
	# 导致 shader ColorTransform 一直不被清理。
	if is_original_special_effect_finish_state():
		resume_original_special_color()


func is_original_special_effect_finish_state() -> bool:
	# 原版 NORMAL 在 FighterActionState 中是“非受击流程”的广义状态，不能简单等价为 current_action == idle。
	# 当前复刻中只要普通受击硬直结束、击飞状态结束，就等价于可恢复 ColorTransform。
	if not in_hitstun and hurt_fly_state == 0:
		return true

	# 原版 HURT_DOWN / HURT_DOWN_TAN 也会立即恢复颜色；Godot 侧这些状态对应 knock_down/getup/land 一类动作。
	if current_action == "knock_down" or current_action == "getup" or current_action == "land":
		return true

	return false


func apply_original_no_world_move_anchor() -> void:
	if not original_no_world_move_anchor_active:
		return
	if in_air:
		original_no_world_move_anchor_active = false
		return
	# 只锁原版无根移动的地面技能/超必杀 FighterMain 世界坐标；动作本身的帧动画仍正常播放。
	if current_action != "skill1" and current_action != "skill2" and current_action != "skill3" and current_action != "super_special" and current_action != "win":
		original_no_world_move_anchor_active = false
		return
	if current_action == "win" and original_round_end_winner_hold_lock:
		position = original_round_end_winner_hold_position
	else:
		position = original_no_world_move_anchor_pos
	velocity_x = 0.0
	damping_x = 0.0
	velocity_y = 0.0


func is_original_world_position_locked() -> bool:
	return original_no_world_move_anchor_active


func update_animation(delta: float) -> void:
	if original_animation_stopped:
		return

	if not manifest.has("actions"):
		return

	if not manifest["actions"].has(current_action):
		return

	var action: Dictionary = manifest["actions"][current_action]
	var frames: Array = action.get("frames", [])

	if frames.is_empty():
		return

	# 受击硬直没结束时，普通“被打”动作停在最后一帧，避免提前回 idle。
	if in_hitstun and current_action == "hurt" and frame_index >= frames.size() - 1:
		return

	frame_timer += delta
	var frame_duration: float = 1.0 / fps

	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		frame_index += 1

		if frame_index >= frames.size():
			handle_action_finished()
			return

		update_frame()
		emit_events_for_current_frame()


func emit_events_for_current_frame() -> void:
	if not manifest.has("actions"):
		return

	if not manifest["actions"].has(current_action):
		return

	var action: Dictionary = manifest["actions"][current_action]
	var events: Array = action.get("events", [])

	for i in range(events.size()):
		var event_data: Dictionary = events[i]
		var relative_frame: int = int(event_data.get("relative_frame", -999))

		if relative_frame != frame_index:
			continue

		var key: String = current_action + ":" + str(frame_index) + ":" + str(i)

		if fired_event_keys.has(key):
			continue

		fired_event_keys[key] = true
		frame_event.emit(current_action, event_data)


func return_to_neutral_from_timeline() -> void:
	# 对应原版 parent.$mc_ctrler.idle();
	# 注意：如果人在空中，原版 idle() 不会硬切站立，而是进入下落/跳跃状态。
	action_locked = false
	apply_gravity_enabled = true
	clear_original_timeline_states()
	if in_air:
		if velocity_y < 0:
			play_action("jump")
		else:
			play_action("fall")
	else:
		play_action("idle")


func handle_action_finished() -> void:
	var finished_action: String = current_action

	if in_hitstun and finished_action == "hurt":
		var action: Dictionary = manifest["actions"].get(current_action, {})
		var frames: Array = action.get("frames", [])
		frame_index = max(0, frames.size() - 1)
		frame_timer = 0.0
		update_frame()
		return

	action_locked = false
	apply_gravity_enabled = true
	action_finished.emit(finished_action)

	if finished_action == "jump_start":
		if in_air:
			play_action("jump")
		else:
			play_action("idle")
		return

	# 原版 Flash 从“砍4”会自然继续播放到后面的“砍4_QK”标签。
	# 当前 PNG manifest 是按标签切开的，所以这里显式补上连续播放。
	if finished_action == "atk4":
		play_action("atk4_extra")
		return

	if finished_action == "jump_attack":
		if in_air:
			play_action("fall")
		else:
			play_action("idle")
		return

	if finished_action == "win":
		# 原版 GameEndCtrl 调用 winner.win() 后保持胜利动作展示，
		# 不会在结算菜单弹出前自动回到 idle，也不会继续移动世界坐标。
		_hold_last_frame()
		velocity_x = 0.0
		damping_x = 0.0
		velocity_y = 0.0
		original_no_world_move_anchor_active = true
		original_no_world_move_anchor_pos = original_round_end_winner_hold_position if original_round_end_winner_hold_lock else position
		original_round_end_winner_hold_lock = true
		original_round_end_winner_hold_position = original_no_world_move_anchor_pos
		action_locked = true
		original_animation_stopped = true
		if sprite != null:
			sprite.material = null
			sprite.modulate = Color.WHITE
			sprite.self_modulate = Color.WHITE
		return

	if finished_action == "knock_fly":
		# 击飞动画由 update_hurt_fly_state() 按原版 playHurtFly/renderHurtFly 状态机驱动。
		_hold_last_frame()
		return

	if finished_action == "knock_fall":
		_hold_last_frame()
		return

	if finished_action == "knock_bounce":
		_hold_last_frame()
		return

	if finished_action == "knock_down":
		# 原版倒地会保留一段 _hurtDownFrame 后才播放“击飞_起”。
		_hold_last_frame()
		return

	if finished_action == "getup":
		_clear_hurt_state()
		play_action("idle")
		return

	if finished_action == "land":
		play_action("idle")
		return

	if in_air:
		if velocity_y < 0:
			play_action("jump")
		else:
			play_action("fall")
	else:
		play_action("idle")


func update_physics(delta: float) -> void:
	if original_move_target_bound:
		velocity_y = 0.0
		return

	if not in_air:
		return

	position.y += velocity_y * delta
	if apply_gravity_enabled:
		velocity_y += gravity * delta

	if velocity_y >= 0 and current_action == "jump":
		play_action("fall")

	if position.y >= ground_y:
		position.y = ground_y
		velocity_y = 0.0
		in_air = false
		original_jump_times_left = original_jump_times_max
		original_air_hit_times_left = original_air_hit_times_max

		if hurt_fly_state == 1:
			# 原版 renderHurtFly state1：落地后进入“击飞_落”。
			_start_hurt_fall_stage()
		elif hurt_fly_state == 3:
			# 原版 state3：弹起后再次落地进入“击飞_倒”。
			_start_hurt_down_stage(15)
		elif current_action != "land" and not in_hitstun:
			play_action("land")


func update_hurt_timer(delta: float) -> void:
	if not in_hitstun:
		return

	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer > 0.0:
			return

	# hurtType=0 的普通硬直结束后恢复；击飞流程由 update_hurt_fly_state() 处理。
	# Step68：若这次普通硬直已经把 HP 打到 0，原版 renderHurtAnimate 不会恢复 idle，
	# 而是：空中 -> hurtFly(vec.x, vec.y)；地面 -> playHurtDown()，最终停在 DEAD/击飞_倒。
	if current_action == "hurt" and hurt_fly_state == 0:
		if original_round_end_dead_lock or not is_alive:
			if in_air:
				_continue_original_dead_hurt_fly_from_current_velocity()
			else:
				_start_original_dead_hurt_down_tan()
			return
		_clear_hurt_state()
		if in_air:
			play_action("fall")
		else:
			play_action("idle")


func update_be_hit_gap(delta: float) -> void:
	if be_hit_gap_timer <= 0.0:
		return
	be_hit_gap_timer -= delta
	if be_hit_gap_timer <= 0.0:
		be_hit_gap_timer = 0.0
		is_allow_be_hit = true


func update_original_guard_break_timer(delta: float) -> void:
	if original_guard_break_timer <= 0.0:
		return
	original_guard_break_timer = maxf(0.0, original_guard_break_timer - delta)


func update_original_can_hurt_break_timer(delta: float) -> void:
	if original_can_hurt_break_timer <= 0.0:
		return
	original_can_hurt_break_timer = maxf(0.0, original_can_hurt_break_timer - delta)


func _set_be_hit_gap(frames: int) -> void:
	is_allow_be_hit = false
	be_hit_gap_timer = maxf(be_hit_gap_timer, float(frames) / ORIGINAL_FPS)


func _hold_last_frame() -> void:
	if not manifest.has("actions") or not manifest["actions"].has(current_action):
		return
	var action: Dictionary = manifest["actions"].get(current_action, {})
	var frames: Array = action.get("frames", [])
	if frames.is_empty():
		return
	frame_index = max(0, frames.size() - 1)
	frame_timer = 0.0
	update_frame()


func _clear_hurt_state() -> void:
	in_hitstun = false
	action_locked = false
	hurt_timer = 0.0
	hurt_fly_state = 0
	hurt_fly_delay_timer = 0.0
	hurt_fall_timer = 0.0
	hurt_down_timer = 0.0
	is_allow_be_hit = true
	be_hit_gap_timer = 0.0
	velocity_x = 0.0
	damping_x = 0.0
	if is_alive:
		original_round_end_dead_lock = false
		original_round_end_dead_announced = false
	if not in_air:
		velocity_y = 0.0


func _start_original_hurt_fly(hitx: float, hity: float) -> void:
	# 对照 FighterMC.playHurtFly(hitx, hity, showBeHit=true)：
	# 先显示“被打”，延迟 1 帧后进入“击飞”；hity>5 时为重下砸，落地后直接倒地。
	if hitx != 0.0:
		set_facing(-1 if hitx > 0.0 else 1)

	hurt_fly_state = 1
	hurt_fly_delay_timer = 1.0 / ORIGINAL_FPS
	hurt_fall_timer = 0.0
	hurt_down_timer = 0.0
	hurt_y_min = position.y
	hurt_fly_hitx = hitx
	hurt_fly_hity = hity
	hurt_is_heavy_down_attack = hity > 5.0

	velocity_x = hitx * HIT_SPEED_SCALE
	velocity_y = hity * HIT_SPEED_SCALE
	damping_x = 0.0
	in_air = true
	in_hitstun = true
	action_locked = true
	apply_gravity_enabled = true
	play_action("hurt")


func _continue_original_dead_hurt_fly_from_current_velocity() -> void:
	# 原版 FighterMcCtrler.renderHurtAnimate：若非存活且仍在空中，取当前 vec2 调 hurtFly(vec.x, vec.y)。
	# 这里把 Godot px/s 速度还原成原版近似 hitx/hity，再直接进入 knock_fly，不再重复播放“被打”起手。
	var hitx: float = velocity_x / HIT_SPEED_SCALE
	var hity: float = velocity_y / HIT_SPEED_SCALE
	if absf(hitx) < 0.1:
		hitx = 7.0 * float(original_round_end_attacker_facing)
	if absf(hity) < 0.1:
		hity = -6.0
	if hitx != 0.0:
		set_facing(-1 if hitx > 0.0 else 1)
	hurt_fly_state = 1
	hurt_fly_delay_timer = 0.0
	hurt_fall_timer = 0.0
	hurt_down_timer = 0.0
	hurt_y_min = position.y
	hurt_fly_hitx = hitx
	hurt_fly_hity = hity
	hurt_is_heavy_down_attack = hity > 5.0
	velocity_x = hitx * HIT_SPEED_SCALE
	velocity_y = hity * HIT_SPEED_SCALE
	damping_x = 0.0
	in_air = true
	in_hitstun = true
	action_locked = true
	apply_gravity_enabled = true
	play_action("knock_fly")


func _start_original_dead_hurt_down_tan() -> void:
	# 原版 FighterMC.playHurtDown：先 goFrame(击飞_弹)，2 帧后 playHurtDown2 -> 击飞_倒。
	# KO 时保持 original_round_end_dead_lock，进入倒地后不会起身，等同 DEAD。
	hurt_fly_state = 5
	hurt_fall_timer = 2.0 / ORIGINAL_FPS
	hurt_down_timer = 0.0
	in_air = false
	position.y = ground_y
	velocity_y = 0.0
	in_hitstun = true
	action_locked = true
	apply_gravity_enabled = true
	damping_x = 2.0 * HIT_SPEED_SCALE
	play_action("knock_bounce")


func _start_hurt_fall_stage() -> void:
	# 原版 state2 先 goFrame("击飞_落")，至少渲染 2 帧再弹起/倒地。
	hurt_fly_state = 2
	hurt_fall_timer = 2.0 / ORIGINAL_FPS
	in_hitstun = true
	action_locked = true
	play_action("knock_fall")


func _start_hurt_bounce_stage() -> void:
	# 原版非重下砸：goFrame("击飞_弹") 后按高度差给一个反弹速度。
	var y_diff: float = maxf(0.0, ground_y - hurt_y_min)
	var bounce_v: float = clampf(y_diff / 25.0, 3.0, 8.0)
	hurt_fly_state = 3
	in_air = true
	velocity_y = -bounce_v * HIT_SPEED_SCALE
	# 落地时仍保留一部分横向滑行。
	damping_x = 2.0 * HIT_SPEED_SCALE
	play_action("knock_bounce")


func _start_hurt_down_stage(frames: int) -> void:
	# 原版 playHurtDown2 / renderHurtFly state4：goFrame("击飞_倒")。
	# 若角色已死亡，renderHurtFly state4 会直接进入 DEAD 并停在倒地，不会再“击飞_起”。
	hurt_fly_state = 4
	hurt_down_timer = 9999.0 if original_round_end_dead_lock or not is_alive else float(frames) / ORIGINAL_FPS
	in_air = false
	position.y = ground_y
	velocity_y = 0.0
	damping_x = 2.0 * HIT_SPEED_SCALE
	play_action("knock_down")
	if original_round_end_dead_lock or not is_alive:
		action_locked = true
		is_allow_be_hit = false


func update_hurt_fly_state(delta: float) -> void:
	if hurt_fly_state == 0:
		return

	if hurt_fly_state == 1:
		if hurt_fly_delay_timer > 0.0:
			hurt_fly_delay_timer -= delta
			if hurt_fly_delay_timer <= 0.0 and current_action == "hurt":
				play_action("knock_fly")
		if hurt_y_min > position.y:
			hurt_y_min = position.y
		return

	if hurt_fly_state == 2:
		hurt_fall_timer -= delta
		if hurt_fall_timer > 0.0:
			return
		if hurt_is_heavy_down_attack:
			_start_hurt_down_stage(30)
		else:
			_start_hurt_bounce_stage()
		return

	if hurt_fly_state == 3:
		# 落地切换在 update_physics() 里处理。
		return

	if hurt_fly_state == 5:
		# 原版 playHurtDown 的 2 帧“击飞_弹”过渡。
		hurt_fall_timer -= delta
		if hurt_fall_timer <= 0.0:
			_start_hurt_down_stage(30)
		return

	if hurt_fly_state == 4:
		# 原版 FighterMC.renderHurtFly state4：如果 !_fighter.isAlive，立刻进入 DEAD 并停在倒地帧。
		if original_round_end_dead_lock or not is_alive:
			hurt_fly_state = 0
			hurt_down_timer = 9999.0
			in_hitstun = false
			action_locked = true
			is_allow_be_hit = false
			be_hit_gap_timer = 9999.0
			if current_action != "knock_down":
				play_action("knock_down")
				action_locked = true
			if not original_round_end_dead_announced:
				original_round_end_dead_announced = true
				print("原版 KO DEAD：败者停在击飞_倒，不进入起身。")
			return
		hurt_down_timer -= delta
		if hurt_down_timer <= 0.0:
			hurt_fly_state = 0
			play_action("getup")
		return


func update_horizontal_motion(delta: float) -> void:
	if original_round_end_winner_hold_lock and current_action == "win":
		position = original_round_end_winner_hold_position
		velocity_x = 0.0
		damping_x = 0.0
		return
	if abs(velocity_x) <= 0.1:
		velocity_x = 0.0
		return

	position.x += velocity_x * delta
	if damping_x > 0.0:
		velocity_x = move_toward(velocity_x, 0.0, damping_x * delta)


func update_energy(delta: float) -> void:
	# 原版按帧恢复 energy。这里用 30 FPS 等价换算成 delta，便于 Godot 独立帧率运行。
	if energy_add_gap > 0.0:
		energy_add_gap = maxf(0.0, energy_add_gap - delta)
		return

	if energy >= energy_max:
		energy = energy_max
		return

	var add_per_frame: float = ENERGY_ADD_NORMAL_PER_FRAME
	if energy_overload:
		add_per_frame = ENERGY_ADD_OVERLOAD_PER_FRAME
	elif current_action == "defend":
		add_per_frame = ENERGY_ADD_DEFENSE_PER_FRAME
	elif is_attacking_action():
		add_per_frame = ENERGY_ADD_ATTACKING_PER_FRAME

	energy = minf(energy_max, energy + add_per_frame * ORIGINAL_FPS * delta)
	if energy_overload and energy > 30.0:
		energy_overload = false



func is_attacking_action() -> bool:
	return (
		current_action.begins_with("atk")
		or current_action.begins_with("skill")
		or current_action.begins_with("attack_skill")
		or current_action.begins_with("super")
		or current_action == "jump_attack"
		or current_action == "air_skill"
	)


func add_qi(value: float) -> void:
	if value <= 0.0:
		return
	qi = minf(qi_max, qi + value)


func has_qi(value: float) -> bool:
	return qi >= value


func use_qi(value: float) -> bool:
	if value <= 0.0:
		return true
	if qi < value:
		return false
	qi = maxf(0.0, qi - value)
	return true


func has_energy(value: float, allow_overflow: bool = false) -> bool:
	if energy >= value:
		return true
	if allow_overflow and not energy_overload:
		return true
	return false


func use_energy(value: float) -> void:
	energy -= value
	# 原版：_energyAddGap = USE_ENERGY_CD * FPS_ANIMATE；这里用秒计时，所以直接保存 0.8s。
	energy_add_gap = USE_ENERGY_CD
	if energy < 0.0:
		energy = 0.0
		energy_overload = true


func is_defending() -> bool:
	return current_action == "defend" or defense_hit_timer > 0.0


func is_can_hurt_break() -> bool:
	# 原版 canHurtBreak 只在受击/击飞可中断窗口且辅助气满时成立；当前项目仍忽略 O 键，只供 HUD/SP 状态读取。
	if not is_alive:
		return false
	if fzqi < fzqi_max:
		return false
	if original_move_target_bound or original_caught_by_throw:
		return false
	return in_hitstun or hurt_fly_state != 0 or original_can_hurt_break_timer > 0.0


func update_defense_hold(delta: float) -> void:
	if defense_hit_timer > 0.0:
		defense_hit_timer = maxf(0.0, defense_hit_timer - delta)


func unlock_original_action() -> void:
	action_locked = false


func set_apply_gravity_enabled(enabled: bool) -> void:
	apply_gravity_enabled = enabled
	if not enabled:
		velocity_y = 0.0


func set_original_time_scale(value: float) -> void:
	original_time_scale = clampf(value, 0.01, 4.0)


func set_cross_enabled(enabled: bool) -> void:
	is_cross = enabled


func set_air_move_enabled(enabled: bool) -> void:
	original_air_move_enabled = enabled


func stop_original_animation() -> void:
	# MovieClip.stop()：停在当前帧，不继续 advance frame。
	original_animation_stopped = true
	action_locked = true


func play_original_round_end_loser_down(attacker_facing: int = 1, last_hit_vo: Dictionary = {}) -> void:
	# 对照原版：FighterMain.die() 只把 isAlive=false；若当前处于受击/击飞流程，
	# FighterMC.renderHurtFly 会继续让角色飞出、落地、弹起/倒地；到 state4 时因 !isAlive 进入 DEAD 并停在倒地。
	# 旧 Step64 直接清零速度并 play_action("knock_down")，导致败者血量清零后原地趴下，缺少原版的击飞距离。
	hp = 0.0
	is_alive = false
	original_round_end_dead_lock = true
	original_round_end_attacker_facing = attacker_facing
	original_round_end_dead_announced = false
	is_allow_be_hit = false
	be_hit_gap_timer = 9999.0
	defense_hit_timer = 0.0
	original_guard_break_timer = 0.0
	original_can_hurt_break_timer = 0.0
	set_steel_body(false)
	clear_original_timeline_states()
	resume_original_special_color()
	if sprite != null:
		sprite.material = null
		sprite.modulate = Color.WHITE

	# 如果 KO 命中已经让角色进入击飞/空中流程，继续保留该速度和状态，
	# 等落地后自然进入 knock_down/DEAD。不要在这里强制归零。
	if hurt_fly_state != 0 or in_air or current_action in ["knock_fly", "knock_fall", "knock_bounce"]:
		in_hitstun = true
		action_locked = true
		apply_gravity_enabled = true
		print("原版 KO：保留当前击飞/空中流程，败者落地后进入 DEAD。 action=", current_action, " vx=", velocity_x, " vy=", velocity_y)
		return

	# 如果 KO 命中是 hurtType=0 的普通受击，原版 doHurtAnimate 会先停留 hurtHoldFrame，
	# 等 renderHurtAnimate 发现 !isAlive 后再 playHurtDown，而不是恢复 idle。
	if in_hitstun and current_action == "hurt":
		# 原版 hurtType=0：先保留 HURT_ING 的速度/阻尼，hurtHold 结束时若 !isAlive 则 playHurtDown。
		# 若 Godot 侧因为 KO 检测晚一帧丢了 hity/hitx，则用最后一击 HitVO 补回速度，避免角色原地站死。
		if not last_hit_vo.is_empty():
			var last_hitx: float = float(last_hit_vo.get("hitx", 0.0)) * float(attacker_facing)
			var last_hity: float = float(last_hit_vo.get("hity", 0.0))
			var last_hurt_type: int = int(last_hit_vo.get("hurtType", 0))
			if last_hurt_type == 1:
				if last_hity == 0.0:
					last_hity = -6.0
				_start_original_hurt_fly(last_hitx, last_hity)
				original_round_end_dead_lock = true
				is_alive = false
				print("原版 KO：最后一击 hurtType=1，补回 hurtFly。 hitx=", last_hitx, " hity=", last_hity)
				return
			if absf(velocity_x) < 0.1 and absf(last_hitx) > 0.0:
				velocity_x = last_hitx * HIT_SPEED_SCALE
				damping_x = absf(last_hitx) * HIT_SPEED_SCALE * 3.0 + 180.0
		action_locked = true
		apply_gravity_enabled = true
		print("原版 KO：保留普通受击硬直，hurtHold 结束后 playHurtDown -> DEAD。 vx=", velocity_x, " vy=", velocity_y)
		return

	# 异常兜底：如果 Godot 侧进入 KO 时已不是受击状态，对齐 FighterMain.die() 的 fallback。
	# 但若最后一击本身是 hurtType=1，原版 doHurt 已经应当进入 HURT_FLYING，Godot 侧不能丢掉这段飞出过程。
	if not last_hit_vo.is_empty() and int(last_hit_vo.get("hurtType", 0)) == 1:
		var fallback_hitx: float = float(last_hit_vo.get("hitx", 7.0)) * float(attacker_facing)
		var fallback_hity: float = float(last_hit_vo.get("hity", -6.0))
		if fallback_hity == 0.0:
			fallback_hity = -6.0
		_start_original_hurt_fly(fallback_hitx, fallback_hity)
	else:
		_start_original_dead_hurt_down_tan()
	is_alive = false
	original_round_end_dead_lock = true
	is_allow_be_hit = false
	be_hit_gap_timer = 9999.0
	action_locked = true
	print("原版 KO fallback：非受击状态按 FighterMain.die() -> playHurtDown。")


func is_original_round_end_dead_down() -> bool:
	return original_round_end_dead_lock and current_action == "knock_down" and not in_air


func stop_original_motion() -> void:
	velocity_x = 0.0
	if in_air:
		velocity_y = 0.0


func set_original_velocity(vx: float, vy: float) -> void:
	velocity_x = vx
	if absf(vy) > 0.001:
		velocity_y = vy
		if position.y < ground_y - 0.5 or vy < 0.0:
			in_air = true
		apply_gravity_enabled = true


func set_original_damping(damping_value: float) -> void:
	damping_x = maxf(0.0, damping_value)


func apply_original_dash_motion(speed_plus: float = 3.0, _base_speed: float = 220.0) -> void:
	# FighterMcCtrler.dash(speedPlus)：
	#   _fighter.setVelocity(_fighter.speed * speedPlus * direct, 0)
	#   _fighter.speed 原版 FighterMain.as 默认值为 6，单位是“每个 render frame 的像素”。
	# Godot 这里 velocity_x 使用 px/s，所以需要乘 ORIGINAL_GAME_RENDER_FPS。
	var original_speed_per_frame: float = ORIGINAL_FIGHTER_SPEED_PER_FRAME
	velocity_x = original_speed_per_frame * speed_plus * ORIGINAL_GAME_RENDER_FPS * float(facing)
	velocity_y = 0.0
	damping_x = 0.0
	is_cross = true
	is_allow_be_hit = false
	be_hit_gap_timer = maxf(be_hit_gap_timer, 2.0 / ORIGINAL_FPS)


func apply_original_dash_stop(lose_spd_percent: float = 0.5) -> void:
	# FighterMcCtrler.dashStop(loseSpdPercent)：
	#   vecx 是原版 px/frame；damping=abs(vecx)*losePercent；BaseGameSprite.setDamping 再按帧衰减。
	# 当前 velocity_x 是 px/s，因此先转回 px/frame，再换算为 px/s^2，避免旧版出现很长滑行。
	var vecx_per_frame: float = velocity_x / ORIGINAL_GAME_RENDER_FPS
	var damping_per_frame: float = absf(vecx_per_frame) * lose_spd_percent
	damping_x = damping_per_frame * ORIGINAL_GAME_RENDER_FPS * ORIGINAL_GAME_RENDER_FPS
	is_cross = false
	is_allow_be_hit = true
	be_hit_gap_timer = 0.0
	action_locked = false


func set_air_state_from_position() -> void:
	in_air = position.y < ground_y - 0.5
	if in_air:
		velocity_y = 0.0


func set_original_move_target_bound(enabled: bool) -> void:
	# MoveTargetParamVO 绑定 currentTarget 时，目标位置由 FighterMcCtrler.renderMoveTarget() 控制。
	original_move_target_bound = enabled
	if enabled:
		apply_gravity_enabled = false
		velocity_x = 0.0
		velocity_y = 0.0
		damping_x = 0.0
		in_air = position.y < ground_y - 0.5
	else:
		apply_gravity_enabled = true
		set_air_state_from_position()


func set_original_caught_by_throw(enabled: bool) -> void:
	# HitType.CATCH 命中后目标进入投技控制状态；moveTarget 会进一步绑定位置。
	original_caught_by_throw = enabled
	if enabled:
		in_hitstun = true
		action_locked = true
		velocity_x = 0.0
		velocity_y = 0.0
		damping_x = 0.0
	else:
		original_caught_by_throw = false


func get_damage_from_hitvo(hit_vo: Dictionary) -> float:
	# 原版 HitVO.getDamage():
	#   powAdd = power * (powerAdd / 100)
	#   return (power + powAdd) * powerRate
	var power: float = float(hit_vo.get("power", 0.0))
	var power_add: float = float(hit_vo.get("powerAdd", 0.0))
	var power_rate: float = float(hit_vo.get("powerRate", 1.0))
	return (power + power * (power_add / 100.0)) * power_rate


func set_original_hurt_action(action_name: String) -> void:
	original_hurt_action = action_name


func set_steel_body(enabled: bool, is_super: bool = false) -> void:
	is_steel_body = enabled
	is_super_steel_body = enabled and is_super
	# 原版 setSteelBody(false) 同时结束 glow。Godot 当前没有 startGlow/endGlow 资源，
	# 所以这里只保存战斗状态，不伪造光效。
	if not enabled:
		is_super_steel_body = false


func clear_original_timeline_states() -> void:
	original_hurt_action = ""
	set_steel_body(false)
	if original_move_target_bound:
		set_original_move_target_bound(false)
	if original_caught_by_throw:
		set_original_caught_by_throw(false)


func _is_bisha_hit_vo(hit_vo: Dictionary) -> bool:
	var hit_id: String = str(hit_vo.get("id", ""))
	return hit_id.find("bs") != -1 or hit_id.find("sbs") != -1 or hit_id.find("cbs") != -1 or hit_id.find("kbs") != -1


func _is_catch_hit_vo(hit_vo: Dictionary) -> bool:
	return int(hit_vo.get("hitType", 0)) == 11 and hit_vo.get("isBreakDef", false) == true


func _apply_original_steel_hit(hit_vo: Dictionary, attacker_facing: int) -> Dictionary:
	# 对照 FighterMcCtrler.doSteelHurt(hitvo, hitRect)。
	# 普通钢体遇到 energyOverLoad / 必杀 / 抓取时会退回普通 doHurt。
	if (not is_super_steel_body) and (energy_overload or _is_bisha_hit_vo(hit_vo) or _is_catch_hit_vo(hit_vo)):
		set_steel_body(false)
		return {}

	var hit_id: String = str(hit_vo.get("id", ""))
	var damage: float = get_damage_from_hitvo(hit_vo)
	var damage_rate: float = SUPER_STEEL_BODY_DAMAGE_RATE if is_super_steel_body else STEEL_BODY_DAMAGE_RATE
	var actual_damage: float = damage * damage_rate
	hp = maxf(0.0, hp - actual_damage)
	if hp <= 0.0:
		is_alive = false
		set_steel_body(false)
		# 原版钢体被打死时仍转入 doHurt，这里返回 dead 让外层走 KO。
		mark_original_hit_result("dead", actual_damage)
		return {"result":"dead", "damage":actual_damage, "hit_id":hit_id}

	var energy_cost: float = 0.0
	if is_super_steel_body:
		energy_cost = damage * SUPER_STEEL_BODY_ENERGY_RATE
	elif hit_vo.get("isBreakDef", false) == true:
		energy_cost = damage * STEEL_BODY_BREAK_DEF_ENERGY_RATE
	else:
		energy_cost = damage * STEEL_BODY_ENERGY_RATE
	use_energy(energy_cost)

	if not is_super_steel_body:
		var hitx: float = float(hit_vo.get("hitx", 0.0)) * float(attacker_facing)
		var hity: float = float(hit_vo.get("hity", 0.0))
		if hit_vo.get("isBreakDef", false) == true:
			hitx *= 2.0
			hity *= 2.0
		velocity_x = hitx * HIT_SPEED_SCALE
		velocity_y = hity * HIT_SPEED_SCALE
		damping_x = absf(hitx) * HIT_SPEED_SCALE * 3.0 + 180.0

	_set_be_hit_gap(10 if int(hit_vo.get("hurtType", 0)) == 1 else 4)
	print("STEEL HitVO=", hit_id, " damage=", actual_damage, " hp=", hp, "/", hp_max, " energy=", energy, "/", energy_max)
	mark_original_hit_result("steel", actual_damage)
	return {"result":"steel", "damage":actual_damage, "hit_id":hit_id}


func get_original_defense_energy_cost(hit_vo: Dictionary, damage: float) -> float:
	# 原版防御的 energy 消耗随攻击类型/破防属性变化；这里保留原先数值但集中到一个入口，便于 HUD/SP 审计。
	if hit_vo.get("isBreakDef", false) == true:
		return energy_max * 0.9
	var hit_type: int = int(hit_vo.get("hitType", 0))
	if hit_type in [3, 5, 6, 7, 8, 9]:
		return minf(70.0, maxf(18.0, damage / 4.0))
	return minf(50.0, maxf(8.0, damage / 5.0))


func is_original_hit_guardable(hit_vo: Dictionary, attacker_facing: int) -> bool:
	if not is_defending():
		return false
	if hit_vo.get("isReal", false) == true:
		return false
	if int(hit_vo.get("hitType", 0)) == 11:
		return false
	# facing 与攻击者方向相反时，代表面向攻击来源。
	return facing == -attacker_facing


func mark_original_hit_result(result: String, damage: float) -> void:
	original_last_hit_result = result
	original_last_damage_taken = damage
	if result in ["hurt", "knock_fly", "break_defense", "catch"]:
		original_can_hurt_break_timer = maxf(original_can_hurt_break_timer, 12.0 / ORIGINAL_FPS)


func apply_original_hit(hit_vo: Dictionary, attacker_facing: int) -> Dictionary:
	if not is_alive:
		return {"result":"dead"}

	# 原版 FighterMain.beHit：isAllowBeHit=false 时直接忽略本次受击。
	if not is_allow_be_hit:
		return {"result":"ignored"}

	# 原版 FighterMcCtrler.beHit：若 _action.hurtAction 存在，先 doAction(hurtAction)，不走普通受击伤害。
	if original_hurt_action != "":
		var counter_action: String = original_hurt_action
		print("原版 hurtAction 触发：", current_action, " 被打时转入 ", counter_action, "，本次 HitVO 不扣血")
		_set_be_hit_gap(4)
		play_action(counter_action)
		mark_original_hit_result("counter", 0.0)
		return {"result":"counter", "action":counter_action}

	if is_steel_body:
		var steel_result: Dictionary = _apply_original_steel_hit(hit_vo, attacker_facing)
		if not steel_result.is_empty():
			return steel_result

	var hit_id: String = str(hit_vo.get("id", ""))
	var damage: float = get_damage_from_hitvo(hit_vo)
	var hit_type: int = int(hit_vo.get("hitType", 0))
	var _is_real: bool = hit_vo.get("isReal", false) == true
	var _is_break_def: bool = hit_vo.get("isBreakDef", false) == true
	var _can_defend_direct: bool = facing == -attacker_facing

	if hit_type == 11:
		# HitType.CATCH：不可按普通防御处理；原版 doHurt 中使用“被打”不跳到第 7 帧。
		hp = maxf(0.0, hp - damage)
		if hp <= 0.0:
			is_alive = false
		set_steel_body(false)
		set_original_caught_by_throw(true)
		hurt_timer = maxf(0.05, float(hit_vo.get("hurtTime", 1000.0)) / 1000.0)
		in_hitstun = true
		action_locked = true
		velocity_x = 0.0
		velocity_y = 0.0
		damping_x = 0.0
		_set_be_hit_gap(10)
		play_action("hurt")
		mark_original_hit_result("catch", damage)
		return {"result":"catch", "damage":damage, "hit_id":hit_id}

	# 原版防御：真实伤害/抓取不可防；破防招消耗大量 energy，不够则破防。
	if is_original_hit_guardable(hit_vo, attacker_facing):
		var def_energy: float = get_original_defense_energy_cost(hit_vo, damage)

		if has_energy(def_energy, false):
			use_energy(def_energy)
			var guard_damage: float = damage * DEFENSE_LOSE_HP_RATE
			hp = maxf(0.0, hp - guard_damage)
			defense_hit_timer = 10.0 / ORIGINAL_FPS
			_set_be_hit_gap(8 if int(hit_vo.get("hurtType", 0)) == 1 else 4)
			velocity_x = float(attacker_facing) * float(hit_vo.get("hitx", 0.0)) * HIT_SPEED_SCALE
			damping_x = 500.0
			print("DEFENSE HitVO=", hit_id, " guard_damage=", guard_damage, " energy=", energy, "/", energy_max)
			if hp <= 0.0:
				is_alive = false
			mark_original_hit_result("defense", guard_damage)
			return {"result":"defense", "damage":guard_damage}

		# 原版 doBreakDefense：破防时扣约 1/10 伤害，进入受击硬直。
		var break_damage: float = damage / 10.0
		hp = maxf(0.0, hp - break_damage)
		use_energy(def_energy)
		print("BREAK DEFENSE HitVO=", hit_id, " break_damage=", break_damage, " energy=", energy, "/", energy_max)
		in_hitstun = true
		action_locked = true
		hurt_timer = 42.0 / ORIGINAL_FPS
		_set_be_hit_gap(10 if int(hit_vo.get("hurtType", 0)) == 1 else 4)
		velocity_x = float(attacker_facing) * clampf(float(hit_vo.get("hitx", 5.0)), 5.0, 10.0) * HIT_SPEED_SCALE
		damping_x = 300.0
		if hp <= 0.0:
			is_alive = false
		set_steel_body(false)
		play_action("hurt")
		original_guard_break_timer = maxf(original_guard_break_timer, 18.0 / ORIGINAL_FPS)
		mark_original_hit_result("break_defense", break_damage)
		return {"result":"break_defense", "damage":break_damage}

	hp = maxf(0.0, hp - damage)
	if hp <= 0.0:
		is_alive = false

	var hitx: float = float(hit_vo.get("hitx", 0.0)) * float(attacker_facing)
	var hity: float = float(hit_vo.get("hity", 0.0))
	var hurt_type: int = int(hit_vo.get("hurtType", 0))
	var hurt_time_ms: float = float(hit_vo.get("hurtTime", 300.0))

	# 对应原版 FighterMcCtrler.doHurt 里的地面/空中 hity 修正。
	if in_air:
		if hity <= 0.0:
			hity -= 3.0
	elif hity < 0.0:
		hity -= 6.0

	print("APPLY HitVO id=", hit_id, " damage=", damage, " hp=", hp, "/", hp_max,
		" hitType=", hit_vo.get("hitType", 0), " hurtType=", hurt_type,
		" hitx=", hitx, " hity=", hity, " hurtTime=", hurt_time_ms)

	velocity_x = hitx * HIT_SPEED_SCALE
	damping_x = absf(hitx) * HIT_SPEED_SCALE * 3.0 + 180.0

	# 原版 doHurt 会 setSteelBody(false)。
	set_steel_body(false)

	if hurt_type == 0:
		# 原版：_hurtHoldFrame = round(hurtTime / 1000 * 30) + 3，最少 4 帧。
		var hurt_hold_frame: int = maxi(4, int(round(hurt_time_ms / 1000.0 * ORIGINAL_FPS)) + HURT_FRAME_OFFSET)
		hurt_timer = float(hurt_hold_frame) / ORIGINAL_FPS
		in_hitstun = true
		action_locked = true

		if hity != 0.0:
			in_air = true
			velocity_y = hity * HIT_SPEED_SCALE

		_set_be_hit_gap(4)
		play_action("hurt")
		mark_original_hit_result("hurt", damage)
		return {"result":"hurt", "damage":damage}

	# hurtType=1：原版进入 FighterMC.playHurtFly(hitx, hity)，但普通受击间隔仍来自 GameConfig.HURT_GAP_FRAME=4。
	if hity == 0.0:
		# HitVO 未给 hity 时保留一个最小上抛，避免击飞状态停在地面。
		hity = -6.0
	_set_be_hit_gap(4)
	_start_original_hurt_fly(hitx, hity)
	mark_original_hit_result("knock_fly", damage)
	return {"result":"knock_fly", "damage":damage}



func get_original_strict_visual_frame_path(rel_path: String) -> String:
	# Step35：恢复 U/招1 的角色抬手动作和闪电特效。
	# 不再把整个 skill1 显示替换成 idle；仍显示原始 skill1 帧。
	# 后撤观感改由 get_original_skill1_visual_offset() 的逐帧注册点补偿解决。
	return rel_path



const ORIGINAL_SKILL1_VISUAL_OFFSET_X: Array[float] = [-13.0, -13.0, -13.0, -13.0, -13.0, -13.0, -13.0, -13.0, -13.0, -13.0, -13.0, -13.0, 0.0, 0.0, 0.0, 0.0, 3.0, 57.0, 57.0, 110.0, 109.0, 160.0, 160.0, 153.0, 153.0, 159.0, 158.0, 140.0, 141.0, 95.0, 95.0, 3.0, 2.0, 2.0, 3.0, 3.0, 3.0, 3.0, 2.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


func get_original_skill1_visual_offset() -> Vector2:
	# Step35：基于当前 actions_game/skill1 实战帧逐帧计算的“脚部锚点”补偿。
	# 原版 U/招1 无根移动；这里只移动 Sprite2D 的本地显示位置，不改 Node2D.position / hitbox / timing。
	# facing=1 时使用 target_anchor - frame_anchor；facing=-1 时反向。
	if current_action != "skill1":
		return Vector2.ZERO
	var idx: int = clampi(frame_index, 0, ORIGINAL_SKILL1_VISUAL_OFFSET_X.size() - 1)
	return Vector2(ORIGINAL_SKILL1_VISUAL_OFFSET_X[idx] * float(facing), 0.0)


func force_reapply_original_no_world_move_anchor() -> void:
	# BattlePlaceholder 在自己 _process 末尾再调用一次，防止任何父级逻辑在本帧最后又改变 skill1 的世界坐标。
	apply_original_no_world_move_anchor()


func update_frame() -> void:
	var action: Dictionary = manifest["actions"][current_action]
	var frames: Array = action.get("frames", [])

	if frame_index < 0 or frame_index >= frames.size():
		return

	var rel_path: String = str(frames[frame_index])
	var visual_rel_path: String = get_original_strict_visual_frame_path(rel_path)
	var full_path: String = "res://assets/characters/aizen/" + visual_rel_path

	var tex: Texture2D = load(full_path)

	if tex == null:
		push_warning("Cannot load frame: " + full_path)
		return

	ensure_sprite()
	if current_action == "win" or current_action == "lose" or current_action.begins_with("knock_"):
		sprite.material = null
		sprite.modulate = Color.WHITE
		sprite.self_modulate = Color.WHITE
	sprite.texture = tex
	sprite.flip_h = facing < 0
	sprite.position = get_original_skill1_visual_offset()
