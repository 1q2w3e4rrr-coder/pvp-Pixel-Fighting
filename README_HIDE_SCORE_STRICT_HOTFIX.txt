BVN Aizen HUD strict hotfix: hide score UI

目的：
- 按用户当前单回合复刻要求，不显示 fight HUD 中的 SCORE 和 0000000。
- 不删除原版资源，不生成替代图，只是不实例化 FightScoreUI 显示层。

修改文件：
- scripts/ui/FightHud.gd

依据：
- 原版 fight.swf 中存在 score_mc / txtmc_score / FightScoreUI.as。
- 当前项目只保留单回合对战，不需要 arcade score 显示；用户明确要求隐藏 SCORE 与 0000000。
