BVN Aizen strict hotfix: timer and startKOmc position

依据原版源码：
1. FightTimeUI.as: gameTimeMax == -1 时 _renderTime=false，只显示 ui.wuxian，不刷新 MCNumber。
   当前 FFDec 原版 time_frame.png 已包含无限符号，所以 Godot 不再叠加 time_number_mc 或 infinity_time_rect。
2. FightUI.as: showStart() 设置 ui.startKOmc.y = -50；playKO()/playTimeOver() 设置 ui.startKOmc.y = 0。
   当前 Godot 的 FightStartKOAnimator 不再居中/下移 startKOmc，而是按原版 x=0, start y=-50, end y=0。

覆盖文件：
scripts/ui/FightHud.gd
scripts/ui/FightStartKOAnimator.gd

没有新增自制 UI 图，也没有手调技能坐标。
