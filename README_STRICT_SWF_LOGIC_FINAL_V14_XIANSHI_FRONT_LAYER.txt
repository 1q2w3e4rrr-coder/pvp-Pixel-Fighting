BVN Aizen strict SWF logic final v14 - xianshi frontLayer camera patch

基于 v13_xianshi_layered_map_patch 继续修正地图层级。

本次只按原版 SWF/AS 地图逻辑接入 frontLayer：
1. 使用 xianshi.swf FFDec 导出的 sprites/DefineSprite_18/1.png，项目内为 assets/maps/xianshi_layers/front_layer_candidate.png。
2. 对照 MapMain.as / GameStage.as：bgLayer 在根层，mapLayer 在 gameLayer，playerLayer 在 mapLayer 上方，frontFixLayer/frontLayer 在 playerLayer 上方。
3. frontLayer 放进 game_layer，z_index=90，使其位于角色和普通战斗特效上方；bisha/cut-in 仍保持在更高层级。
4. 对照 MapMain.render(gameX, gameY, zoom)：frontLayer.x = gameX * 0.1 + default.x；frontLayer.y = max(default.y, (gameY + bottom) * 0.1 + default.y)。
5. default.x 使用 frontLayer 宽 1201 与 mapLayer 宽 1000 的居中差值 -100.5；default.y 使用 bottom 600 - frontLayer 高 229 = 371。

未做：
- renderOptical 的逐子 MovieClip 半透明遮挡。FFDec 当前导出的 frontLayer 是扁平 PNG，已经失去每个 MovieClip 子对象的边界，不能凭空生成遮挡矩形。后续若需要完整复刻，需要导出 xianshi.swf 的 display list / frontLayer 子 MovieClip 边界。
- 没有改 HUD、HITS、QiBar、Round、技能逻辑。
