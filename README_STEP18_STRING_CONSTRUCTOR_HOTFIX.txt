BVN Aizen Step18 HOTFIX - String constructor crash

Fix:
- Replaces GDScript String(Variant) conversions with str(Variant) in:
  scripts/battle/BattlePlaceholder.gd
  scripts/character/ManifestFighter.gd

Reason:
- Godot 4.x can throw:
  Invalid call 'String' constructor: setSkill2
  when String(...) receives a StringName/Variant from manifest semantic data.
- str(...) is the safe global conversion and does not change the battle logic.

Not changed:
- No battle feature changes.
- No generated images.
- No HUD / map / QiBar / HITS / texture-quality changes.

Apply:
1. Close Godot.
2. Extract this zip to the project root:
   D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot
3. Reopen Godot.
