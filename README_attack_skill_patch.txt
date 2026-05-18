第9步：蓝染 S+J / W+J 按原 SWF/XFL 逻辑接入

覆盖到 bvn-godot 根目录。

修改点：
1. 修复上一版 J 普攻命中判定不会触发的问题：主时间轴攻击面现在也会参与 check_active_hit_target。
2. S+J = 砍技1：按原版 setHurtAction 处理。砍技1本体是反击准备；如果该动作期间被打，会转入 attack_skill1_extra（砍技1_HA），attack_skill1_extra 的 kj1atm 才有攻击面和 HitVO=kj1。
3. W+J = 砍技2：按原版 setHitTarget("kj2_chkm", "砍技2_CHK") 处理。检测框命中 P2 后，进入 attack_skill2_check。
4. attack_skill2_check 的 kj21atm 接 HitVO=kj21。
5. attack_skill2_check 到达 setSkill2("砍技2_1") 后，再次 W+J 可以进入 attack_skill2_1。
6. attack_skill2_1 的 kj2atm 接 HitVO=kj2。

测试：
- J 连段：确认 k1/k2/k3/k4/k5/k52 能打印 HIT 并扣血。
- W+J：靠近 P2 按 W+J，应先出现 CHECK kj2_chkm，命中后进入 attack_skill2_check 并造成 kj21。随后在 CHK 动作中再次按 W+J，进入 attack_skill2_1，造成 kj2 击飞。
- S+J：当前 demo 没有 P2 主动攻击，所以它主要验证原版 hurtAction 逻辑已接入；等接 P2/AI 攻击后，被打时会转入 attack_skill1_extra。
