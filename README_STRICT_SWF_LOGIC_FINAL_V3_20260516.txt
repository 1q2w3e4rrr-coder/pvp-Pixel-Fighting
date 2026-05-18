BVN Aizen strict SWF logic final v3
===================================

基于：bvn_aizen_strict_swf_logic_final_v2_patch

本次只改 scripts/battle/BattlePlaceholder.gd。

目的：
- 继续按原版 aizen XFL / mc_023.xml 时间轴脚本处理蓝染 attacker。
- 不再只靠 action_name + relative_frame 的硬编码兜底生成 bsmc / zh3mc。
- 直接读取 manifest 中保留下来的 raw call：object=mc_ctrler, method=addAttacker。

原版依据：
1. aizen/LIBRARY/元件/mc_023.xml：
   - global frame 804：parent.$mc_ctrler.addAttacker("bsmc", {x:{followTarget:true,offset:0}, y:{followTarget:true,offset:-25}, applyG:false});
   - global frame 680：parent.$mc_ctrler.addAttacker("zh3mc", {applyG:false});
2. FighterMcCtrler.as：addAttacker(mcName, params) 会从当前 MovieClip child 中取出 mcName，并把 params 交给 FighterEvent.ADD_ATTACKER。
3. FighterAttacker.as：followTargetX/followTargetY 每帧按 currentTarget 位置更新；applyG=false 表示不受重力。

改动：
1. _on_p1_frame_event() 对 semantic 为空的 raw call 不再直接跳过。
2. 新增 handle_aizen_raw_call_event()：
   - 识别 mc_ctrler.addAttacker。
   - bsmc：按原版 followTarget x=0, y=-25, applyG=false 播放并跟随 P2。
   - zh3mc：按原版 applyG=false 播放，不追踪目标；攻击面继续使用由 mc_023 zh3mc Matrix + mc_015 zh3atm Matrix 推导出的 ZH3ATM_RECT。
3. 删除/停用原来 action_name == "super" && relative_frame == 40、action_name == "skill3" && relative_frame == 6 的硬编码兜底，避免将来 manifest raw call 正常解析后重复生成 attacker。

未做的事：
- 没有手调 bsmc / zh3mc 的 Y 轴。
- 没有生成替代素材。
- 没有新增非原版技能逻辑。
- zh3mc FFDec PNG 的视觉锚点仍保持当前已验证值；若要像素级还原，下一步必须提取/计算 FFDec 导出 canvas 的原始 bounds / registration point，而不是靠截图凑坐标。

覆盖路径：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

测试重点：
1. I 普通必杀仍在原版 raw addAttacker 帧触发 bsmc。
2. W+U 招3仍在原版 raw addAttacker 帧触发 zh3mc。
3. Output 中应看到“原版 raw addAttacker 触发”。
4. Round 1 / Fight / 无限时间 / 隐藏 SCORE / O 键忽略 等 v2 内容应保持不变。
