# 界面2：含横向距离的轨迹拟合与速度解模糊

[返回文档索引](README.md) · [参数说明](parameters.md) · [算法流程](algorithm.md)

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

先枚举径向 Doppler 模糊数，再在沿轨迹速率域对候选施加范围约束；用户参考速率只锚定**目标运动结束帧**，更早的帧从结束帧逆向逐点求解，由相邻点连续性和模糊数跳变惩罚连接。不是先把模糊速度除以角度，再加一个固定的沿轨迹模糊周期，也不是把参考速率当成每一帧的先验。

`R<=d`、非有限斜距、或 `|c_i|<minRadialProjection` 的点不参与折算。默认最小投影为 0.10，可在界面2修改。不能将无效斜距夹到 d 附近后强行除以接近零的数。最近点附近径向速度不能稳定确定沿轨迹速率，这不是用更多小数位可以修复的问题。

参考速率只是末帧解模糊先验，不是独立测速真值；摘要中的 RMSE/MAE 是相对所输入参考值的差异，对加速目标整段会明显偏大。错误参考值、方向或横向距离仍可能使模糊数选错。

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


## 时间基准与初始距离

`Time_ms` 是目标所选区间的相对窗口中心时间，源自 `processFrameRange`：

```text
t_i = (physicalFrame_i - targetFrameStart)*framePeriod
      + (chirpStart_i - 1 + (winSize - 1)/2)*chirpPeriod
```

函数生成毫秒，拟合时再乘1e-3转成秒。第一窗口中心不一定为0；`fitInfo.intercept` 对应目标区间第一帧起点 t=0 的沿轨迹位置，而不是“第一窗口实测斜距”。原始斜距为 `Range_m`，几何预测斜距为 `FittedRange_m`，二者不可混淆。

## 动态规划实际使用的约束

有效点按时间**降序**排列（目标运动结束帧在前），对每个点和模糊数 k 在沿轨迹速率候选 `V_i(k)` 上计算：

```text
localCost(1,k) = unwrapEndAnchorWeight * ( unwrapMeasuredWeight*((V_1(k)-measuredSpeed)/measuredSpeedStd)^2
                                         + unwrapEndFitWeight*((V_1(k)-referenceSpeed)/distanceFitSpeedStd)^2 )
localCost(i>1,k) = 0
transition(i,k,j) = unwrapContinuityWeight*((V_i(k)-V_(i-1)(j))/unwrapContinuityStd)^2
                  + unwrapAliasChangePenalty*|k_i - k_j|
```

配置字段 `measuredSpeed` 是用户输入的参考速率（例如 200 m/s），它**只锚定目标运动结束帧**。`referenceSpeed` 是函数参数 `fitInfo.speed`，默认不再进入锚点（`unwrapEndFitWeight=0`），避免整段匀速拟合值把加速目标的末帧拉偏；如需启用可显式设置 `unwrapEndFitWeight`。超出 `unwrapSpeedMin/Max` 的状态不可行。从结束帧出发逆向 DP，取最早帧的最小累计代价后回溯，输出仍写回原表行顺序。

连续性项是相邻有效点的速率差，未除以时间间隔；不能称为加速度滤波器。`unwrapAliasChangePenalty` 对模糊数跳变增加线性代价，默认 0.5，用于抑制 `k` 来回翻转。无可行路径时输出保持NaN并给出警告，不自动扩大模糊数范围或强制取参考值。由于锚点只在末帧，界面桥接把 `unwrapSpeedMax` 放宽到参考速率的 3 倍，以便容纳加速目标前段更高的速度。

## 输出解释补充

- `GeometryValid=true` 仅表示距离/投影条件满足；还要检查 `isfinite(TargetSpeed_mps)`，才能认定该点产生了测速结果。
- `AspectAngle_deg=acosd(abs(RadialProjection))` 丢弃方向符号；方向仍由投影符号/配置说明。
- `fitInfo.speed` 是整段近似恒速几何模型的拟合结果；`TargetSpeed_mps` 是由每点 Doppler 解模糊并折算得到的速率，两者不必逐点相等。
- 当前不是把距离观测和Doppler观测一次性联合优化，也不提供CRLB或测速置信区间。
- 窗口中把目标近似为一点；距离栅格误差、横向距离误差、时间参数错误及目标关联错误均可能影响结果。输出曲线平滑不代表误差已经受控。

## 对应源码与测试

[几何投影](../src/+pradar/rangeGeometry.m) · [距离预测](../src/+pradar/predictRangeTrack.m) · [距离拟合](../src/+pradar/fitRangeTrack.m) · [轨迹搜索](../src/+pradar/selectTrack.m) · [候选关联](../src/+pradar/associateCandidates.m) · [速度解模糊](../src/+pradar/unwrapTrackVelocity.m)

回归包括 `tests/test_rangeGeometry.m`、`tests/test_geometryTrack.m` 和 `tests/test_geometryUnwrap.m`；运行方法见[测试说明](testing.md)。
