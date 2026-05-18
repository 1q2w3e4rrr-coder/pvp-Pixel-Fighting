BVN Godot Aizen - qbar_facemc / qbar_mc timeline closer-to-original final

覆盖位置：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本版继续按原版 OpenBleachVsNaruto/swf_source/embed/fight/fight.xfl 处理 HUD：
1. O 键继续忽略，不做支援/换人。
2. 保留上一版所有蓝染动作、HitVO、hitbox/hurtbox、HP/Qi/Energy、KO/TimeOver、startKOmc、MCNumber、HitsUI、FightBar/QiBar、命中特效、防御特效、必杀 cut-in。
3. 新增原版 qbar_facemc 资源：
   - qibar_face_back.png  来自 picture_070 / M 47 1555507084.dat
   - qibar_face_front.png 来自 picture_075 / M 46 1555507084.dat
4. FightHud.gd 加入 qbar_facemc 的底框、角色头像、前框；fzqi 显示时一起出现。
5. qbar_mc 主气条 barmc 的淡入不再是简单侧滑：按 mc_026.xml 的关键帧加入 frame11 overshoot。
6. qbar_fzqi_mc / readymc / sp 的逻辑继续保留。

测试：
1. 进入 Aizen VS Aizen。
2. 按 T 充满 qi/fzqi/energy。
3. 底部辅助气条区域应出现原版小头像框与角色头像。
4. qbar 淡入时应有更明显的原版 overshoot。
5. O 键仍应无反应。

不需要你额外处理文件：
本补丁所需 qbar_facemc 图片已经从你上传的原版 fight.xfl/bin 中解码。

如果后续继续追求像素级还原：
需要专门用 JPEXS 或 Adobe Animate 从 fight.swf / fight.xfl 导出以下完整 MovieClip 的逐帧 PNG：
- qbar_mc / qbar_fzqi_mc / qbar_facemc
- energybar_barmc
- hpbar_barmc
- hits_mc / score_mc / time_mc
原因：Godot 当前已经按原版逻辑和关键帧复刻，但 Flash 的矢量 shape、mask、motion tween、color transform 仍是近似实现。
