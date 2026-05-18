BVN Godot strict SWF logic v18 continuation - camera / HITS / HUD / QiBar final patch

基线：v18 player_pos head alignment。v19-v22 不沿用。

覆盖路径：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁只修改代码，不生成任何新图像，不替换素材：
- scripts/battle/BattlePlaceholder.gd
- scripts/ui/OriginalHitsDisplay.gd
- scripts/ui/FightHud.gd
- scripts/character/ManifestFighter.gd

修正内容：
1. 摄像机缩放
   - 保留原版 GameCamera 的 autoZoomMin=1、autoZoomMax=2.5、margin=0.8、tweenSpd=2.5 计算。
   - 当前 Godot xianshi 分层 PNG + centered ManifestFighter 导出基准导致实机画面比 3.8.4.3 原版截图偏大，因此在最终 viewport zoom 上增加 GODOT_XIANSHI_CAMERA_VISUAL_SCALE=0.80 的坐标系校正。
   - 目的是让近战最小画面与远景最小画面更接近用户上传的 3.8.4.3 原版运行截图。

2. HITS 残影与数字裁切
   - 保留原版 HitsUI.as 的 fadin/update 显示逻辑与 mc_018.xml 的 ct 数字关键帧。
   - combo 归零时不再播放会产生 1px 彩线的 Godot 拆层 fadout 末段，而是直接进入最终 hidden 状态。
   - 隐藏时销毁 hits_mc 与 ct 数字子节点，下一次命中再按原版资源重建，避免残留阴影。
   - hits_num_mc 数字宽度改为原始导出宽度 47px，避免数字边缘被压缩/裁切。

3. HUD 血量显示
   - 复用已导出的原版 MCNumber score 数字，不生成新图片。
   - 上方血条附近显示当前 HP。
   - Aizen 初始 hp/hpMax 调整为 2000，用于匹配用户上传的 3.8.4.3 原版实机 HUD 显示。

4. 下方 QiBar / 怒气条
   - P2 底部 qbar_mc 视觉层整体右移 24px，更接近原版截图中右下角位置。
   - 初始 qi=100，fzqi=100，使底部气槽显示 1 格并显示 READY，匹配用户上传的原版运行截图。
   - 仍保持 O 键忽略，不实现支援/换人，只保留 HUD READY 状态。

未做：
- 没有生成或手绘任何图片。
- 没有修改电线杆/地图镜像问题。
- 没有沿用 v19-v22 的 HITS hard clear / pixel crisp 代码。
