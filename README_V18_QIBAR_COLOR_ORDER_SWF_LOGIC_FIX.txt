BVN Godot v18 qibar color order SWF logic fix

只改 scripts/ui/FightHud.gd。

原版依据：
- QiBar.as / InsBar.setProcess(v)
- fight.xfl: mc_026(qbar_mc) -> mc_022(qbar_barmc) -> mc_020(qbar_barmcgroup)
- mc_020: bar1=mc_008/picture_053 蓝青，bar2=mc_009/picture_054 黄绿，bar3=mc_010/picture_055 橙，bar4=mc_011/picture_059 红

修正：
1. 不再让 qibar_frame.png 静态帧里烘入的红色/满段颜色参与常态显示。
2. 用 track mask 遮掉静态帧内的彩色条区域。
3. 按原版 InsBar.setProcess 的 visible + scaleX 顺序绘制：
   0-100: bar1 蓝青增长
   100-200: bar2 黄绿覆盖增长
   200-300: bar3 橙色覆盖增长
   >=300: bar4 红色满槽显示
4. P2 仍保持从右往左增长；txtmc 仍只显示一个层数数字。

没有新增图片素材，没有生成替代图。
