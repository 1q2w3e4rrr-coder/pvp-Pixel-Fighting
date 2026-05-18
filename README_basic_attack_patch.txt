第 9 步：按原 SWF / XFL 逻辑接入蓝染 J 普攻连段攻击面和 HitVO。

覆盖到 Godot 项目根目录：
D:\学习文件\大三下\软件工程实践\BVN_Godot\bvn-godot

新增：
1. atk1 / k1atm -> HitVO k1
2. atk2 / k2atm -> HitVO k2
3. atk3 / k3atm -> HitVO k3
4. atk4_extra / k4atm -> HitVO k4
5. atk5 / k5atm -> HitVO k5
6. atk5 / k52atm -> HitVO k52

说明：
- 攻击面矩形由 mc_023 中的 k1atm/k2atm/k3atm/k4atm/k5atm/k52atm 的 Matrix 换算。
- HitVO 数据来自 aizen/DOMDocument.xml defineAction。
- 仍然没有实现防御、连击计数、命中特效、受击音效。
