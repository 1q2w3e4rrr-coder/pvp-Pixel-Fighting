BVN Godot Aizen strict SWF logic final v13 - Xianshi SWF layer map patch

基于 v12 继续。

这次只做原版 xianshi.swf 地图层替换和窗口启动最大化：
1. 不再使用早期 450x270 的 xianshi.png 放大作为地图主体。
2. 使用 FFDec 从原版 xianshi.swf 导出的真实层：
   - bg_stage.png <- sprites/DefineSprite_3/1.png, 800x600
   - map_layer.png <- images/4.png, 1000x397, 透明 PNG
   - front_layer_candidate.png <- sprites/DefineSprite_18/1.png, 1201x229，暂存，不叠加，避免与 map_layer 双影。
3. BattlePlaceholder.gd 中 map_layer 按原版 bottom=600、height=397 放在 y=203。
4. 取消旧 MAP_RENDER_SCALE = 1000/450 的缩放，避免地图、人物、地面比例不符合原版。
5. project.godot 设置 window/size/mode=2，运行项目时默认最大化；viewport 仍是 800x600，stretch/aspect=keep 保持 4:3。

注意：如果你是在 Godot 编辑器 2D 视图里看，看到的是编辑器画布，不代表运行窗口缩放效果。请用 F5 / Run Project 测试。
