BVN Godot v18 - time frame top-layer hotfix

This patch only changes:
- scripts/ui/FightHud.gd

Original logic followed:
- The center time_mc / infinite-time frame from fight.swf is drawn above the HP bar layer.
- The time frame image itself contains the left/right black-white triangular covers, which visually fills/occludes the slanted HP bar ends near the center.
- Godot previously scaled the exported 83x62 time_frame.png down to 75x54 and left it below HP bar nodes, so the HP bar ends looked like they had gaps.

Fix:
- Use the exported original time_frame.png at its native 83x62 size.
- Center it at x=400 with position (358.5, 14.0).
- Raise its z_index above HP bar/front/redbar layers but keep HP number MC above it.
- No generated image assets are added.
