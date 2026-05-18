BVN Godot Aizen strict final current patch - 2026-05-16
========================================================

覆盖路径：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁按当前上传的项目状态整理，不新增自制/占位素材，不生成替代 UI 图。
如果需要继续像素级还原，必须继续从原版 SWF / XFL / ActionScript / FFDec 导出资源，而不是手调或凑合。

一、本版已经确认保留 / 修正

1. SCORE / 0000000 已隐藏
   - 修改文件：scripts/ui/FightHud.gd
   - 不创建 OriginalScoreText。
   - 不创建 OriginalScoreMCNumber。
   - update_state() 不写入 score 数字。
   - 这不是删除原版资源，只是按当前单回合 Demo 要求不实例化 FightScoreUI 显示层。

2. 无限时间显示修正
   - 修改文件：scripts/ui/FightHud.gd, scripts/battle/BattlePlaceholder.gd
   - BattlePlaceholder.gd 中 DEMO_GAME_TIME_MAX = -1。
   - FightHud.gd 中无限时间分支不显示 00，不额外叠加 infinity_time_rect。
   - 只保留 FFDec 原版 time_mc / time_frame.png 中自带的无限符号。

3. Round / Fight / startKOmc 修正
   - 修改文件：scripts/ui/FightStartKOAnimator.gd
   - start 阶段使用原版 startKOmc 帧段。
   - 单回合 Demo 固定 Round 1，跳过 FFDec 导出中不会执行 go:fight 而残留出的 Round 2 过渡帧。
   - start 完成后清空 texture，避免 Fight 文字残留。
   - showStart 位置按原版 FightUI.as：startKOmc.y = -50；KO / TimeOver 等结算分支 y = 0。

4. 正常游玩调试键关闭
   - 修改文件：scripts/battle/BattlePlaceholder.gd
   - ORIGINAL_DEV_KEYS_ENABLED = false。
   - H / T / P 调试键默认不生效。
   - O 键继续不接支援/换人，不输出调试日志。

5. 蓝染原版逻辑继续保留
   - J / S+J / W+J
   - U / S+U / W+U
   - I / W+I / S+I
   - 空中 J / U / I
   - HitVO / 攻击面 / 被打面 / HP / Qi / Energy / Combo / KO / TimeOver
   - Bisha cut-in：Aizen_1 + XG_bs，Aizen_2 + XG_cbs
   - CommonEffectLayer / 原版命中、防御、破防音效逻辑继续保留

二、原版依据摘要

1. fight.swf / FightScoreUI.as 中确实存在 score_mc / txtmc_score；本补丁只是不实例化显示层。
2. FightTimeUI.as 在 gameTimeMax == -1 时不刷新 MCNumber，只显示无限时间分支。
3. FightUI.as 的 showStart 设置 startKOmc.y = -50；KO / TimeOver 设置 y = 0。
4. Aizen mc_023.xml 中普通必杀 addAttacker("bsmc", {x:{followTarget:true,offset:0}, y:{followTarget:true,offset:-25}, applyG:false})。
5. Aizen mc_023.xml 中招3 addAttacker("zh3mc", {applyG:false})。

三、没有伪装成完成的部分

以下内容仍不能声称像素级 100% 完成：
1. Flash motion tween / color transform / mask / shape path 的逐帧递归渲染。
2. qbar_mc / qbar_fzqi_mc / hpbar_mc / energybar_barmc / hits_mc 的全部矢量时间轴像素级渲染。
3. O 键支援/换人完整系统。
4. 完整 P2 玩家输入/AI 与全角色系统。
5. 如果继续校正技能特效 Y 轴或 anchor，必须重新读取原版 XFL 的 Matrix、registration point、FFDec export bounds 或直接导出完整 MovieClip PNG 序列；不要手调坐标。

四、覆盖方法

1. 关闭 Godot。
2. 解压本补丁到：
   D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot
3. 选择覆盖同名文件。
4. 重新打开 Godot 4.6。
5. 进入 Aizen VS Aizen 测试。

五、测试重点

1. 开局只出现 Round 1，不再紧接 Round 2。
2. Fight 文字最终消失，不残留。
3. 顶部时间区域不显示 00，只保留原版无限符号。
4. 顶部不显示 SCORE，也不显示 0000000。
5. O 键无反应。
6. H / T / P 调试键正常游玩中不生效。
7. 血条、Qi、Energy、HitsUI、startKOmc、Bisha cut-in 继续正常。
