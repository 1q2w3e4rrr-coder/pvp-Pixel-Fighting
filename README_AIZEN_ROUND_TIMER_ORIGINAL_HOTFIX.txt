BVN Aizen Round/Timer original-logic hotfix

This patch only changes code, no generated/replacement art.

1. FightStartKOAnimator.gd
- Uses FFDec-exported original startKOmc frames.
- Skips the Round 2 transition frames that appear because FFDec export does not execute startKOmc's go:fight label.
- Keeps this Godot demo to Round 1 only.
- Clears the startKOmc texture after COMPLETE so Fight text does not remain on screen.

2. BattlePlaceholder.gd
- Sets DEMO_GAME_TIME_MAX = -1, disabling real-time countdown for this one-round demo.
- Existing FightHud will use the infinite-time branch instead of 99/98/97 countdown.

No O-key support is added. O remains ignored.
No hit/effect offsets are guessed in this patch; skill/effect Y-axis correction must come from original Aizen XFL matrices / attacker logic.
