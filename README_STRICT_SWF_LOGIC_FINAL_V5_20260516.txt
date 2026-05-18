BVN Aizen strict SWF logic final v5 patch

基于 v4 继续修正，遵守：只按原版 SWF/XFL/AS 逻辑，不生成替代素材，不手调凑效果。

本次修改：
1. FightStartKOAnimator.gd
   - 原版 fight/mc_043.xml 的 startKOmc 声音层：frame 11 播 sound_007(round)，frame 57 播 sound_005(fight)。
   - 原版 round 数字 MovieClip mc_041.xml 内部还有 sound_001~sound_004，分别对应 Round 1~4 的数字音频。
   - 本项目固定 Round 1，所以在 Round 1 数字出现的原版时机播放 round_1.ogg（由 sound_001 原始音频转码）。

2. OriginalHitsDisplay.gd / FightHud.gd
   - 按原版 FightUI.showHits(hits, id) -> HitsUI.show(hits)，不再限制 hits >= 2；现在 hits >= 1 即显示。
   - 修复 HITS 图像一闪一闪：FFDec 导出的 hits_mc 序列左右状态交替，直接逐帧播放会闪；现在固定同一侧帧，数字 ct 层仍按 mc_018.xml 补间。
   - HitsUI 坐标改回 mc_044.xml 原始 Matrix：hits1=(62.15,121.95)，hits2=(662.15,121.95)。

3. FightHud.gd QiBar
   - qbar 坐标改为严格由 mc_044.xml + mc_026.xml 推导：
     fzqi1=(48,534.1)，fzqi2=(a=-1, tx=749, ty=534.1)，barmc=(35.95,24.45)。
     P1 barmc left-top=(83.95,558.55)，P2 barmc left-top=(522.05,558.55)。
   - qbar 图层顺序按 mc_022.xml 修正：bar 在下，外框 picture_063 与 txtmc 在上，避免蓝条盖住原版描边。
   - 数字位置改用 mc_022.xml txtmc Matrix 近似：tx=161.3, ty=11.25（在导出裁切下对应 Godot local y≈5.6）。

新增资源：
- assets/sfx/fight/round_1.ogg
  来源：OpenBleachVsNaruto/swf_source/embed/fight/DOMDocument.xml 中 声音/sound_001，转码为 Godot 4.6 可稳定播放的 ogg。
