BVN Aizen / Fight UI mc_043 frame-sequence final patch

本补丁在 bvn_aizen_mc043_original_timeline_final_patch 基础上继续推进：

1. O 键继续完全忽略，不做支援/换人。
2. 保留之前所有蓝染动作、HitVO、攻击面/被打面、Qi/Energy、combo、KO、TimeOver、原版 fight UI、命中特效、防御特效和必杀 cut-in。
3. FightStartKOAnimator.gd 不再只用单张 announcer 贴图近似，而是使用 assets/ui/fight/startko_sequences/ 下的逐帧 PNG 序列。
4. 序列按原版 embed/fight/LIBRARY/元件/mc_043.xml 的帧段组织：
   - start: frame 9..87
   - fight_in: frame 54
   - fight: frame 57
   - complete: frame 87
   - ko: frame 144..189
   - winner: frame 199..209
   - timeover: frame 219..262
   - drawgame: frame 266..308
5. 声音触发仍按原版声音层：
   - frame 11: start_round.ogg
   - frame 57: fight.ogg
   - frame 221: timeover.ogg
   - frame 267: drawgame.ogg

说明：
这版是 Godot 侧更稳定的“逐帧序列版”。当前序列已经使用原版 XFL 提取的 announcer bitmap 资源，并按 mc_043 的原始帧段输出。若后续要进一步像素级靠近，需要把 mc_043 的每个 letter layer 的 Matrix / Color / Tween 参数做完整递归渲染；本补丁已经把播放层改为序列播放，后续只需要替换 startko_sequences 里的 PNG 即可。
