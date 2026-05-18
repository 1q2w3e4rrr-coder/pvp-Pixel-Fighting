BVN Godot v18 hpbar stripe hotfix

原因：上一版按 mc_033.xml 把 picture_008 作为 hpbar_top_glass 覆盖在绿色 bar 上。
但当前 FFDec 拆出的 picture_008 是整条黑色网格/玻璃纹理，Godot 直接叠到绿色条上会形成明显条纹。
原版 3.8.4.3 实际画面中 HP 前条呈纯绿色，因此本热修保留节点但默认隐藏 hpbar_top_glass，不再盖住绿色 front bar。

修改文件：
scripts/ui/FightHud.gd

不新增图片，不生成替代素材。
