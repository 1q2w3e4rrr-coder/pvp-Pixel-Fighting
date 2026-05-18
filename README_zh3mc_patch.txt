第 5 步补丁：补蓝染 W+U「招3」的 zh3mc attacker。

覆盖到 Godot 项目根目录：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

包含：
- scripts/battle/BattlePlaceholder.gd
- scripts/character/EffectPlayer.gd
- scripts/character/BishaEffectPlayer.gd
- assets/characters/aizen/aizen_effect_manifest.json
- assets/characters/aizen/effects_game/zh3mc/*.png

测试：战斗中按 W+U，Output 应出现：原版 addAttacker 触发：zh3mc applyG=false。
