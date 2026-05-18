BVN Aizen closer-to-original final patch: startKOmc animator integration.

This patch keeps O ignored and preserves all previous Aizen systems. It adds scripts/ui/FightStartKOAnimator.gd and assets/ui/fight/announcer/*.png. The new animator follows original embed/fight mc_043 timing:
- start label frame 9
- fight_in event frame 54
- fight event frame 57
- complete frame 87
- ko label frame 144, complete frame 189
- winner label frame 199, complete frame 209
- timeover label frame 219, complete frame 262
- drawgame label frame 266, complete frame 308

The visual PNGs are fallback raster images arranged by the original timeline. For pixel-level perfection, export mc_043 shape_008~025 as proper PNG sequences from fight.xfl/fight.swf and replace assets/ui/fight/announcer.
