BVN Aizen strict SWF logic v12 hotfix

本补丁基于 v11 继续修两个问题：
1. FightStartKOAnimator.gd 的 Array[int] 赋值报错。
2. OriginalHitsDisplay.gd 连击中断后残留细线。

修改文件：
- scripts/ui/FightStartKOAnimator.gd
- scripts/ui/OriginalHitsDisplay.gd
- scripts/battle/BattlePlaceholder.gd
- tools/extract_gense_layers.py

说明：
- FightStartKOAnimator 不再把普通 Array 直接赋给 Array[int]。
- round_num 改为 _round_num，保留函数签名但清除警告。
- BattlePlaceholder 中 unused delta / call shadowing 警告清理。
- HitsUI 当前 Godot 版是 hits_mc 与 ct 数字层拆开绘制；为彻底避免残影，combo 中断时直接隐藏整组，不再播放会产生 1px 残线的 fadout 末段。

GenSe 分层提取：
- tools/extract_gense_layers.py 只复制/解码原始 GenSe XFL 中的 bitmap，不生成替代图。
- 如果某个 bitmapDataHRef 无法被安全解码，脚本会写报告并要求用 FFDec/JPEXS 或 Adobe Animate 导出。
