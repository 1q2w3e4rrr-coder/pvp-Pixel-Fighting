BVN Aizen FFDec original fight UI frames patch

本补丁使用用户从原版 FighterTester_ORG.swf 内嵌 fight.swf 中用 FFDec 导出的真实 Sprite PNG。
没有使用手绘/近似生成资源。

已替换/接入：
- startKOmc: DefineSprite_217, 317 帧，按原版帧段切入 start/ko/winner/timeover/drawgame。
- hits_mc: DefineSprite_55, 56 帧，作为 HitsUI 原版时间轴图层。
- MCNumber digits: hits_num_mc / txtmc_score / time_txtmc。
- player_pos_p1 / player_pos_p2。
- hpbar_barmc / energybar_barmc / qbar_barmc / qbar_fzqi_mc / qbar_facemc 等静态 Sprite。

仍按原版 AS 逻辑驱动：FightUI / FightBar / QiBar / EnergyBar / HitsUI / MCNumber。
O 键继续忽略；H/T/P 调试键仍禁用。
