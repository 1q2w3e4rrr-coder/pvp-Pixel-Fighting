BVN Aizen strict SWF logic final v7 warning cleanup

本补丁基于 v5/v6，不改变任何原版 SWF/XFL/AS 逻辑和视觉资源，只清理 Godot 的静态检查警告。

修改文件：
- scripts/ui/FightHud.gd

修正内容：
1. update_state() 中 p1_score / p2_score 当前按用户要求隐藏 SCORE，不再使用，所以改名为 _p1_score / _p2_score。
2. _apply_fzqi_positions() 与 _apply_fzqi_process() 中局部变量 ready 改为 ready_tex，避免遮蔽 Node.ready 信号。
3. _update_player_pos_ui() 中 p1_node / p2_node 当前按用户要求隐藏头顶 P1/P2 指示，不再使用，所以改名为 _p1_node / _p2_node。
4. _update_combo_number() 中 num_mc / is_p1 当前由 OriginalHitsDisplay 统一处理，不再单独使用，所以改名为 _num_mc / _is_p1。
5. _make_label() 的 align 参数类型改为 HorizontalAlignment，避免 int 直接赋值给枚举的警告。

没有新增自制资源，没有修改 QiBar、HitsUI、Round/Fight、技能、HitVO、音效等逻辑。
