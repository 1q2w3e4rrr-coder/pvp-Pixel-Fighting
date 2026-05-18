BVN Aizen strict SWF-logic final v2 patch
========================================

覆盖到项目根目录：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁基于 bvn_aizen_strict_final_current_patch.zip 继续，只做有原版 SWF/AS 依据的修正，不新增自制素材，不生成替代图，不手调技能坐标。

本次新增的严格修正：
1. BishaEffectPlayer.gd 的必杀脸图左右位置不再用 facing 近似。
2. 按原版 EffectCtrler.showFace() 逻辑：
   - faceId 默认 1；
   - 如果 currentTarget 存在，并且发动者 target.getDisplay().x > currentTarget.getDisplay().x，则 faceId = 2；
   - 也就是发动者在目标右侧时使用 facemc2，否则使用 facemc1。
3. BattlePlaceholder.gd 在蓝染 I / W+I / S+I / 空中 I 触发 bisha 时，把当前 Demo 的 currentTarget=P2 坐标传入 BishaEffectPlayer。
4. bsmc 的 followTarget 注释也改为当前 Demo 的原版语义：单目标模式下 currentTarget 固定映射 P2，不再写成“临时模拟”。

继续保留上一版所有严格 hotfix：
- 只显示 Round 1，跳过 FFDec 序列里的 Round 2 过渡帧。
- Fight 播放结束后清空，不残留。
- DEMO_GAME_TIME_MAX = -1，无限时间，不显示 00。
- 不显示 SCORE，也不显示 0000000。
- O 键继续忽略，不实现支援/换人。
- H / T / P 调试键正常游玩中关闭。
- 血条、Qi、Energy、HitsUI、startKOmc、MCNumber、player_pos、普通/上/空中/超必杀 cut-in 继续保留。

原版依据：
- EffectCtrler.as: bisha(target,isSuper,face) 内 showFace(target,face)。
- EffectCtrler.as: showFace 中 faceId 默认 1；若 target.getDisplay().x > currentTarget.getDisplay().x，则 faceId = 2。
- BlackBackView.as: showBishaFace(faceId,face)。
- BishaFaceEffectView.as: face.width=254, face.height=180。

未做的内容：
- 没有继续手调 bsmc / zh3mc 的视觉 Y 轴。
- 如果后续要像素级校正 attacker 贴图注册点，需要提取或生成带原点/矩阵元数据的 MovieClip 帧序列；不能只看 Godot 画面手调。
