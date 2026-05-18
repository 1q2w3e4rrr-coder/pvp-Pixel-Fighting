BVN Godot Aizen closer-to-original integrated final patch

This patch is based on the previous original_effect_ui_system_final patch, then continues toward the original SWF/AS logic:

1. O key is still ignored.
2. Effect SFX are kept as original sound IDs but converted to .ogg to avoid Godot 4.6 FileAccessMemory errors.
3. Fight HUD uses original fight XFL bitmap resources and adds an original-shaped HP front bar derived from the hpbar_barmc bar shape.
4. FightUI.showStart timing is approximated from original startKOmc:
   - startKOmc frame 57 dispatches fight event, so input is locked for 57 / 30 seconds.
   - startKOmc COMPLETE is at frame 87, so the center start message remains until 87 / 30 seconds.
5. KO flow is closer to original:
   - show K.O.
   - delay winner display
   - show P1 WIN / P2 WIN and PERFECT when applicable.
6. Existing Aizen actions, HitVO, hitbox/hurtbox debug, bisha, common hit/defense effects, qi/energy/score/combo remain integrated.

Not claimed complete:
- Pixel-perfect startKOmc/winner/timeover vector animation from mc_043 is not fully rasterized yet.
- Full P2 input/AI, full map/camera, complete GameCtrler round flow, and multi-character support are still outside this patch.

If you want pixel-perfect start / ko / winner UI next, extract or render OpenBleachVsNaruto/swf_source/embed/fight/LIBRARY/元件/mc_043.xml (startKOmc) to PNG frames, or allow a script to rasterize that MovieClip from XFL.
