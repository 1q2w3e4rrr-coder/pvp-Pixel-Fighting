修复 FightHud.gd 第704行 _mc040_piecewise 参数数量错误。
原因：_mc040_piecewise 需要 7 个关键帧点，但 time 层只传了 6 个。
修复：补一个末尾保持点 49.0, v2，不改变视觉逻辑，只让 Godot 4.6 正常解析。
