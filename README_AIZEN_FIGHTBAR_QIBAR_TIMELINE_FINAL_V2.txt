BVN Godot Aizen - 原版 FightBar/QiBar timeline final v2

本补丁接在 bvn_aizen_original_fightbar_qibar_timeline_final_patch 之后。

本次继续按原版 SWF / XFL / AS 逻辑修正：

1. 修复 FightHud.gd 第 704 行附近的 _mc040_piecewise 参数数量错误。
   _mc040_piecewise 需要 7 个关键帧点，_mc040_delta_time 现在补齐末尾保持点 49.0, v2。

2. 红色延迟扣血条改为更接近原版 FighterHpBar.as 的算法。
   原版：
      diffRed = _hprate - _redbar.scaleX
      addRateRed = diffRed < 0 ? 0.1 : 0.02
      _redbar.scaleX += diffRed * addRateRed
   Godot 版现在按 ORIGINAL_UI_FPS=24 转为 delta 无关算法。

3. show_fight_in fallback 不再显示 READY。
   之前已经确认 mc_043 frame54 = fight_in 进入 FIGHT 过渡，frame57 = fight。
   如果 FightStartKOAnimator 存在，仍以 startKOmc 序列为准。

4. O 键继续完全忽略，不做支援/换人。

保留上一版所有内容：
- Aizen J / S+J / W+J
- U / S+U / W+U
- I / W+I / S+I
- 空中 J / U / I
- HitVO / hitbox / hurtbox / HP / Qi / Energy / combo / KO / TimeOver
- 原版 fight UI 图片
- startKOmc 序列
- MCNumber 时间/分数/连击数字
- HitsUI fadin/update/fadout
- FightBar mc_040 与 QiBar mc_026 的 fadin/fadout 时间轴
- 命中特效 / 防御特效 / 必杀 cut-in

下一步如果继续靠近原版：
- 解析 QiBar.as 里的 fzqi 辅助气条、readymc、sp 提示。
- 解析 EnergyBar.as 里的 overLoad 第 3 帧资源，而不是用颜色临时模拟。
- 继续递归渲染 mc_040 / mc_026 的每一帧 Matrix / ColorTransform / Tween。
