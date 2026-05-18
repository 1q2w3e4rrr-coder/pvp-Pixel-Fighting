BVN Godot v18 HP/Qi SWF logic final patch
=========================================

Base:
- Apply after current v18-based project state.
- v19/v20/v21/v22 remain discarded.

Changed file:
- scripts/ui/FightHud.gd

Original references:
1. FighterHpBar.as:
   - _bar.scaleX = hp / hpMax
   - redbar.scaleX follows with delay
2. fight.xfl / mc_033.xml:
   - redbar is under bar
   - bar is the green front HP strip
   - glass highlight is above both
   - bar1 is normal orientation; bar2 is mirrored by the parent hpbar_mc
3. QiBar.as / InsBar.setProcess:
   - qiRate = fighter.qi / 100, clamped to 3
   - bar1 visible when v > 0
   - bar2 visible when v > 1
   - bar3 visible when v > 2
   - bar4 visible when v >= 3
   - txtmc.gotoAndStop(int(v) + 1)
4. fight.xfl / mc_022.xml:
   - qbar_barmc contains frame, bar group, ghost, and txtmc
5. fight.xfl / mc_044.xml:
   - fzqi1 normal orientation
   - fzqi2 has matrix a=-1, so P2 qbar is mirrored

Fixes:
1. HP bar:
   - Uses an AtlasTexture region from the existing original hpbar_frame.png green inner strip as the front HP bar.
   - Does not use the uploaded hpbar_frontbar.png as the visible front bar because it is not the green HP strip in the current project export.
   - Does not generate new image files.
   - Green bar stays above redbar; redbar delays; empty region masks the baked full-green frame underneath.

2. Qi bar:
   - Stops using FFDec qbar_mc full-frame PNGs as the hold-state base, because the original runtime logic changes qbar child MovieClips dynamically.
   - Uses qibar_frame + bar1/bar2/bar3/bar4 + dynamic txtmc number logic.
   - Masks the baked static 0 in qibar_frame and draws only one dynamic layer number.
   - P1 qi grows left-to-right.
   - P2 qi grows right-to-left by using the mirrored qbar geometry.

No new images, placeholders, or guessed assets are added.
