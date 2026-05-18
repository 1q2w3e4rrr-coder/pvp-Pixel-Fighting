BVN Godot Aizen v18 strict HUD/HITS/qbar fix
=============================================

Base:
- Apply after bvn_aizen_v18_strict_camera_hits_hud_qibar_final.zip.
- v19/v20/v21/v22 are still discarded.

Changed files:
- scripts/ui/OriginalHitsDisplay.gd
- scripts/ui/FightHud.gd
- scripts/character/ManifestFighter.gd

Fixes:
1. HitsUI
   - Keeps original HitsUI.as logic basis: MCNumber(hits_num_mc, 0, 1, 35), xoffset = -_txtmc.width + 45, hits1 x compensation.
   - Fixes multi-digit width calculation: one digit uses the original 47px bitmap width, later digits advance by 35px.
   - Stops playing the FFDec exported compressed update/fadout frames in Godot, because those frames produce the yellow 1px shadow line after the HITS text is split from ct.
   - Uses a stable original hits_mc frame while visible and clears visual children immediately when combo resets.

2. Bottom QiBar
   - Restores P2 qbar coordinates to the original mc_044/mc_026 derived positions.
   - Restores qbar_movie P2 position to the v18/original-derived value.
   - Reverts forced initial qi/fzqi=100. The forced fzqi was the reason the large red/blue fzqi MovieClip appeared over the bottom HUD.

3. Top HP number
   - Keeps hp/hpMax=2000 for the 3.8.4.3 HUD test.
   - Repositions HP MCNumber values closer to the original top-bar placement.
   - Raises HP MCNumber z_index so the 2000 text is not hidden by the center time/infinity frame.

No new image assets are generated.
