BVN Godot v18 - qbar_facemc original layer fix

基线：接在 v18 后续已修好的 FightHud.gd 上。
本补丁不从 qbar_mc 整帧裁六边形，也不生成图片。

原版逻辑：
qbar_mc(mc_026) 内部 facemc 是独立子元件，不属于 barmc。
facemc 由渐变底层 + 黑色六边形前框组合。
主气槽 barmc 仍负责 bar1/bar2/bar3/bar4 与 txtmc。

本补丁：
1. 删除/绕开从 qbar_mc/0013.png Atlas 截 facemc 的错误路线。
2. 新增原版素材引用：
   assets/ui/fight/qibar_face_gradient.png  <- fight_ffdec_full_export/images/85.png
   assets/ui/fight/qibar_face_front.png     <- fight_ffdec_full_export/sprites/DefineSprite_96_qbar_facemc/1.png
3. FightHud.gd 中按 facemc Matrix 放置：
   gradient back 64x45
   front 56x39，位于 gradient 内侧偏移 (4,3)
4. 不改 HP、顶部 time_mc、HITS、角色逻辑。
