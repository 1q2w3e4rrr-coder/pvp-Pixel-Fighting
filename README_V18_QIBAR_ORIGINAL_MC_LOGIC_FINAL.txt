BVN Godot v18 - qbar_mc / QiBar.as original logic patch

覆盖到：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁只修改：
scripts/ui/FightHud.gd

修改原则：
- 不生成新图片素材。
- 继续使用已上传/已导出的原版 fight.swf / fight.xfl 资源。
- 底部怒气条按原版 QiBar.as + qbar_mc(mc_026) + qbar_barmc(mc_022) 的嵌套逻辑处理。

核心逻辑：
1. qbar_frame 作为底层外观。
2. bar1 / bar2 / bar3 / bar4 按 qi / 100 连续 scaleX。
3. P1 按本地左侧增长，视觉为从左到右。
4. P2 对应原版 fzqi2 的 Matrix a=-1，视觉为从右到左。
5. qibar_frame 静态图中烘入的 0 被遮住，动态 txtmc 只显示一个数字：0/1/2/3。
6. qbar_facemc / readymc / sp 等节点保留在 qbar_mc 结构下，不再当作独立截图乱摆。

测试重点：
- 左下 P1 蓝条从左往右增长。
- 右下 P2 蓝条从右往左增长。
- 层数数字同一时间只出现一个。
- fadin/fadout 仍使用原版 qbar_mc 序列。
