BVN Aizen / Fight UI infinite-time cleanup patch
================================================

This patch follows the original FightTimeUI.as branch:
- If gameTimeMax == -1, FightTimeUI shows _ui.wuxian and does not render MCNumber.
- The Godot HUD now initializes in infinite-time mode and hides time MCNumber when is_infinite=true.
- BattlePlaceholder keeps DEMO_GAME_TIME_MAX = -1.
- No generated/fallback UI images are added in this patch.

Not changed in this patch:
- Skill/effect Y offsets are not hand-tuned here. The next correct step is to re-read the Aizen SWF/XFL attacker MovieClip registration points and FFDec export bounds, then replace the remaining approximate attacker placements with original-derived anchors. This avoids guessing.
