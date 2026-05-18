BVN Aizen strict SWF logic final v8 - QiBar MovieClip sequence patch

基于 v7 继续，只处理底部主 QiBar / 怒气条显示层。

修改依据：
1. 原版 FightUI.as 创建 ui.fzqi1 / ui.fzqi2，并分别交给 QiBar。
2. QiBar.as 内部用 qbar_mc：fadIn/fadOut 通过 gotoAndStop("fadin"/"fadout") 后逐帧 nextFrame() 播放。
3. qbar_mc 对应 fight.xfl 的 mc_026.xml；barmc 对应 mc_022.xml；主气条不是手拼 UI，而是 qbar_mc MovieClip 的时间轴组合。
4. 本补丁直接使用用户已上传的 FFDec 原版 qbar_mc PNG 序列：assets/ui/fight/ffdec_sprites/qbar_mc/0000.png..0057.png。

本次变更：
- FightHud.gd 新增 qbar_mc 原版序列加载。
- 底部主 QiBar 不再优先显示旧的拼接式 frame/bar/num/facemc 层，改用原版 qbar_mc 序列贴图。
- qbar fadin/fadout 使用原版序列对应帧。
- hold 状态根据 qi 段数切换到原版序列中的 0/1/2/3 段代表帧。
- P2 使用同一序列水平镜像，保留原版 fzqi2 Matrix 镜像逻辑。

未新增手绘资源，也没有生成替代图。

注意：
- 这一步解决“底部怒气条不是原版 MovieClip 外观”的问题。
- 如果后续还要做到运行时 0.01 精度的连续缩放像素级一致，需要继续把 qbar_mc 子元件 barmc/bar/ghost/txtmc 的运行时状态逐帧递归渲染，或从 Flash/FFDec 导出带注册点的运行时状态序列。
