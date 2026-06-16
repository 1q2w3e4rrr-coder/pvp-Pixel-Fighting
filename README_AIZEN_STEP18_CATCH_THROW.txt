BVN Aizen Step18 - catch / throw entry patch

Modified:
- scripts/battle/BattlePlaceholder.gd
- scripts/character/ManifestFighter.gd
- scripts/character/CommonEffectLayer.gd
- assets/effects/common/common_effect_manifest.json

Original source basis:
- FighterMcCtrler.setCatch1(action="摔1") / setCatch2(action="摔2") save catch actions after checking labels.
- FighterMcCtrler.renderFloorAction only does catch when moving toward the target:
  moveRIGHT while self is left of target and direct=1, or moveLEFT while self is right of target and direct=-1.
- FighterMcCtrler.allowCatch rejects target HURT_ING, then checks body edge gap disX < 2 and vertical gap disY < 1.
- FighterMcCtrler.doCatch(action) calls doAction(action) and sets actionState=SKILL_ING.
- Aizen mc_023.xml throw hitboxes:
  throw1 sh1atm frame 709-711, sh12atm frame 715-717.
  throw2 sh1atm frame 730-732, sh22atm frame 746-748.
- Aizen DOMDocument.xml defineAction:
  sh1:  power=0,   hitType=11, hitx=0,  hity=0,  hurtTime=1000, hurtType=0, isBreakDef=true
  sh12: power=50,  hitType=6,  hitx=-7, hity=1,  hurtTime=1000, hurtType=0
  sh2:  power=0,   hitType=11, hitx=0,  hity=0,  hurtTime=1000, hurtType=0, isBreakDef=true
  sh22: power=150, hitType=5,  hitx=10, hity=-5, hurtTime=0,    hurtType=1
- EffectModel.initHitEffect maps HitType.CATCH to xg_catch_hit with freeze=400 and sound=snd_hit_cache.
  In effect.xfl, mc_045 has linkageClassName=xg_catch_hit and linkageIdentifier=XG_qdj, so this patch aliases catch_hit to the original XG_qdj/hit_2 frames rather than creating placeholder art.

Godot input mapping:
- A/D toward target + J = catch1 / throw1
- A/D toward target + U = catch2 / throw2

Fixes:
- Adds sh1/sh12/sh2/sh22 HitVO data.
- Adds throw1/throw2 attack rectangles from XFL Matrix.
- Adds allowCatch-style body edge check.
- Adds target caught state in ManifestFighter.
- HitType.CATCH bypasses ordinary defense and returns result="catch".
- catch_hit uses snd_hit_cache and 400 ms hit-stop.
- moveTarget from Step17 continues to control throw2 target binding.

Not changed:
- No generated images.
- No HUD / map / QiBar / HITS / texture-quality changes.
- No screenshot hand-tuning.
