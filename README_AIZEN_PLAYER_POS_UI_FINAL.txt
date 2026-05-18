# BVN Aizen Player Position UI Final Patch

本补丁接上 qibar_facemc_timeline_final 进度。

按原版 FightUI.as 继续加入：
- player_pos_p1 / player_pos_p2
- 原版 FightUI 构造时通过 ResUtils.I.createDisplayObject(ResUtils.I.fight, "player_pos_p1/player_pos_p2") 创建
- renderPlayerPosUI(zoom) 中 zoom > 1.8 隐藏，否则跟随当前 fighter 的全局位置 (0, -50)
- getPlayerPos 中 x clamp 到 20..GAME_SIZE.x-20，y 至少 60

资源来源：
- fight.xfl / mc_047.xml = player_pos_p1，picture_082，matrix tx=-18 ty=-51
- fight.xfl / mc_046.xml = player_pos_p2，picture_018，matrix tx=-18 ty=-50

继续保持：
- O 键完全忽略，不做支援/换人
- 保留之前所有蓝染战斗、HUD、QiBar、EnergyBar、startKOmc、HitsUI、MCNumber、命中特效逻辑

测试：
1. 进入 Aizen VS Aizen
2. 看 P1/P2 头上是否出现原版小三角位置标记
3. 移动角色，图标应持续跟随角色头顶
4. 图标靠近屏幕边缘时应被限制在可见范围
5. O 键仍无反应
