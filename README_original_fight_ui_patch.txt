BVN Aizen 原版 fight.swf HUD 贴图补丁

覆盖到：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁只替换/新增 UI 层：
- scripts/ui/FightHud.gd
- assets/ui/fight/*.png

已确认来源：
- OpenBleachVsNaruto-master/swf_source/embed/fight/DOMDocument.xml
- OpenBleachVsNaruto-master/swf_source/embed/fight/LIBRARY/元件/mc_044.xml = ui_fight
- mc_040.xml = hpbar_mc
- mc_033.xml = hpbar_barmc
- mc_034.xml = hpbar_facemc
- mc_035.xml = hpbar_facegroup
- mc_032.xml = energy_bar
- mc_031.xml = energybar_barmc
- mc_026.xml = qbar_mc
- mc_022.xml = qbar_barmc
- FightUI.as / FightBar.as / FighterHpBar.as / QiBar.as / EnergyBar.as

改动：
1. O 键继续忽略，不做支援/换人。
2. 顶部 HP、头像框、红色延迟扣血条、energy 防御能量条改用 embed/fight 的原版位图资源。
3. Qi 蓝条移到原版 ui_fight 坐标：P1 约 (84,558)，P2 约 (525,558)，不再放在顶部临时位置。
4. QiBar 显示逻辑按原版 InsBar.setProcess：qi/100 最大 3 段，0-1、1-2、2-3 分段显示，>=3 显示第 4 层满气效果。
5. FighterHpBar 红条逻辑按原版方向：受击时红条延迟下降，普通受击和击飞延迟不同。

尚未完整做：
- fight.swf 的 fadin/fadout 时间轴动画。
- hits_mc 的完整 MovieClip 数字动画；当前仍用 Label 显示 combo。
- 原版字体数字 MCNumber 全套贴图数字渲染。
