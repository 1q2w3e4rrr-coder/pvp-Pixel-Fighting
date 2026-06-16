BVN Aizen Step19-21 Core Battle Integration

Modified:
- scripts/battle/BattlePlaceholder.gd
- scripts/character/ManifestFighter.gd
- scripts/character/CommonEffectLayer.gd

Included dependencies:
- scripts/character/EffectPlayer.gd
- scripts/character/ShadowEffectLayer.gd
- scripts/character/BishaEffectPlayer.gd
- assets/characters/aizen/aizen_effect_manifest.json
- assets/effects/common/common_effect_manifest.json
- dash / dash_air assets
- original sfx assets already included from Step18

Step19:
- Defense / break-defense logic centralized and audited.
- HitType.CATCH and isReal remain unblockable.
- canHurtBreak status is exposed more closely to the original state rules.

Step20:
- Aizen attack-window audit report included under reports/.
- Runtime audit print logs covered windows once at scene start.

Step21:
- KO cleanup for slowDown, shadow, and moveTarget.
- KO hit_end safe playback hook.
- Timeover winner actions.
- p2 last-hit record for KO/score consistency.

Apply:
1. Close Godot.
2. Extract this zip to:
   D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot
3. Reopen Godot.

Not changed:
- No generated images.
- No HUD / map / QiBar / HITS / texture-quality changes.
