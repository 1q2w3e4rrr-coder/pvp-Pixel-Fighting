BVN Godot Aizen strict SWF logic final v16

本补丁接在 v15_xianshi_front_displaylist_patch 之后。

修正内容：
1. 角色边界：
   - 对齐原版 MapMain 的 line_left / line_right 边界思想。
   - 当前 xianshi.swf mapLayer 宽 1000，因此在 Godot 中将角色 x 限制到地图活动范围内，避免 camera 到边缘后角色继续走出 800x600 画面。
   - 普通 A/D 移动、dash、moveToTarget 后都会执行边界夹取。

2. HITS 残影：
   - combo 中断时不再播放会留下细线的 fadout 末段。
   - 强制隐藏父节点、清空 hits_mc 贴图、隐藏 ct 数字层并重置 scale，避免 combo>=2 消失时残留阴影/彩线。

3. P1/P2 指示标识：
   - 恢复原版 player_pos_p1 / player_pos_p2。
   - 按 FightUI.as 的 renderPlayerPosUI：camera zoom > 1.8 时隐藏，否则显示。
   - 两人距离拉远时 GameCamera 自动缩小 zoom，因此 P1/P2 标识才会出现。
   - 位置按 GameStage.getGameSpriteGlobalPosition(sp, 0, -50) 转换到 HUD 屏幕坐标，并按原版 clamp 到 x=20..780、y>=60。

未改动：
- v15 的 xianshi frontLayer 子元件透明逻辑。
- QiBar、Round 1 音频、隐藏 SCORE/0000000、无限时间、蓝染技能/HitVO/必杀 cut-in。
