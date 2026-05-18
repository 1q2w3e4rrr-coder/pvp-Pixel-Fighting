# BVN Aizen MCNumber / Fight HUD Final Patch

本补丁继续按原版 SWF/XFL/AS 逻辑靠近：

1. O 键继续完全忽略，不做支援/换人。
2. 保留上一版所有蓝染动作、HitVO、攻击面、被打面、Qi/Energy、KO/TimeOver、startKOmc 逐帧播放层。
3. 新增 Godot 版 MCNumberDisplay，对应原版 net.play5d.kyo.display.MCNumber.as。
4. 从原版 OpenBleachVsNaruto/swf_source/embed/fight/fight.xfl 提取并解码：
   - time_txtmc = mc_016，对应 FightTimeUI 的数字
   - txtmc_score = mc_045，对应 FightScoreUI 的分数
   - hits_num_mc = mc_048，对应 HitsUI 的连击数字
5. FightHud 不再用 Label 显示时间、分数、连击，改为原版数字 MovieClip 贴图序列。
6. 移除屏幕底部调试按键提示，避免污染原版 HUD。
7. KO 得分补上原版 GameLogic.addScoreByKO 的核心逻辑：
   - 必杀 KO +2000
   - Perfect +20000
   - 普通胜利 +3000

仍未完成像素级还原的部分：HitsUI 的 fadin/update/fadout 动画曲线、scoremc/time_mc 的完整 MovieClip 外层时间轴动画，后续可以继续从 fight.xfl 递归渲染。
