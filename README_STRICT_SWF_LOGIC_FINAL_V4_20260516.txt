BVN Aizen strict SWF logic final v4 patch

基于 v3 继续修正用户指出的 4 个画面问题。

本次修改文件：
- scripts/ui/FightHud.gd
- scripts/ui/FightStartKOAnimator.gd

本次严格依据：
1. OpenBleachVsNaruto swf_source/#FighterTester/src/net/play5d/game/obvn/ui/fight/FightUI.as
2. OpenBleachVsNaruto swf_source/#FighterTester/src/net/play5d/game/obvn/ui/fight/QiBar.as
3. OpenBleachVsNaruto swf_source/#FighterTester/src/net/play5d/game/obvn/ui/fight/HitsUI.as
4. OpenBleachVsNaruto swf_source/embed/fight/LIBRARY/#U5143#U4ef6/mc_026.xml
5. 原版 fight.swf/FFDec 导出的 startKOmc、qbar_mc、hits_mc 资源

修正内容：
1. 底部 QiBar：
   - qbar 主 face/front 框不再只在 fzqi 显示时出现。
   - 按 mc_026.xml 中 facemc Matrix 计算主气槽头像框位置：
     facemc final=(-10.55,5)，barmc final=(35.95,24.45)，偏移=(-46.5,-19.45)。
   - P2 侧按 Godot 水平翻转后的 qbar_frame 宽度镜像放置。

2. 角色头顶 P1/P2 图标：
   - 不再实例化 player_pos_p1/player_pos_p2 到画面。
   - update_state 中也强制隐藏。

3. Round 2 问题：
   - FFDec 导出的 startKO 序列不会执行 mc_043 的 go:fight 标签，所以会把 Round 2 过渡帧导出。
   - v4 在 FightStartKOAnimator 的 start frame map 中跳过 local>=42 的 Round 2 段，直接进入 Fight 段。
   - 音效仍按原版声音层：frame 11 只播放 start_round，frame 57 播放 fight；没有额外伪造 “1” 的音频。

4. HitsUI：
   - HUD 淡入淡出不再强制把 hits1/hits2 设为 visible。
   - 连击 UI 只由 OriginalHitsDisplay.show_hits/hide_hits 控制：无连击时隐藏，combo>=2 时 fadin/update，combo 计时归零后 fadout。

没有做的事：
- 没有手绘或生成替代素材。
- 没有手调蓝染技能特效坐标。
- 没有实现 O 支援/换人。

如果后续继续像素级修正技能特效位置，需要继续从 Aizen XFL 的 attacker MovieClip registration point、Matrix、FFDec 导出 bounds 计算。
