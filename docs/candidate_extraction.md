# 候选点提取

[返回文档索引](README.md) · [算法流程](algorithm.md) · [几何轨迹](track_fitting.md)

候选点包含窗口、时刻、斜距、有模糊径向速度和相对背景增强量。它是“可能的目标点”，不是界面1的全图最大 SNR 点，也不是最终轨迹。

## 1. range 投影：保留距离

`compressRdToRangeProfile` 在速度掩膜允许的单元中取最大背景增强：

```text
E_R(r,w) = max_k E_RD(r,k,w)
k_star(r,w) = argmax_k E_RD(r,k,w)
v_alias(r,w) = selectedVelocityAxis(k_star(r,w))
```

`argmax` 返回索引，不是速度值本身；必须映射到对应有模糊速度坐标。

`extractCandidates` 的顺序为：距离门、移动平均、局部峰、增强门限、强度排序、最小间距、数量上限。实现中先对轮廓 `movmean`，再将距离门外值设为 `-Inf`；局部峰判据为“≥左邻且>右邻”，只检查距离门内部单元，门至少覆盖3个bin。

保留峰需满足：

```text
profileSmooth >= candidateThresholdDb
abs(R_new - R_selected) >= minCandidateSeparation
count <= maxCandidatesPerWindow
```

`RelativeStrength_dB` 是平滑后的轮廓值；对应速度从压缩时的 `aliasVelocityMap` 取得。默认3点平滑以FFT网格为单位，改变FFT长度后其物理宽度也改变。该流程不是另一个标准CA-CFAR实现。

## 2. velocity 投影：保留模糊速度

`compressRdToVelocityProfile` 在候选距离门内压缩距离维，记录各速度单元最大增强及其对应斜距。`extractVelocityCandidates` 再执行速度轮廓平滑、速度掩膜、周期邻居峰检测、门限和周期速度间隔筛选。

局部峰和最小速度间距按Doppler圆周处理，使接近 `-Vmax` 与 `+Vmax` 的点被视为邻近。当前平滑仍使用普通 `movmean`，不是整条处理链都采用循环卷积。

两种投影输出同类候选表并调用同一个 `selectTrack`；当前 `velocity` 模式不等于新增了独立速度域轨迹模型。

## 3. 输出字段

| 字段 | 含义 |
|---|---|
| `GlobalWindow` | 本次目标帧区间中从1开始的窗口序号 |
| `PhysicalFrame` | 当前BIN内的物理帧号，不是裁剪前源文件帧号 |
| `WindowInFrame` | 该物理帧中的窗口序号 |
| `Time_ms` | 目标区间第一帧起点为零的窗口中心时刻 |
| `Range_m` | 候选斜距，m |
| `AliasedVelocity_mps` | 有模糊径向速度，m/s |
| `RelativeStrength_dB` | 平滑投影轮廓的背景增强量 |
| `RangeBin` | 距离网格索引 |
| `VelocityBin` | 仅速度投影候选表额外提供的速度网格索引 |

`candidateRangeMin/Max` 控制搜索；`displayRangeMin/Max` 只控制图的显示。两者分离是为了在观察更大场景时仍使用较窄候选门。

## 4. 调参和边界

门限过低或每窗候选数过大，会增加杂波和两点假设组合；并非候选越多结果越可靠。门限过高会丢失弱目标。背景含目标、速度掩膜排除目标、错误I/Q布局都可能导致无候选，不能只降低门限。

后续轨迹搜索才应用逐点几何有效性和距离/速度一致性约束；“候选数量>0”并不保证有轨迹，“有轨迹”也不保证速度解模糊存在可行路径。

源码：[距离投影](../src/+pradar/compressRdToRangeProfile.m)、[距离候选](../src/+pradar/extractCandidates.m)、[速度投影](../src/+pradar/compressRdToVelocityProfile.m)、[速度候选](../src/+pradar/extractVelocityCandidates.m)。
