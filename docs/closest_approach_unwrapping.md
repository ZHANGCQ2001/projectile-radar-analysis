# 最近点速度锚定的距离—径向速度联合解模糊

适用分支：`feature/closest-approach-joint-unwrapping`。基于 `88d02d5` 新建，未修改原功能分支。仅改变精细处理、脚本分析及相应测试/文档；界面1、OS-CFAR选帧、采集控制、BIN格式和板端固件不变。

[返回索引](README.md) · [双界面操作](uppermachine_processing.md) · [参数](parameters.md)

## 1. 参考值的物理含义

`measuredSpeed` 在新模式中只表示目标经过几何最近点时的**沿轨迹合速率** Vc，不是每个位置的速度，不是最近点径向速度，也不默认对应所选第一帧。默认采用 `unwrapMethod="closestApproach"`；原算法保留为 `"legacy"`，用于显式对比，不会在新求解失败时自动回退或伪造结果。

模型要求雷达固定，目标沿直线单向运动，垂距 d 已知且固定。以运动方向为 x 的正方向，最近点 x=0；`radialDirection=+1/-1/0` 分别为远离段、接近段、跨越最近点。跨越模式要求 d>0。

```text
x(t) = x0 + v0*(t-t0) + 0.5*a*(t-t0)^2
V(t) = v0 + a*(t-t0)
R(t) = hypot(d,x(t))
u(t) = V(t)*x(t)/R(t)
x(tc) = 0; Vc = V(tc) > 0
```

数值计算以观测区间中心 t0 归一化，最终换算得到 tc、Vc。`constantVelocity` 固定 a=0；`constantAcceleration` 允许所选短区间内近似匀加速度。最近点处 u=0，并不表示 Vc=0。只包含一侧的区间允许有界外推 tc，但会在摘要明确标记。d=0 只允许单侧处理，最近点是模型外推参考，不支持经过雷达原点的穿越。

## 2. 关联与求解

候选提取/RD处理仍沿用现有链路。`selectMotionTrack` 先按距离、回波强度建立有限数量的轨迹假设；候选关联比较预测斜距和预测**模糊径向速度**的循环差，不再逐点加入固定参考速率的代价。初步关联采用较宽的距离门和软速度代价，最终关联恢复用户的门限。

对每条候选轨迹，枚举径向模糊状态 `u_i(k)=alias_i+2*Vmax*k`，交替执行径向域两优路径动态规划与连续运动模型优化。连续优化使用基础 MATLAB 的 `fminsearch`；不增加 Optimization Toolbox 依赖。缺测 Doppler 不补成零，距离观测仍可用于拟合，输出中相应径向速度保持 NaN。

统一目标由五部分组成：

```text
sum Huber((R_i-Rmodel_i)/sigmaR)
+ sum Huber((u_i(k_i)-umodel_i)/sigmaU)
+ prediction-residual transition cost using actual delta-t
+ ((Vc-reference)/sigmaReference)^2          # 整段仅一次
+ (a/motionAccelerationStd)^2               # 匀加速度模式的弱正则
```

转移项比较相邻径向**预测残差**增量，尺度为 `sqrt(2*sigmaU^2+(motionAccelerationStd*deltaT)^2)`。它不惩罚物理上合理的径向变化，也不要求模糊整数保持不变。距离模型与多普勒观测直接联合，不再把同一批距离得到的标量拟合速度作为额外独立测量重复计权。

每条完整轨迹假设只加一次最近点先验；取消勾选可完全不使用该先验。单窗误差尺度和参考值误差尺度必须由测量/标定估计，不能直接填 FFT bin 间距。重叠窗口使用 `min(1,winStep/winSize)` 折减观测项，属于近似处理，不是完整相关协方差模型或严格最大似然证明。

## 3. 界面2设置

| 控件/字段 | 含义与初值 |
|---|---|
| 解模糊方法 / `unwrapMethod` | 默认“最近点联合解模糊”；可选“旧版全程参考（对比）” |
| 运动模型 / `motionModel` | 默认匀加速度；短段或加速度证据不足时选择恒速 |
| 最近点速率 / `measuredSpeed` | 最近点合速率正值，GUI初值400m/s，必须按实验确认 |
| 使用最近点速度软约束 / `useClosestSpeedPrior` | 默认开启；关闭后输入值不参与新求解 |
| 参考 σ / `closestSpeedStd` | 默认35m/s；越大先验越弱，不是要把轨迹拟合到该误差范围 |
| 指定最近点时刻 / `closestApproachTimeMs` | 不勾选时NaN，自动估计；勾选时固定为所填时间 |
| 最近点 ms | **相对于目标起始物理帧的开始**，不是BIN开始、首滑窗中心或界面1帧号；允许负值 |
| 横向距离 / `perpendicularDistance` | 雷达到直线轨迹的最短距离，m；初值0不是已测几何 |
| 径向方向 | 单侧选接近/远离；确实覆盖最近点两侧才选“跨越最近点” |
| 物理速率上下限 | 对观测段及到最近点之间的速度施加范围；GUI初值1～2000m/s，独立于参考值 |
| 最大绝对加速度 / `maxAbsAcceleration` | 5e4m/s²，仅为初始物理边界，不是减速度测量 |
| 最大外推 / `closestMaxExtrapolationMs` | 50ms，限制最近点距离选段的最大时间；较远外推仍会标记不确定 |
| 测距 σ / `jointRangeStd` | 0.10m，需按数据标定 |
| 径向 σ / `jointRadialStd` | 5m/s，需按数据标定 |
| 最小投影 / `minRadialProjection` | 0.10，只限制直接除角度的输出，不再删除低投影距离观测 |

高级脚本配置保留：`jointMaxStarts=10`、`jointMaxIterations=4`、`jointMaxTrackHypotheses=6`、`jointHuberDelta=2.5`、`jointTransitionWeight=0.2`、`motionAccelerationStd=2e4`、`jointAmbiguityGapThreshold=9`、`jointMaxNormalizedResidual=6`。模糊整数默认 -12～12。所有界限都应按物理工况设置；需要更大搜索范围时显式修改配置，而不是改变参考速度来“拉”结果。

切换文件、目标起始帧或帧周期会改变时间基准，因此界面会取消“指定最近点时刻”，恢复自动估计；需要固定时刻时，请按新基准重新填写。仅改变目标终止帧不改变时间原点。

## 4. 结果和诊断

| 字段 | 意义 |
|---|---|
| `UnwrappedRadialVelocity_mps` | 选择分支后的径向观测值；`UnwrappedVelocity_mps`保留相同兼容含义 |
| `TargetSpeed_mps` | 按每点实际斜距和拟合侧别直接几何折算；低投影、R<=d、Doppler缺测时NaN |
| `ModelTargetSpeed_mps` | 距离和径向速度联合拟合得到的连续运动模型速度；不是新增独立测量 |
| `RadialProjection` / `ModelRadialProjection` | 实测距离直接投影 / 模型预测投影 |
| `RangeObservationValid` | 该距离是否可参与拟合；轻微R<d可作为带噪声距离，但不会强行做速度除法 |
| `GeometryValid` | 是否可以直接几何折算测速 |
| `FittedRange_m` / `FittedRadialVelocity_mps` | 同一个运动模型的距离/径向速度预测 |
| `RadialFitResidual_mps` | 解模糊径向观测减模型预测，m/s |
| `MeasuredSpeedResidual_mps` | 新模式留NaN，不再构造全程真值误差 |
| `DistanceFitSpeedResidual_mps` | 新模式为直接折算速度减模型速度，不是独立精度指标 |

`result.unwrapInfo` 和 `result.fitInfo.unwrapInfo` 保留最近点时间/速度、加速度、代价分解、不同路径数、次优路径代价、模型残差、外推标记和不确定标记。`fitInfo.speed` 在新模式表示 Vc；不能当作全程恒速。绘制轨迹请调用 `predictTrackResult`，不要直接用 `speed*t+intercept`。

新速度图分开绘制直接折算点与联合模型曲线；参考值仅在 tc 位于显示区间内时画一个点，不再画全程参考水平线。全程对单个最近点参考值的MAE/RMSE已停用，兼容字段为NaN。最近点参考差异也不是独立精度验证，因为该值可参与求解。

`estimated` 只表示在当前有界搜索内找到候选，不是实测精度保证。`uncertain` 表示替代路径过近/未找到充分竞争路径、较远外推等；`model-mismatch` 表示距离或径向残差过大，在选轨入口会拒绝该假设。代价间隔是启发式诊断，不是置信概率，不能宣称已经找到了全局唯一解。

## 5. 范围、验证与限制

本实现是有界多初值交替求解，不穷举所有轨迹、连续参数和模糊整数。每次仅从最多16个采样窗口各取两个强候选生成初始假设，可能漏掉弱目标；应检查原始候选和轨迹覆盖，不以曲线平滑作为正确性证明。

模型不适用于转弯、速度反向、横向距离变化或长区间强非匀加速度运动。最近点远在观测区间之外时，Vc与加速度耦合较强，应缩小外推、提供可信最近点时刻或标记不确定。恒速模型中最近点速度对全段的影响属于用户明确选择的恒速假设，而不是重复参考惩罚。

距离—速度耦合修正仍沿用原有后处理，尚未与几何模型迭代联立；修正量继续使用径向速度。横向距离误差、错误I/Q符号、错峰/错轨、丢包均可能导致错误结果。本轮不优化采集、实时性或完整RD Cube内存。

运行：

```matlab
startup
results = runtests('tests/test_closestApproachJoint.m');
assertSuccess(results);
run('tests/run_tests.m');
smoke_test_interfaces(fullfile(tempdir,'radar-ui-smoke'),false);
regression_snr_frame_marker(fullfile(tempdir,'radar-snr-marker-test'));
```

新测试包括恒速/变速、接近/远离/跨最近点、自动/已知最近点时间、缺测、非等间隔、参考关闭/有偏、单次先验计数、低投影、带噪声与距离异常点、径向DP与穷举对比和候选关联。旧几何测试显式使用legacy模式，以保留旧路径兼容验证。GUI测试是无硬件功能检查，不是Windows接板或现场测速精度验收。
