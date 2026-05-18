BVN Godot Aizen system-final integrated patch

覆盖位置：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁基于前一个 final_integrated 版本继续合并，并新增：
1. 修复 ManifestFighter.gd 里 jump_attack 重复 if 的潜在解析问题。
2. 接入原版 FighterMain 的 qi / qiMax = 300，以及 energy / energyMax = 100。
3. I / W+I / 空中 I 消耗 100 气；S+I 超必杀消耗 300 气。
4. T 键为调试键：临时把 P1/P2 qi=300、energy=100，方便测试必杀。此键不是原版正式键。
5. S 单独按住进入防御 defend；松开进入 defend_recover。S+J/S+U/S+I 仍按原版作为组合技。
6. 防御时按原版 doDefenseHit / doBreakDefense 的核心逻辑处理：
   - 可防普通攻击：扣 5% 防御伤害，消耗 energy。
   - 破防攻击或 energy 不足：进入破防受击。
   - 真实伤害 isReal 不可防。
7. 命中后按原版 FighterMain.hit / beHit 的方向接入气槽增长：
   - 攻击者非必杀命中加 qi = min(power*0.16, 15)
   - 受击者加 qi = min(power*0.085, 20)
8. 增加 combo 计数、分数和 K.O. 测试 UI。
9. 保留前面版本里的 Aizen 动作、hitbox、HitVO、bsmc、zh3mc、XG_bs/XG_cbs、cut-in 脸图逻辑。

仍未宣称 100% 完成的部分：
1. 原版完整 GameCtrler / FighterEventDispatcher / Score 系统未整体移植。
2. 命中特效和防御特效当前只有日志占位；当前素材包没有完整通用命中特效导出到 Godot。
3. P2 完整玩家输入/AI 没有接入，P 键仍只是测试 P2 atk1。
4. O 支援/换人仍未实现。
5. 地图边界、摄像机、完整 UI 还需继续从原 SWF / XFL / AS 接。

测试建议：
1. 覆盖补丁后进入 Aizen VS Aizen。
2. 按 T 充满气，测试 I / W+I / S+I / 空中 I。
3. 按 H 看攻击面。
4. 按 S 单独防御，再按 P 让 P2 攻击，观察防御扣血/energy。
5. 连按 J / U / W+U 等，观察 combo、score、qi 和 KO。
