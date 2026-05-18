BVN Aizen strict SWF logic final v10 - window/fullscreen and GenSe stage y patch

基于 v9 状态继续修正：
1. project.godot
   - 保持原版 800x600 viewport。
   - 增加 window/size/resizable=true，让窗口右上角可以最大化。
   - 增加 window/stretch/aspect="keep"，最大化/全屏时保持 4:3 原始画布比例，避免拉伸变形。

2. scripts/battle/BattlePlaceholder.gd
   - 修正蓝染战斗中人物可见脚底过低的问题。
   - 原版依据：OpenBleachVsNaruto/swf_source/map/GenSe/DOMDocument.xml 中 line_bottom.y=395，p1/p2.y=365。
   - MapMain.initlize() 中 offsetY = GameConfig.GAME_SIZE.y - bottom = 600 - 395 = 205，所以原版人物落点世界 y = 365 + 205 = 570。
   - 当前 Godot 使用 centered Sprite2D + actions_game 归一化帧，idle 可见脚底相对 Node2D 原点约 244 px；因此 Node2D ground_y 修为 570 - 244 ≈ 326。
   - 这不是截图手调，是按 GenSe.xfl 的出生点/底线和当前 FFDec 导出帧注册偏移换算。

没有修改：
- QiBar v8 MovieClip 序列逻辑。
- HITS v9 残影修复逻辑。
- Round 1 音频、隐藏 SCORE、无限时间、O 键忽略等逻辑。

如果后续要进一步像素级还原地图和相机：
需要继续从 GenSe.xfl/GenSe.swf 还原完整 map/front/bg 层、line_left/right/bottom/player_bottom、camera clamp，而不是继续使用单张 xianshi.png 静态图拉伸。
