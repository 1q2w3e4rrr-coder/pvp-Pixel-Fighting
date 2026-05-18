第 4 步补丁：修正蓝染普通必杀 bsmc 的 followTarget 行为。

覆盖到 Godot 项目根目录：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

在第 3 步 bsmc 基础上继续：
- bsmc 不再只是生成在 P2 当时位置，而是在播放期间持续跟随 P2 地面坐标。
- 对齐原版 addAttacker("bsmc", {x:{followTarget:true,offset:0}, y:{followTarget:true,offset:-25}, applyG:false})。
- 为 FFDec 导出 PNG 加入小的 anchor 修正 Vector2(6, -5)。
- 设置 fighter z_index=10，bsmc z_index=20，确保 bsmc 在人物上层但低于必杀 cut-in。
