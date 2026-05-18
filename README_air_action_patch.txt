第 13 步：按原 SWF/XFL 逻辑接入蓝染空中 J / U / I。

内容：
1. 空中 J = 跳砍：tkatm -> HitVO tk。
2. 跳砍第 9 帧 setSkillAIR / setBishaAIR 后允许接空中 U / 空中 I。
3. 空中 U = 跳招：tzatm -> HitVO tz。
4. 空中 I = 空中必杀：Aizen_1 + XG_bs，moveToTarget(50,-70,true)，kbsatm -> HitVO kbs。
5. 接入 isApplyG(false) 的最小重现，避免空中必杀期间立刻受重力下落。

仍未完成：
1. 空中招式的完整特效、残影、shake、shine 视觉还只是日志或最小逻辑。
2. 防御、连击数、命中特效、受击音效仍待继续按原版接入。
