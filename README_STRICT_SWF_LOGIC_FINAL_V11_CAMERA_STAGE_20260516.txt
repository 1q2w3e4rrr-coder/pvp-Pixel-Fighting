BVN Aizen strict SWF logic final v11 - window stretch + original GameCamera/GenSe stage pass

基于 v10 继续修：
1. project.godot 将 stretch/mode 改为 viewport，保持 800x600 虚拟画布，窗口最大化时按 4:3 等比放大。
2. BattlePlaceholder.gd 改为原版 GameStage 层级思路：
   - fixed bgLayer 留在根层，不参与 camera。
   - gameLayer 内放 mapLayer / playerLayer / common effect，统一由 camera scroll/scale。
3. 使用原版 GenSe.xfl / MapMain.as / GameStage.as / GameCamera.as 数据：
   - line_bottom=395，line_player_bottom=365，offsetY=205。
   - p1=(370.1,570)，p2=(643.55,570) 的原版出生点逻辑。
   - camera autoZoomMin=1，autoZoomMax=2.5，margin=0.8，tweenSpd=2.5。
   - offsetY=bottom-playerBottom=30。
4. 当前项目的 Aizen PNG 是 normalized centered Sprite2D，所以 local fighter scale 改为 1.25，Node2D y 用原版 playerBottom 与 idle 脚底偏移换算。
5. 新增 assets/maps/gense_bg.png，来自 GenSe.xfl 的 picture_01 / M 4 1481511437.dat 原版背景层。

注意：
- 当前仍只有 xianshi.png 合成图作为 mapLayer 的临时源，所以 map/front 还不是最终像素级分层。
- 若要继续做到真正原版地图像素级，需要从 GenSe.xfl/fight map 导出 picture_02(map) 与 picture_03(front) 的透明 PNG 或 FFDec/SWF 分层序列。
