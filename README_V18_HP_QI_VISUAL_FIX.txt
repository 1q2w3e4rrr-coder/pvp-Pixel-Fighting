BVN Godot v18 - HP/Qi visual process fix
=========================================

Base:
- Continue from v18 valid baseline and the latest hits/hp/qi continuous patch.
- v19-v22 remain discarded.
- No new image assets are generated or added.

Modified:
- scripts/ui/FightHud.gd

Original logic referenced:
1. FighterHpBar.as: front hp bar follows hp/hpMax immediately; redbar follows with delayed scaleX.
2. fight.xfl mc_033.xml: hpbar_barmc contains picture_076 plus inner child bar/redbar.
3. QiBar.as / InsBar.setProcess: qbar process is qi / 100 and child bar1/bar2/bar3/bar4 are shown/scaled continuously, not only at integer 1/2/3.
4. fight.xfl mc_022.xml: qbar_barmc contains picture_063 as base frame, then child bar group, then txtmc number.

Fix:
1. HP bar:
   The previously extracted hpbar_frame.png is a static full-hp export of hpbar_barmc, so it covered any resized child bar.
   This patch keeps that original bitmap but adds a code-only empty mask over the unfilled part of the bar so hp changes are visible immediately.

2. Qi bar:
   The qibar_frame.png static base was being drawn above the scaled bar children, so it hid continuous fill changes.
   This patch restores the original display order: frame/base first, scaled bar children above it, number above the bars.

No placeholder image or generated replacement art is included.
