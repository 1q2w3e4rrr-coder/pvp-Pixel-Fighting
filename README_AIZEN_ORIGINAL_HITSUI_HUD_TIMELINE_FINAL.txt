# BVN Aizen Original HitsUI / HUD Timeline Final Patch

本补丁继续按原版 SWF/XFL/AS 逻辑靠近：

1. O 键继续完全忽略，不做支援/换人。
2. 保留上一版所有蓝染动作、HitVO、攻击面、被打面、Qi/Energy、KO/TimeOver、startKOmc 序列、MCNumber 时间/分数/连击数字。
3. 新增 scripts/ui/OriginalHitsDisplay.gd，对应原版 HitsUI.as + fight.xfl 的 hits_mc / mc_018.xml。
4. 连击显示不再只是显示/隐藏数字，而是按原版：
   - 第一次连击：gotoAndPlay("fadin")
   - 连击数更新：gotoAndPlay("update")
   - 连击消失：gotoAndPlay("fadout")
5. 复刻 mc_018.xml 关键帧中的 ct 数字层与 hitsmc 文字层的缩放和位移。
6. 按 HitsUI.as 处理 hits1 的 xoffset：P1 连击数字宽度变化时，外层位置会反向修正。
7. FightTimeUI 的时间数字位置按原版 _numMc.x=-22, _numMc.y=-15 重新校正到 time_mc 原点。

仍未完全像素级还原的部分：mc_018 motion tween 的 acceleration 曲线现在使用线性近似；score_mc/time_mc 外层只有静态组合，没有完整 UI fadin/fadout 时间轴。下一步如果继续，应渲染 ui_fight / mc_040 的全 HUD fadin/fadout 时间轴。
