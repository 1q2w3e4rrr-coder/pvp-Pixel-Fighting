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
var original_guard_break_timer: float = 0.0
var original_can_hurt_break_timer: float = 0.0

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

	# Step27：原版 mc_023 的 招1/招2/招3 时间轴没有 move / movePercent / dash / moveToTarget。
	# 因此这些地面 U 技能不应改变 FighterMain 世界坐标；开始时记录 anchor，并在动作期间持续锁定。
	original_no_world_move_anchor_active = false
	if action_name == "skill1" or action_name == "skill2" or action_name == "skill3":
		velocity_x = 0.0
		damping_x = 0.0
		if not in_air:
			velocity_y = 0.0
			original_no_world_move_anchor_active = true
			original_no_world_move_anchor_pos = position

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


func set_facing(new_facing: int) -> void:
	facing = new_facing

	if sprite != null:
		sprite.flip_h = facing < 0


func start_jump() -> void:
	if in_air:
		return

	if is_busy():
		return

	in_air = true
	velocity_y = jump_speed
	play_action("jump_start")


func start_air_attack() -> void:
	if not in_air:
		return

	if is_busy():
		return

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
	update_animation(scaled_delta)
	update_physics(scaled_delta)
	update_horizontal_motion(scaled_delta)
	apply_original_no_world_move_anchor()


func apply_original_no_world_move_anchor() -> void:
	if not original_no_world_move_anchor_active:
		return
	if in_air:
		original_no_world_move_anchor_active = false
		return
	# 只锁地面 U 技能的 FighterMain 世界坐标；动作本身的帧动画仍正常播放。
	if current_action != "skill1" and current_action != "skill2" and current_action != "skill3":
		original_no_world_move_anchor_active = false
		return
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
	if current_action == "hurt" and hurt_fly_state == 0:
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
	# 原版 playHurtDown2 / renderHurtFly state4：goFrame("击飞_倒")，等待 _hurtDownFrame 后进入“击飞_起”。
	hurt_fly_state = 4
	hurt_down_timer = float(frames) / ORIGINAL_FPS
	in_air = false
	position.y = ground_y
	velocity_y = 0.0
	damping_x = 2.0 * HIT_SPEED_SCALE
	play_action("knock_down")


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

	if hurt_fly_state == 4:
		hurt_down_timer -= delta
		if hurt_down_timer <= 0.0:
			hurt_fly_state = 0
			play_action("getup")
		return


func update_horizontal_motion(delta: float) -> void:
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
	sprite.texture = tex
	sprite.flip_h = facing < 0
	sprite.position = get_original_skill1_visual_offset()
