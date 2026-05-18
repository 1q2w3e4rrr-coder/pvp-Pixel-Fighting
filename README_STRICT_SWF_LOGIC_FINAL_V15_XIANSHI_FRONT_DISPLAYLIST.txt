BVN Godot strict SWF logic final v15 - xianshi front display list / optical patch

本补丁接在 v14_xianshi_front_layer_patch 之后，只修 xianshi 地图前景层，不改 HUD、HITS、QiBar、Round、蓝染技能逻辑。

原版依据：
1. xianshi.swf 根时间轴 PlaceObject2：
   bg  = char 3  depth 1  x=0     y=0
   map = char 12 depth 3  x=0     y=-80.2
   front = char 18 depth 8 x=430.5 y=166.5
   p1 = x=374.1 y=365.0
   p2 = x=637.1 y=365.0
   line_bottom y=395.15，line_player_bottom y=365.15
2. MapMain.initlize(): offsetY = GameConfig.GAME_SIZE.y - bottom，所以 frontLayer.y += offsetY。
3. MapMain.render(): frontLayer.x = gameX * 0.1 + _defaultFrontPos.x; frontLayer.y = max(_defaultFrontPos.y, (gameY + bottom) * 0.1 + _defaultFrontPos.y)。
4. MapMain.renderOptical(): frontLayer 的每个子 MovieClip 与角色 area 相交时 alpha=0.5，否则 alpha=1。

本次改动：
- 不再直接把 FFDec 导出的扁平 front_layer_candidate.png 整张盖在角色上。
- 按 DefineSprite_18 的 display list 重建 front 子元件：front_pole.png 与 front_fence.png。
- front 默认位置改为原版 root Matrix + offsetY：x=430.5, y=371.5。
- 每帧按原版 0.1 视差更新 frontLayer。
- 每个前景子元件单独执行 alpha=0.5 的 renderOptical，避免整根柱子完全遮住角色。

新增资源：
assets/maps/xianshi_layers/front_pole.png   <- DefineSprite_15/1.png
assets/maps/xianshi_layers/front_fence.png  <- DefineSprite_17/1.png

仍未完成：
- front_fix 如果后续在原版 SWF 里找到独立层，需要继续按 display list 接入。
- 角色 area 目前使用当前项目已接入的 bdmn hurt rect。若后续从蓝染 XFL 接入每帧 body area，则 renderOptical 会继续更准确。
