BVN Godot 蓝染系统整合最终补丁
================================

覆盖路径：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

本补丁继续遵守：原版 SWF / XFL / ActionScript 源码优先。

本次新增 / 整合：
1. O 键继续忽略，不做支援/换人。
2. 保留蓝染已接入的 J / S+J / W+J / U / S+U / W+U / I / W+I / S+I / 空中 J/U/I。
3. 使用原版 embed/fight 导出的 HUD 图片：血条、红色延迟扣血条、头像框、Qi 蓝条、Energy 条。
4. 新增 CommonEffectLayer.gd，对应原版 EffectCtrler.doHitEffect / doDefenseEffect / break_def。
5. 从原版 effect.xfl 的 DOMSoundItem / soundDataHRef 导出 snd_bs、snd_cbs、snd_kan1、snd_def、snd_mfdjx 等音效到 assets/sfx/effect/。
6. 从原版 effect.xfl 的部分 bitmap 元件导出 hit_*/defense_* 通用命中/防御特效到 assets/effects/common/。
7. 命中、重击、防御、破防现在会触发对应音效、特效、闪白、短暂停顿、屏幕震动。
8. BishaEffectPlayer 播放 XG_bs/XG_cbs 时同步播放 snd_bs/snd_cbs。
9. AudioManager.gd 改为 SFX 池，避免多个命中音互相打断。

重要说明：
- hit_1 / hit_2 / hit_4 / defense_1 / defense_2 / defense_4 等已从原版 effect.xfl 位图序列导出。
- 部分 shape-only 的重击/重防御特效目前使用保留原版 effect id 的 fallback 形状帧；后续若需要完全像素级复刻，应继续解析 XFL shape path 或用 JPEXS/Animate 直接导出对应 linkage。
- 这仍是课程 Demo 阶段最终整合版，不等于完整 BVN 引擎。尚未完成：完整选人界面、完整 P2 输入/AI、地图摄像机、完整 KO/round 结算、全角色系统。
