BVN Godot v18 HP / Qi 原版条层逻辑修正补丁

基线：
- 继续基于 v18 当前有效项目状态。
- 不沿用 v19 / v20 / v21 / v22。
- 不新增、不生成任何图片素材。

修改文件：
- scripts/ui/FightHud.gd

原版依据：
1. FighterHpBar.as:
   - _bar = _ui.bar
   - _redbar = _ui.redbar
   - _bar.scaleX = hp / hpMax
   - redbar.scaleX 延迟追随 _bar.scaleX
2. fight.xfl / mc_033.xml:
   - redbar 在底层，bar 绿色前条在 redbar 上层，picture_008 玻璃高光在更上层。
   - bar/redbar 子元件注册点在右侧；2P 由外层 bar2 Matrix a=-1 镜像。
3. QiBar.as / InsBar.setProcess:
   - v = qi / 100，最大 3。
   - bar1 visible = v > 0，bar2 visible = v > 1，bar3 visible = v > 2，bar4 visible = v >= 3。
   - bar1/bar2/bar3 按小数连续 scaleX，不是只在 1/2/3 档跳变。
   - txtmc.gotoAndStop(int(v) + 1)，同一时间只能显示一个层数数字。
4. fight.xfl / mc_022.xml / mc_020.xml:
   - qbar_barmc 包含 txtmc 和 bar(barmcgroup)。
   - qbar_mc 序列可作为整数段底层外观；连续填充仍由 bar1/bar2/bar3 叠加缩放实现。

修正内容：
1. 血条：
   - 绿色前条改为直接使用已导出的 hpbar_frontbar.png，不再从 hpbar_frame.png 截取。
   - redbar 在下，green/front bar 在上，glass 在最上。
   - 1P 按原版 mc_033 注册点从右端缩放；2P 按外层镜像后的视觉方向缩放。
2. 怒气条：
   - qbar_movie 使用原版 qbar_mc 的整数段帧作为底层外观。
   - 隐藏旧 qibar_frame / txtmc / facemc 前框，避免出现“01”这种数字叠加。
   - bar1/bar2/bar3 继续按 InsBar.setProcess 连续缩放。
   - P2 不再从中间开始变色，而是按镜像 qbar 的视觉左侧开始连续填充。
3. 层级：
   - 明确设置 HP 与 Qi 子节点 z_index，避免底图盖住动态前条。

覆盖方法：
关闭 Godot 后，将本补丁解压覆盖到：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

测试重点：
1. P2 扣血后，顶部绿色血条应在红色延迟条上层，并随 HP 数字变化缩短。
2. 底部怒气条只显示一个层数数字，不再出现 01/00 叠加。
3. P2 怒气条积攒不应从中间开始变色。
4. 不影响 v18 的 P1/P2 头顶标识、HITS、Round 1、无限时间、xianshi 前景透明。
