bvn_aizen_ground_skill_patch

第 12 步：按原 SWF/XFL 逻辑接入蓝染 U / S+U。

已接入：
1. U = 招1 / skill1：zh1atm -> HitVO zh1。
2. S+U = 招2 / skill2：先 zh2_chkm 检测，命中后进入 skill2_check。
3. skill2_check：zh2atm -> HitVO zh2。
4. 保留 W+U = 招3 的 zh3mc/zh3atm 逻辑。

原版依据：
- mc_023：招1 start=506，zh1atm 在 511/513/515/517。
- mc_023：招2 start=322，setSteelBody(true) 在 323，setHitTarget(zh2_chkm, 招2_CHK) 在 326。
- mc_023：招2_CHK start=362，zh2atm 在 362-367。
- DOMDocument：zh1 power=100，hitType=9；zh2 power=110，hitType=5，isBreakDef=true。

测试：
1. Aizen VS Aizen，按 H 打开调试框。
2. 按 U，看 skill1 / zh1atm 红框，命中后 P2 扣 100 并击飞。
3. 靠近 P2 按 S+U，看 CHECK zh2_chkm，检测命中后自动进入 skill2_check。
4. skill2_check 出现 zh2atm，命中后 P2 扣 110 并击飞。

注意：setSteelBody(true) 暂时只打印，完整霸体/防御系统后续继续接。
