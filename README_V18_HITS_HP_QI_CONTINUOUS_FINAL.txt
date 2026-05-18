BVN Godot v18 strict SWF logic - Hits / HP bar / Qi bar continuous final
=======================================================================

覆盖路径：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁继续基于 v18 当前有效基线，不沿用 v19/v20/v21/v22。
没有生成任何新图像素材，没有替换原版 PNG，只修改代码。

修改文件：
- scripts/ui/OriginalHitsDisplay.gd
- scripts/ui/FightHud.gd

修改依据：
1. HitsUI.as：
   - 第一次连击 gotoAndPlay("fadin")
   - 连击数更新 gotoAndPlay("update")
   - _txtmc = new MCNumber(hits_num_mc, 0, 1, 35)
   - xoffset = -_txtmc.width + 45
   - hits1 时 _mc.x = _orgPos.x - xoffset
2. fight.xfl / mc_018.xml：
   - ct 数字层 Matrix / scale
   - hitsmc 文字层 Matrix / scale
3. FighterHpBar.as：
   - _bar.scaleX = hp / hpMax
   - redbar 延迟跟随 _redbar.scaleX
4. QiBar.as / InsBar.setProcess：
   - qirate = fighter.qi / 100，最多 3
   - bar1/bar2/bar3 按小数部分 scaleX 连续变化
   - bar4 在 >=3 时显示
   - qbar_mc 只在 fadin/fadout 时间轴逐帧播放；持有状态不是只切 0/1/2/3 四帧。

修正内容：
1. HITS：
   - 恢复 fadin/update 的 Matrix/scale 动画。
   - 仍然不播放会产生 1px 黄色残线的 Godot 拆层 fadout 末段；combo 归零时直接进入最终隐藏状态。
   - 数字与 HITS 图标的大小和位置改回 mc_018.xml 的 ct/hitsmc 关键帧逻辑。

2. HP 血条：
   - HP 数字变化时，绿色前条也立即按 hp/hpMax 缩放。
   - 红色延迟条继续按原版 FighterHpBar.as 延迟追踪。
   - 修正之前 mc_040 时间轴位置更新把条形位置重置、导致视觉上看不出扣血的问题。

3. Qi 怒气条：
   - 持有状态下不再用 qbar_mc 整帧 0/1/2/3 档截图代替。
   - 改为按原版 InsBar.setProcess，对 bar1/bar2/bar3 做连续宽度变化。
   - qbar_mc FFDec 序列仍保留用于 fadin/fadout 时间轴播放。

测试重点：
1. 2/3/4/5 HITS 出现时，数字与 HITS 的大小、弹跳和间距应更接近原版。
2. HITS 消失后不应留下黄色横线阴影。
3. P2 被打扣血时，上方绿色血条应跟随 HP 数字缩短；红条稍后追上。
4. 下方 Qi 应随 qi 的小数进度连续填充，而不是只在 1/2/3 档变化。
