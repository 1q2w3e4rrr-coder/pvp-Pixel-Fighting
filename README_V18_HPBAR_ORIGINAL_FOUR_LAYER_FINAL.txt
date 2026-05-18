BVN Godot v18 - Original FighterHpBar four-layer final patch

覆盖到：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁只处理顶部血条，不改技能、地图、HITS、QiBar、镜头。

原版依据：
1. fight.xfl / mc_033.xml = hpbar_barmc。
2. mc_033.xml 内部层级：
   - picture_076：底框 / 空槽
   - mc_004 redbar：picture_062，Matrix tx=-260
   - mc_005 bar：shape_004 / picture_047
   - picture_008：玻璃高光，Matrix tx=1.5, ty=1
3. FighterHpBar.as：
   - _bar.scaleX = fighter.hp / fighter.hpMax
   - redbar 延迟追随 _bar.scaleX

本次修改：
- scripts/ui/FightHud.gd
- assets/ui/fight/hpbar_frame.png      <- 原版 images/133.png / picture_076
- assets/ui/fight/hpbar_redbar.png     <- 原版 images/127.png / picture_062
- assets/ui/fight/hpbar_greenbar.jpg   <- 原版 images/130.jpg / picture_047
- assets/ui/fight/hpbar_top_glass.png  <- 原版 images/56.png / picture_008

说明：
- 没有生成自制图片，只复制原版 fight.swf / FFDec 导出的图片资源。
- 不再从 hpbar_frame.png 截绿色区域。
- 不再用 ColorRect 遮罩模拟空槽。
- 绿色 bar 位于 redbar 上层，玻璃高光位于最上层。
