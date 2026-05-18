BVN Godot v18 基线继续修正：近战镜头尺寸 + HITS 残影最终补丁
================================================================

覆盖路径：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

当前基线：
bvn_aizen_strict_swf_logic_final_v18_playerpos_head_align_patch.zip

本补丁只修改：
1. scripts/battle/BattlePlaceholder.gd
2. scripts/ui/OriginalHitsDisplay.gd

一、近战最小画面 / 放大比例

原版依据：
- GameCamera.as：autoZoom 仍按 screenSize / distance * 0.8 计算，并 clamp 到 autoZoomMin / autoZoomMax。
- GameStage.as：initCamera() 初始化时 camera.setZoom(2)，用于开局近战镜头。
- 当前 Godot Demo 使用 normalized centered Sprite2D + 本地角色 scale/pivot，直接使用 autoZoomMax=2.5 时，近战最小画面相对你提供的原版 3.8.4.3 运行截图更放大，人物和地图元素都偏大。

本次修正：
- 保持原版 GameCamera 的 autoZoom 公式、0.8 margin、tweenSpd=2.5、stage bounds clamp 结构不变。
- 当前单回合 Demo 的近战最大缩放限制到原版 initCamera 的 close zoom = 2.0。
- 这样近战最小画面不再继续放大到 2.5，人物尺寸会更接近原版截图。

二、HITS 消失残影 / 彩色细线

原版依据：
- HitsUI.as：hide() 调用 _mc.gotoAndPlay("fadout")。
- fight.xfl / mc_018.xml：fadout 从 frame50 开始，frame55 执行 gotoAndStop(1)。
- mc_018 frame1 脚本为 stop(); this.visible=false;。

当前 Godot 问题：
- Godot 版把 FFDec 导出的 hits_mc 位图层和 ct 数字层分开绘制。
- 如果继续播放原版 fadout 的压扁末帧，TextureRect / MCNumber 独立层会留下 1px 阴影或彩线。

本次修正：
- combo 归零时，不再渲染压扁末帧，而是直接进入原版最终隐藏状态：frame1 visible=false。
- 清空 hits_timeline_rect.texture。
- 清空/隐藏 ct 数字层。
- 使用 self_modulate=0 与 set_process(false) 双保险，避免 FightHud 后续 alpha 刷新把隐藏节点重新露出来。
- BattlePlaceholder.gd 中先 update_combo_timers，再 update_resource_ui，确保 combo 归零当帧 HUD 立刻清空。

三、没有改动

没有修改：
- P1/P2 player_pos v18 头顶贴合逻辑
- xianshi frontLayer 柱子透明逻辑
- QiBar / EnergyBar / HPBar
- Round 1 / Fight / 无限时间 / 隐藏 SCORE
- Aizen 技能、HitVO、bisha cut-in、XG_bs/XG_cbs
- O 键仍忽略，不做支援/换人

四、测试

1. 覆盖补丁后运行 Aizen VS Aizen。
2. 两人靠近时，画面不应再像之前那样放得过大，人物应更接近原版 3.8.4.3 截图比例。
3. 打出 HITS 后，combo 消失时不应留下黄色/橙色阴影或细线。
4. P1/P2 标识、柱子透明、QiBar、Round 1 音频不应受影响。
