BVN Godot v18 - HP number original-style fix

Base: v18 + time_frame_join_slash_fix.

Changed:
- scripts/ui/FightHud.gd

Fix:
1. Previous HP number used mcnumber/score digits, which are yellow/orange and belong to score_mc/txtmc_score, not the original-looking HP number.
2. This patch switches HP number to fight.swf time_txtmc/mc_016 digit PNGs, which are white/cyan and closer to the original 3.8.4.3 HP number style.
3. P1/P2 HP number positions are adjusted to sit beside the center time_mc / infinity frame like the original screenshot.
4. No generated image assets are added.
