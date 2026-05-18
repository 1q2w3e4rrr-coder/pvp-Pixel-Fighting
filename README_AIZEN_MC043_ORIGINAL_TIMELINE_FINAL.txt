# BVN Aizen mc_043 Original Timeline Final Patch

这版在上一个 startKO animator 版本基础上继续向原版 SWF/XFL 靠近：

1. O 键继续忽略，不做支援/换人。
2. `FightStartKOAnimator.gd` 继续按 `OpenBleachVsNaruto/swf_source/embed/fight/LIBRARY/元件/mc_043.xml` 的 label 与脚本帧驱动：
   - start = 9
   - fight_in = 54
   - fight = 57
   - complete = 87
   - ko = 144-189
   - winner = 199-209
   - timeover = 219-262
   - drawgame = 266-308
3. 这次不再使用纯 fallback 文字图，而是把 mc_043 依赖的 shape_008~025 中的原版 bitmapDataHRef 解码成 PNG：
   - fight.png <- shape_025 / picture_011
   - ko.png <- shape_012 + shape_013 + shape_014 + shape_013
   - timeover.png <- shape_009 / picture_016
   - drawgame.png <- shape_008 / picture_039
   - winner/perfect <- mc_042 相关 shape_010 / shape_011
   - round_1.png <- Round 字母 shape_020~024 + mc_041 的数字 1
4. 按 mc_043 的声音层补入 startKO 音效：
   - frame 11: sound_007 -> start_round.ogg
   - frame 57: sound_005 -> fight.ogg
   - frame 221: sound_009 -> timeover.ogg
   - frame 267: sound_008 -> drawgame.ogg
5. 按 `FightUI.as` 的 winner 位置逻辑：P1 winner x=30，P2 winner x=546；startKOmc.y=30。
6. 原版在 fight_in 帧已经显示 fight shape，本版不再显示临时 READY 字样。

仍未完成像素级还原：motion tween 的逐帧缩放/亮度/模糊曲线仍是 Godot 近似实现；如果后续要更精确，需要把 mc_043 每一帧按 Matrix、Color、Tween 参数递归渲染成完整 PNG 序列。
