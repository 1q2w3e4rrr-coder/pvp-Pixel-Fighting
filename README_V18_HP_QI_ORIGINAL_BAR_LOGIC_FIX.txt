BVN Godot v18 - HP/Qi original bar logic fix

Base:
- Continue from current v18 patch chain.
- Do not use v19-v22.
- No generated/replacement art assets are added.

Changed file:
- scripts/ui/FightHud.gd

Original source logic used:
1. FighterHpBar.as:
   - _bar.scaleX = hp / hpMax
   - redbar.scaleX follows with delay using diffRed/addRateRed
2. fight.xfl mc_033.xml:
   - hpbar_barmc contains name="bar" and name="redbar"
   - bar layer is above redbar in visual result
   - glass/top bitmap is above the bars
3. QiBar.as / InsBar.setProcess:
   - process = fighter.qi / 100, clamped to 3
   - bar1 visible v > 0, bar2 visible v > 1, bar3 visible v > 2, bar4 visible v >= 3
   - bar scaleX changes continuously; not only 0/1/2/3 snapshots
4. fight.xfl mc_022.xml:
   - qbar_barmc contains the bar group, txtmc, and frame/background resources.

Fixes:
1. HP visual bar now changes with HP number.
   - The green front bar is drawn above redbar, following hp / hpMax.
   - The red delayed bar follows after delay.
   - No new PNG is created. The green front bar is built at runtime as an AtlasTexture region from the already exported hpbar_barmc texture.
2. Qi bar keeps continuous InsBar.setProcess behavior.
   - The existing qibar_bar1/bar2/bar3/bar4 resources are scaled continuously according to qi / 100.
   - The qbar frame/number and fz/ready resources remain from the original exported fight UI.

Test:
1. Hit P2 and verify HP number and green HP bar both decrease.
2. Verify red delay bar follows behind the green bar.
3. Gain Qi and verify the lower Qi bar fills continuously rather than only jumping at 1/2/3.
