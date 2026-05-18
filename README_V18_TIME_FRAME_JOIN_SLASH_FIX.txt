BVN Godot v18 - time_mc center join slash fix

Base: current v18 strict SWF logic chain.

Changed:
- scripts/ui/FightHud.gd
- assets/ui/fight/hpbar_time_join_slash.png

Original source:
- fight.xfl / mc_040.xml / hpbar_mc
- layer shape_007 on both sides of time_mc
- shape_007 uses picture_033
- final matrices at fadin_fin:
  left : shape_007 tx=-33.75 ty=4.2, picture_033 tx=-12 ty=-15.5
  right: shape_007 a=-1 tx=33.25 ty=4.2, picture_033 tx=-12 ty=-15.5
- ui_fight places hpbar_mc at tx=400 ty=45.6

Result:
- Adds the original mirrored slash/triangle pieces beside the infinite time frame.
- Keeps time_mc above those pieces, matching the original visual layer relation.
- No generated or hand-drawn image is used; hpbar_time_join_slash.png is copied from the FFDec export of the original fight.swf image for picture_033.
