BVN Godot strict SWF logic final v17 - player_pos anchor fix

Base:
- Apply after v16_boundary_hits_playerpos_patch.

Changed:
- scripts/ui/FightHud.gd

Original SWF / AS logic used:
- FightUI.renderPlayerPosUI(zoom) shows player_pos_p1 / player_pos_p2 only when zoom <= 1.8.
- FightUI.getPlayerPos uses GameStage.getGameSpriteGlobalPosition(fighter, 0, -50).
- fight.xfl mc_047 / mc_046 bitmaps use matrix offsets around (-18, -51) / (-18, -50).

Godot correction:
- ManifestFighter.position is the normalized Sprite2D center, not the original BaseGameSprite foot/ground coordinate.
- Before applying original (0, -50), FightHud now converts the Godot center back to the original foot coordinate using the same value as BattlePlaceholder.gd:
  ORIGINAL_FIGHTER_FOOT_OFFSET_Y = 111 * 1.25 = 138.75.
- This makes P1/P2 indicators sit near the character head instead of being clamped to the top of the screen.

Not changed:
- Boundary logic from v16.
- HITS clear logic from v16.
- Xianshi front optical transparency from v15.
- QiBar, Round 1 audio, infinite time, SCORE hiding, Aizen skills.
