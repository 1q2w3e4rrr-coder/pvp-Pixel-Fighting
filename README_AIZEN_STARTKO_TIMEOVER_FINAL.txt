BVN Godot Aizen startKO/timeover final integration patch

本补丁继续按 OpenBleachVsNaruto 原版 FightUI.as / FightBar.as / FighterHpBar.as / FightTimeUI.as / HitsUI.as 的逻辑推进：

1. O 键继续完全忽略，不做支援/换人。
2. 继续保留前面所有蓝染动作、HitVO、攻击面、被打面、必杀、Qi/Energy、combo、KO、原版 fight HUD、命中/防御/破防特效。
3. 修正 FightUI.showStart 的时间点：原版 startKOmc 从 label start(frame 9) 开始，frame 54 派发 fight_in，frame 57 派发 fight，frame 87 COMPLETE。
4. 增加 startKOmc 近似事件序列：ROUND -> READY(fight_in) -> FIGHT，并按 frame 57 解锁输入。
5. 增加 FightTimeUI 逻辑：Demo 默认 99 秒，HUD 显示倒计时；如设 DEMO_GAME_TIME_MAX=-1，则显示无限。
6. 增加 Time Over / Draw Game / Winner 流程：按原版 timeover/drawgame/winner label 的时长推进。
7. KO 流程更接近原版：先播放 snd_over_hit + shake/shine，延迟 500ms 后播放 KO；如果 KO 发生在必杀动作中，使用 snd_ko_bs。
8. KO/TimeOver 后 Qi bar 按原版 fadOut 思路淡出。
9. HUD 增加 fadin/fadout/qibar_fad_in/qibar_fad_out 接口，给后续完整复刻 fight.swf 时间轴保留入口。

仍未完全像素级完成：startKOmc/winner/timeover/drawgame 的矢量 MovieClip 每一帧渲染。若要完全还原，需要继续从 embed/fight/mc_043.xml 递归渲染 shape_008~shape_025、mc_041、mc_042 的时间轴帧。
