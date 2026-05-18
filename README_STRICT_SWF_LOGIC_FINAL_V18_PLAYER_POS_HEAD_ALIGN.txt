BVN Godot strict SWF logic final v18 - player_pos head alignment

基于 v17 继续修 P1/P2 标识位置。

原版依据：
- FightUI.getPlayerPos(fighter) 使用 GameStage.getGameSpriteGlobalPosition(fighter, 0, -50)。
- player_pos_p1 / player_pos_p2 仍使用原版资源与 Matrix 偏移。

本次不改原版 (0,-50) 逻辑，只修正 Godot 当前蓝染 normalized PNG / scale / pivot 下
“ManifestFighter 节点中心 -> 原版脚底点”的换算量。
v17 的换算量过大，导致箭头底部压到角色脸部；v18 调整后，P1/P2 图像底部应贴近角色头顶。

修改文件：
- scripts/ui/FightHud.gd

测试：
1. 两人距离近、镜头放大时，P1/P2 仍隐藏。
2. 两人拉远、镜头缩小时，P1/P2 出现。
3. 标识底部应刚好贴近角色头顶，不再压到脸部。
4. 其它系统不受影响：边界、柱子透明、HITS、QiBar、Round 1 音频。
