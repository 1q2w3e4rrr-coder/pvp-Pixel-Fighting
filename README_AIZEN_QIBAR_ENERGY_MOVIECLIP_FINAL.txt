BVN Aizen Godot - qbar_fzqi_mc / energybar_barmc original logic final

本补丁接在 bvn_aizen_qibar_energy_original_final_patch 之后。

继续按原版 SWF/XFL/AS 逻辑靠近：
1. O 键继续完全忽略，不做支援/换人。
2. 保留前面所有蓝染动作、HitVO、攻击面、被打面、HP、Qi、Energy、combo、KO、TimeOver、原版 fight UI、startKOmc、MCNumber、HitsUI、FightBar/QiBar 淡入淡出。
3. qbar_fzqi_mc 不再只是静态跟随底部 QiBar：
   - 按 fight.xfl / mc_026.xml 中 fzqibar 的 Matrix 关键帧执行 fadin / fadout 位移和缩放。
   - 按 mc_026.xml 中 readymc 的 Matrix 关键帧移动 ready 提示。
   - sp 提示跟随 fzqibar 缩放/位移。
4. energybar_barmc 不再用单纯 Color 调色模拟：
   - 按 EnergyBar.as / InsBar.flash() 的逻辑，每 3 个原版 render 帧在 frame1/frame2 之间切换。
   - energyOverLoad 时固定为 frame2/overload 状态。
5. 新增 energybar_fill_frame1.png / energybar_fill_frame2.png / energybar_fill_overload.png。

仍未完成的像素级内容：
- energybar_barmc 的 shape_002 / shape_003 如果要做到完全像原版，需要继续解析 XFL vector shape 或用 JPEXS/Animate 导出真实帧。
- qbar_fzqi_mc 的头像 facemc 由于项目已决定不做 O 支援/换人，目前没有接真实支援头像。
