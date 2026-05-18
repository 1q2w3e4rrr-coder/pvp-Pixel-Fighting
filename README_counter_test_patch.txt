第 11 步：按原版 setHurtAction 逻辑验证蓝染 S+J 砍技1反击。

新增：
1. P 键触发 P2 的测试 J 攻击：atk1 / k1atm / HitVO k1。
2. P2 攻击命中 P1 的 bdmn 时，调用 P1.apply_original_hit。
3. 如果 P1 正在 S+J 的 attack_skill1 状态，并且原版 setHurtAction("砍技1_HA") 已触发，P1 不扣血，转入 attack_skill1_extra。
4. attack_skill1_extra 第 10-12 帧继续使用 kj1atm / HitVO kj1 命中 P2。
5. H 键打开调试框：红色=P1攻击面，绿色=P2被打面，蓝色=P1被打面，橙色=P2测试攻击面。

测试：
1. Aizen VS Aizen。
2. 按 H 打开框。
3. 按 S+J，让 P1 进入砍技1反击准备。
4. 等一小下，按 P，让 P2 出 atk1。
5. Output 应显示 P2 HIT 后，P1 的 hurtAction 触发并转入 attack_skill1_extra。
6. 如果距离合适，P1 的 kj1atm 会反击命中 P2。

注意：P 键只是调试用，不是最终原版 P2 控制键。
