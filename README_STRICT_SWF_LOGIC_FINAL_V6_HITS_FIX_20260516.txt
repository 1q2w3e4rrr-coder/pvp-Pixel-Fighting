BVN Aizen strict SWF logic final v6 - HitsUI overlap fix

基于 bvn_aizen_strict_swf_logic_final_v5_patch.zip。

本次只修复：连击数字与 HITS 文字重合。

原版依据：
1. HitsUI.as 中 _mc.ct.addChild(_txtmc)，数字层挂在 hits_mc 的 ct 内。
2. show(num) 中：
   xoffset = -_txtmc.width + 45
   _txtmc.x = xoffset
   hits1 时 _mc.x = _orgPos.x - xoffset
3. fight.xfl / mc_018.xml 中：
   ct 数字层 Matrix tx=-23.5
   hitsmc 文字层 Matrix tx=65.05, ty=3

v5 的问题：
- FFDec 导出的 hits_mc_sequence 帧本身包含整张 MovieClip 画布。
- v5 为了消除闪烁固定使用同一侧帧，但把 hits_timeline_rect 放在 (0,0)，导致 HITS 文字从 x=0 开始，与 ct 数字层重合。

v6 修复：
- OriginalHitsDisplay.gd 中把 hits_timeline_rect.position 改为 Vector2(65.05, 0.0)。
- 数字层仍按原版 ct Matrix / xoffset / fadin-update-fadout 逻辑运行。
- 不新增自制资源，不替换原版资源。

覆盖文件：
- scripts/ui/OriginalHitsDisplay.gd
