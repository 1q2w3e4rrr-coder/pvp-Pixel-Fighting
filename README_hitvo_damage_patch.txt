第 8 步：按原版 SWF/XFL 的 HitVO 继续接伤害、hurtType、hitx/hity、hurtTime。

覆盖到 bvn-godot 根目录。

新增：
1. ManifestFighter.gd 增加 hp/hp_max，默认 1000，对齐原版 BaseGameSprite。
2. 从蓝染 DOMDocument.xml 的 defineAction 抽出 bs1 / bs / zh3 的 HitVO 数据。
3. FighterHitModel 的显示对象映射逻辑：bs1atm -> bs1，bsatm -> bs，zh3atm -> zh3。
4. 命中后调用 apply_original_hit：扣血、普通硬直或击飞、hitx/hity 推动、hurtTime 硬直。
5. 战斗场景顶部增加临时 HP 条，方便验证伤害。

仍未完成：防御、连击计数、命中特效、受击音效、GameLogic.addScoreByHitTarget、真实多角色 target 系统。

补充：bsmc 只在原版攻击面存在的帧显示判定：2-48 帧 bs1atm，49-52 帧 bsatm。
