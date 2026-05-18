BVN Aizen 原版 FightBar / QiBar Timeline Final Patch

本补丁在 bvn_aizen_original_hitsui_hud_timeline_final_patch 基础上继续推进。

原版依据：
1. FightUI.as：fadIn() 调用 FightBar.fadIn(animate) 与 QiBar.fadIn(animate)。
2. FightUI.as：fadOut() 调用 FightBar.fadOut(animate) 与 QiBar.fadOut(animate)。
3. FightBar.as：animate=true 时，hpbar_mc gotoAndStop("fadin" / "fadout")，renderAnimate 每帧 nextFrame()，直到 fadin_fin / fadout_fin。
4. QiBar.as：qbar_mc 同样通过 fadin / fadin_fin / fadout / fadout_fin 标签播放。
5. fight.xfl：mc_040.xml = hpbar_mc，标签：fadin frame 9，fadin_fin frame 24，fadout frame 34，fadout_fin frame 45。
6. fight.xfl：mc_026.xml = qbar_mc，标签：fadin frame 9，fadin_fin frame 14，fadout frame 32，fadout_fin frame 37。

这次新增：
- FightHud.gd 不再只用 alpha 淡入淡出 HUD。
- 顶部 FightBar 的血条、头像、Energy、Time、Score 按 mc_040 原版关键帧做位移动画。
- 底部 QiBar 按 mc_026 原版 fadin/fadout 帧段滑入/滑出。
- Energy 低值闪烁继续保留，并与 HUD 淡入淡出 alpha 叠加。
- O 键继续忽略，不恢复支援/换人系统。

仍未完成像素级复刻：
- mc_040 的 motion tween acceleration 已用二次 ease-out 近似，关键帧位置来自原版 XFL，但不是 Flash 插值器逐像素结果。
- mc_040 的 shape_007 顶部装饰线目前没有单独渲染完整层。
- qbar_mc 的辅助头像/辅助气条/fzqi 仍未完整接入，因为当前项目决定先不做 O 支援/换人。
