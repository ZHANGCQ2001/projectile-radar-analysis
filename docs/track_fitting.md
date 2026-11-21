# 界面2：含横向距离的轨迹拟合与速度解模糊

## 物理量与适用范围

- `perpendicularDistance`（d，m）：雷达到目标直线运动轨迹的最短距离。存在高度差时应使用三维最短距离，不是仅用地面水平距离。
- `Range_m`（R）：各短时窗口测得的雷达至目标斜距，不是相对首帧的距离变化量。
- `radialDirection`：+1 表示该段距离增加，-1 表示距离减小。软件沿用“距离增加为正径向速度”的符号约定；实际系统的 I/Q 与 Doppler 符号必须经过验证。
- `measuredSpeed`、拟合速度范围、解模糊速度范围：均为沿轨迹速率（正值），不再将其误当作径向速度。界面2中的速率上下限同时约束轨迹关联和解模糊，不再使用隐藏的旧参考速度范围。
- 一个处理片段必须处于最近点同一侧；跨越最近点时应分段处理。本模型不用于转弯轨迹或随时间改变的垂距。

## 轨迹关联与拟合

先由每个候选斜距恢复带符号的沿轨迹坐标：

```text
x_i = radialDirection * sqrt(R_i^2 - d^2)
x(t) = x0 + V*t
R_pred(t) = sqrt(d^2 + x(t)^2)
v_r,pred(t) = V*x(t)/R_pred(t)
```

两个不同窗口的候选点产生 `V=(x2-x1)/(t2-t1)` 和 `x0=x1-V*t1`。只有满足沿轨迹速率范围和最小时间跨度的假设参与关联。初始位置 x0 自由估计，不假设初始斜距为零。

每个窗口最多选择一个候选点。关联比较的是斜距残差、逐点预期模糊径向速度的循环残差、逐点投影后的参考速率残差与背景增强强度。轨迹评分保留覆盖率、连续性、平均强度和归一化残差的平衡方式。

迭代拟合在 d>0 时最小化原始斜距域的残差：

```text
min_(V,x0) sum_i [R_i - sqrt(d^2+(x0+V*t_i)^2)]^2
```

`fitRangeTrack` 先在线性沿轨迹坐标初始化，再用基础 MATLAB 的 `fminsearch` 优化斜距残差。时间中心化/归一化避免尺度问题。d=0 且方向为远离时退化为原来的距离-时间直线拟合。

`fitInfo.speed` 是沿轨迹速率；`fitInfo.intercept` 是 t=0 的带符号沿轨迹位置。`fitInfo.initialSlantRange=hypot(d,intercept)` 给出该时间基准的斜距截距。不得再直接用 `speed*t+intercept` 绘制斜距，统一调用 `predictRangeTrack`。

## 逐点几何解模糊

```text
c_i = radialDirection * sqrt(R_i^2-d^2)/R_i
v_r,i(k) = AliasedVelocity_i + 2*k*Vmax
V_i(k) = v_r,i(k)/c_i
```

先枚举径向 Doppler 模糊数，再在沿轨迹速率域对候选施加范围、参考速率、距离模型拟合速率和相邻点连续性约束。动态规划选择整段最小代价路径。不是先把模糊速度除以角度，再加一个固定的沿轨迹模糊周期。

`R<=d`、非有限斜距、或 `|c_i|<minRadialProjection` 的点不参与折算。默认最小投影为 0.10，可在界面2修改。不能将无效斜距夹到 d 附近后强行除以接近零的数。最近点附近径向速度不能稳定确定沿轨迹速率，这不是用更多小数位可以修复的问题。

参考速率仍是解模糊先验，不是独立测速真值；摘要中的 RMSE/MAE 是相对所输入参考值的差异。错误参考值、方向或横向距离可能使模糊数选错。

## 输出字段

| 字段 | 含义 |
|---|---|
| `AliasedVelocity_mps` | 有模糊径向速度 |
| `UnwrappedVelocity_mps` | 兼容旧字段：仍是解模糊径向速度 |
| `UnwrappedRadialVelocity_mps` | 明确命名的解模糊径向速度，与上一字段相同 |
| `TargetSpeed_mps` | 逐点几何折算后的沿轨迹速率 |
| `RadialProjection` | 带符号的逐点投影系数 |
| `AspectAngle_deg` | 由投影绝对值得到的锐角（不表示接近/远离方向） |
| `GeometryValid` | 该点是否满足几何条件 |
| `ExpectedAliasedVelocity_mps` | 根据几何距离模型逐点预测的模糊径向速度 |
| `FittedRadialVelocity_mps` | 几何距离模型预测的径向速度 |

CSV/MAT 保留这些字段。统计指标使用 `TargetSpeed_mps`。距离-速度耦合修正仍使用 `UnwrappedRadialVelocity_mps`，不能替换为沿轨迹速率。

当前逐点折算使用 `Range_m`；原有可选距离-速度耦合修正仍作为后处理输出，并未实现耦合修正与几何估计的迭代联立求解。
