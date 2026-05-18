BVN Godot v18 - HP green front bar / P2 Qi right-to-left final patch
====================================================================

覆盖到：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁基于当前 v18 有效基线继续，只处理 FightHud.gd 的原版血条/怒气条显示逻辑。
不沿用 v19-v22。

修改文件：
- scripts/ui/FightHud.gd

新增资源：
- assets/ui/fight/hpbar_greenbar.jpg

新增资源说明：
- hpbar_greenbar.jpg 不是手绘、不是生成替代图。
- 来源是用户已上传的原版 fight.swf FFDec full export：images/130.jpg。
- 对应 OpenBleachVsNaruto/swf_source/embed/fight/LIBRARY/元件/mc_005.xml 的 shape_004，
  shape_004 使用 DOMBitmapItem 图片/picture_047 作为 BitmapFill。
- 也就是原版 FighterHpBar.as 中 _ui.bar 实际显示的绿色前条来源。

原版依据：
1. FighterHpBar.as
   - _bar = _ui.bar
   - _redbar = _ui.redbar
   - _bar.scaleX = hp / hpMax
   - redbar.scaleX 延迟追随

2. fight.xfl / mc_033.xml
   - redbar 和 bar 都在 tx=263.95, ty=4.35
   - redbar 使用 mc_004 / picture_062
   - bar 使用 mc_005 / shape_004 / picture_047
   - bar 位于 redbar 上层

3. QiBar.as / InsBar.setProcess
   - _ui.bar.bar1.visible = v > 0
   - _ui.bar.bar2.visible = v > 1
   - _ui.bar.bar3.visible = v > 2
   - _ui.bar.bar4.visible = v >= 3
   - bar1/bar2/bar3 按小数 scaleX 连续增长
   - txtmc.gotoAndStop(int(v) + 1)，同一时间只显示一个层数数字

4. fight.xfl / mc_044.xml
   - fzqi1 Matrix tx=48, ty=534.1
   - fzqi2 Matrix a=-1, tx=749, ty=534.1
   - 因此 P2 是整个 qbar_mc 外层水平镜像，视觉上应从右往左增长。

本次修正：
1. 血条绿色前条不再从 hpbar_frame.png 截图区域引用，避免出现条纹/网格感。
2. 改用原版 picture_047 对应的 hpbar_greenbar.jpg 作为 front bar。
3. 红条 redbar 在绿色条下面，绿色 front bar 在红条上面。
4. P2 怒气条不再被 _apply_original_qibar_frame 覆盖位置，确保从右往左增长。
5. 怒气层数数字继续保持一个，随 int(qi/100)+1 切换，不再叠字。

测试重点：
1. P2 扣血后，右上绿色血条应是纯绿色/原版绿色质感，不再是网格状。
2. P2 扣血后，绿色条在最上层，红色延迟条在下面。
3. 左下 P1 怒气从左往右增长。
4. 右下 P2 怒气从右往左增长。
5. P1/P2 怒气层数数字同一时间只显示一个。
