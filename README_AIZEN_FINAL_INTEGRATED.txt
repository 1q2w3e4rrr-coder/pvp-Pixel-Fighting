BVN Godot Aizen integrated patch

覆盖到项目根目录：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本整合版包含此前所有蓝染补丁，并继续按原 SWF/XFL 接入：
1. 原版键位：J 普攻，S+J 砍技1，W+J 砍技2，U 招1，S+U 招2，W+U 招3，I 必杀，W+I 上必杀，S+I 超必杀，空中 J/U/I。
2. Aizen_1 / Aizen_2 必杀 cut-in 尺寸修正为原版 bisha_face_mc 逻辑的 254x180 近似显示。
3. XG_bs / XG_cbs 使用 additive 混合。
4. bsmc / zh3mc attacker 特效。
5. 原版攻击面调试框与 P2 bdmn 被打面。
6. HitVO 伤害、受击、击飞、硬直、HP 条。
7. 上必杀 justHitToPlay("sbs1", "上必杀_HIT") 跳转。
8. 超必杀 cbs2atm / cbsatm 攻击面。

调试键：
H = 开关攻击面/被打面调试框
P = P2 临时 atk1，用于测试 S+J 砍技1反击

说明：
这是当前 Godot demo 的“整合阶段最终版”，不是声称已经百分百完成原版引擎。
仍未完全实现的原版系统包括：防御判定、连击数、完整 qi/能量系统、命中特效/音效、KO/胜负流程、真实 currentTarget 多角色系统、全套 FighterAttacker 生命周期、角色全技能的视觉重渲染。
