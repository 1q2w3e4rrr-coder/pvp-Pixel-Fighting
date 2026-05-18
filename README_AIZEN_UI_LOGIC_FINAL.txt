BVN Godot Aizen UI Logic Final Patch

本补丁基于 bvn_aizen_system_final_patch 继续整理：

1. O 键已完全忽略
   - 不再读取 KEY_O。
   - 不再输出 O pressed 日志。
   - 后续支援/换人系统不做。

2. 新增 scripts/ui/FightHud.gd
   逻辑对照原版 AS：
   - FightUI.as：战斗 HUD 总控，每帧 render FightBar / QiBar / HitsUI。
   - FightBar.as：P1/P2 头像组、HP、Energy、时间、Score。
   - FighterHpBar.as：HP 前条立即变化，redbar 延迟下降。
   - QiBar.as：qi / 100，最多显示 3 段。
   - EnergyBar.as：energy / energyMax，低于 0.3 时闪烁。
   - HitsUI.as：连击数 >= 2 时显示。

3. 当前视觉说明
   由于当前上传文件里没有 FFDec 直接导出的 fight.swf/ui_fight PNG 序列，本补丁用 Godot ColorRect/TextureRect 先复刻 UI 结构与更新逻辑。
   这不是最终原版皮肤，但比之前临时 HP/QI 文本条更接近原版 FightUI 的结构。

4. 如果要继续做“图片一比一”
   请从 OpenBleachVsNaruto\swf_source\embed\fight\fight.xfl 或编译后的 fight.swf 中导出下列元件 PNG/序列：
   - ui_fight
   - hpbar_barmc
   - hpbar_facegroup
   - hpbar_facemc
   - energy_bar
   - energybar_barmc
   - qbar_mc
   - qbar_fzqi_mc
   - hits_mc
   - hits_num_mc
   - time_mc
   - time_txtmc
   - score_mc
   - txtmc_score
   - winmc

覆盖方式：
将本补丁内容解压到 bvn-godot 项目根目录。
