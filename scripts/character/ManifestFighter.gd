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

# 第 8 步：按原版 HitVO 做最小伤害/受击/击退。
# 3.8.4.3 原版实机 HUD 中蓝染初始 HP 显示为 2000。
# 原版 FighterMcCtrler.doHurt：power -> loseHp，hitx/hity 由攻击者 direct 修正，hurtType=0 进入“被打”，hurtType=1 进入击飞。
var hp_max: float = 2000.0
var hp: float = 2000.0
var is_alive: bool = true

# 原版 FighterMain：qiMax=300；qi 用于普通必杀/上必杀/空中必杀 100，超必杀 300。
# 初始值不在这里强行填 1 格，避免破坏原版 QiBar/qbar_fzqi_mc 显示层。
var qi: float = 0.0
var qi_max: float = 300.0
# 原版 QiBar.as 还读取 fighter.fzqi/100 来显示辅助气条 fzqibar/readymc/sp。
# 当前项目按你的要求忽略 O 支援/换人，只保留 HUD 显示变量和调试充满。
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

# 原版 setHurtAction：当前动作被打时不进入普通受击，而是转入指定反击动作。
var original_hurt_action: String = ""
# 原版 FighterMcCtrler.setSteelBody(v, isSuper)：钢体/霸体状态。
# 普通钢体被打时不打断当前动作，按 doSteelHurt 扣 65% 伤害并耗 energy；
# superSteelBody 扣 30% 伤害。遇到必杀/抓取/energyOverLoad 时普通钢体会退回 doHurt。
var is_steel_body: bool = false
var is_super_steel_body: bool = false
var apply_gravity_enabled: bool = true

const ORIGINAL_FPS := 30.0
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

	current_action = action_name
	frame_index = 0
	frame_timer = 0.0
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
	update_energy(delta)
	update_defense_hold(delta)
	update_hurt_timer(delta)
	update_animation(delta)
	update_physics(delta)
	update_horizontal_motion(delta)


func update_animation(delta: float) -> void:
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
		if in_air:
			play_action("knock_fall")
		else:
			play_action("knock_down")
		return

	if finished_action == "knock_fall":
		if in_air:
			play_action("knock_fall")
		else:
			play_action("knock_down")
		return

	if finished_action == "knock_down":
		play_action("getup")
		return

	if finished_action == "getup":
		in_hitstun = false
		action_locked = false
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

		if current_action == "knock_fly" or current_action == "knock_fall":
			play_action("knock_down")
		elif current_action != "land" and not in_hitstun:
			play_action("land")


func update_hurt_timer(delta: float) -> void:
	if not in_hitstun:
		return

	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer > 0.0:
			return

	# hurtType=0 的普通硬直结束后恢复；击飞流程由 knock_fly/knock_down/getup 处理。
	if current_action == "hurt":
		in_hitstun = false
		action_locked = false
		if in_air:
			play_action("fall")
		else:
			play_action("idle")


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
	energy_add_gap = USE_ENERGY_CD * ENERGY_ADD_OVERLOAD_RESUME / ORIGINAL_FPS
	if energy < 0.0:
		energy = 0.0
		energy_overload = true


func is_defending() -> bool:
	return current_action == "defend" or defense_hit_timer > 0.0


func is_can_hurt_break() -> bool:
	# 对应原版 QiBar.render() 中的 getMcCtrl().isCanHurtBreak()。
	# 这里只用于 HUD 的 sp 提示，不重新启用 O 支援/换人。
	if fzqi < fzqi_max:
		return false
	return in_hitstun or current_action == "hurt" or current_action.begins_with("knock") or current_action == "hurt_fly"


func update_defense_hold(delta: float) -> void:
	if defense_hit_timer > 0.0:
		defense_hit_timer = maxf(0.0, defense_hit_timer - delta)


func unlock_original_action() -> void:
	action_locked = false


func set_apply_gravity_enabled(enabled: bool) -> void:
	apply_gravity_enabled = enabled
	if not enabled:
		velocity_y = 0.0


func stop_original_motion() -> void:
	velocity_x = 0.0
	if in_air:
		velocity_y = 0.0


func set_air_state_from_position() -> void:
	in_air = position.y < ground_y - 0.5
	if in_air:
		velocity_y = 0.0


func get_damage_from_hitvo(hit_vo: Dictionary) -> float:
	return float(hit_vo.get("power", 0)) * float(hit_vo.get("powerRate", 1.0))


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


func _is_bisha_hit_vo(hit_vo: Dictionary) -> bool:
	var hit_id: String = String(hit_vo.get("id", ""))
	return hit_id.find("bs") != -1 or hit_id.find("sbs") != -1 or hit_id.find("cbs") != -1 or hit_id.find("kbs") != -1


func _is_catch_hit_vo(hit_vo: Dictionary) -> bool:
	return int(hit_vo.get("hitType", 0)) == 11 and hit_vo.get("isBreakDef", false) == true


func _apply_original_steel_hit(hit_vo: Dictionary, attacker_facing: int) -> Dictionary:
	# 对照 FighterMcCtrler.doSteelHurt(hitvo, hitRect)。
	# 普通钢体遇到 energyOverLoad / 必杀 / 抓取时会退回普通 doHurt。
	if (not is_super_steel_body) and (energy_overload or _is_bisha_hit_vo(hit_vo) or _is_catch_hit_vo(hit_vo)):
		set_steel_body(false)
		return {}

	var hit_id: String = String(hit_vo.get("id", ""))
	var damage: float = get_damage_from_hitvo(hit_vo)
	var damage_rate: float = SUPER_STEEL_BODY_DAMAGE_RATE if is_super_steel_body else STEEL_BODY_DAMAGE_RATE
	var actual_damage: float = damage * damage_rate
	hp = maxf(0.0, hp - actual_damage)
	if hp <= 0.0:
		is_alive = false
		set_steel_body(false)
		# 原版钢体被打死时仍转入 doHurt，这里返回 dead 让外层走 KO。
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

	print("STEEL HitVO=", hit_id, " damage=", actual_damage, " hp=", hp, "/", hp_max, " energy=", energy, "/", energy_max)
	return {"result":"steel", "damage":actual_damage, "hit_id":hit_id}


func apply_original_hit(hit_vo: Dictionary, attacker_facing: int) -> Dictionary:
	if not is_alive:
		return {"result":"dead"}

	# 原版 FighterMcCtrler.beHit：若 _action.hurtAction 存在，先 doAction(hurtAction)，不走普通受击伤害。
	if original_hurt_action != "":
		var counter_action: String = original_hurt_action
		print("原版 hurtAction 触发：", current_action, " 被打时转入 ", counter_action, "，本次 HitVO 不扣血")
		play_action(counter_action)
		return {"result":"counter", "action":counter_action}

	if is_steel_body:
		var steel_result: Dictionary = _apply_original_steel_hit(hit_vo, attacker_facing)
		if not steel_result.is_empty():
			return steel_result

	var hit_id: String = String(hit_vo.get("id", ""))
	var damage: float = get_damage_from_hitvo(hit_vo)
	var is_real: bool = hit_vo.get("isReal", false) == true
	var is_break_def: bool = hit_vo.get("isBreakDef", false) == true
	var can_defend_direct: bool = facing == -attacker_facing

	# 原版防御：真实伤害/抓取不可防；破防招消耗大量 energy，不够则破防。
	if is_defending() and can_defend_direct and not is_real:
		var def_energy: float = 0.0
		if is_break_def:
			def_energy = int(energy_max * 0.9)
		else:
			def_energy = minf(50.0, damage / 5.0)

		if has_energy(def_energy, false):
			use_energy(def_energy)
			var guard_damage: float = damage * DEFENSE_LOSE_HP_RATE
			hp = maxf(0.0, hp - guard_damage)
			defense_hit_timer = 10.0 / ORIGINAL_FPS
			velocity_x = float(attacker_facing) * float(hit_vo.get("hitx", 0.0)) * HIT_SPEED_SCALE
			damping_x = 500.0
			print("DEFENSE HitVO=", hit_id, " guard_damage=", guard_damage, " energy=", energy, "/", energy_max)
			if hp <= 0.0:
				is_alive = false
			return {"result":"defense", "damage":guard_damage}

		# 原版 doBreakDefense：破防时扣约 1/10 伤害，进入受击硬直。
		var break_damage: float = damage / 10.0
		hp = maxf(0.0, hp - break_damage)
		use_energy(def_energy)
		print("BREAK DEFENSE HitVO=", hit_id, " break_damage=", break_damage, " energy=", energy, "/", energy_max)
		in_hitstun = true
		action_locked = true
		hurt_timer = 42.0 / ORIGINAL_FPS
		velocity_x = float(attacker_facing) * clampf(float(hit_vo.get("hitx", 5.0)), 5.0, 10.0) * HIT_SPEED_SCALE
		damping_x = 300.0
		if hp <= 0.0:
			is_alive = false
		set_steel_body(false)
		play_action("hurt")
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

		play_action("hurt")
		return {"result":"hurt", "damage":damage}

	# hurtType=1：原版进入击飞流程 playHurtFly(hitx, hity)。
	in_hitstun = true
	action_locked = true
	hurt_timer = 0.0
	in_air = true
	if hity == 0.0:
		# 原版 playHurtFly 内部还有倒地流程；这里给一个最小上抛，方便验证击飞。
		hity = -6.0
	velocity_y = hity * HIT_SPEED_SCALE
	play_action("knock_fly")
	return {"result":"knock_fly", "damage":damage}


func update_frame() -> void:
	var action: Dictionary = manifest["actions"][current_action]
	var frames: Array = action.get("frames", [])

	if frame_index < 0 or frame_index >= frames.size():
		return

	var rel_path: String = String(frames[frame_index])
	var full_path: String = "res://assets/characters/aizen/" + rel_path

	var tex: Texture2D = load(full_path)

	if tex == null:
		push_warning("Cannot load frame: " + full_path)
		return

	ensure_sprite()
	sprite.texture = tex
	sprite.flip_h = facing < 0
