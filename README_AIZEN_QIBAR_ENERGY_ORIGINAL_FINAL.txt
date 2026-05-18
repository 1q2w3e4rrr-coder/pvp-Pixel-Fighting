BVN Godot Aizen original logic integration - QiBar / EnergyBar final pass

This patch continues from bvn_aizen_fightbar_qibar_timeline_final_v2_patch.

New in this pass:
1. O / assist / swap remains ignored by design.
2. FightHud.gd now keeps more of original QiBar.as logic:
   - main qbar_mc / barmc remains 0-300 qi display.
   - fzqibar / qbar_fzqi_mc is added as HUD-only auxiliary bar.
   - readymc is shown when fzqi >= 100.
   - sp prompt is shown when fzqi is full and the fighter is in a hurt-break-eligible state.
3. ManifestFighter.gd adds fzqi/fzqi_max and is_can_hurt_break() for HUD compatibility.
4. T debug fill now fills qi=300, fzqi=100, energy=100 to test the HUD.
5. EnergyBar.as overLoad branch is reflected in Godot HUD:
   - normal: white original energy fill
   - low energy: flashing alpha
   - energy_overload: warm/orange overloaded state
6. Fixes a qibar position drift problem from the earlier timeline approximation.

Original source logic referenced:
- QiBar.as: _fighter.qi / 100, _fighter.fzqi / 100, readymc visible when fz bar process >= 1, sp visible when isCanHurtBreak().
- EnergyBar.as: bar.rate = energy / energyMax; if energyOverLoad -> overLoad(); else if rate < 0.3 -> flash(); else normal().

Still not pixel-perfect:
- qbar_fzqi_mc/readymc/sp are rendered from original-derived PNG fallbacks, not full recursive Flash shape/tween rendering.
- O support/swap remains intentionally omitted per project decision.
