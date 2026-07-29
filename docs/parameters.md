# 参数说明

## 雷达与数据参数

| 参数 | 含义 | 单位 |
|---|---|---|
| `numSamples` | 每 Chirp ADC 采样点数 | 点 |
| `numChirpsPerFrame` | 每物理帧 Chirp 数 | Chirp |
| `numRx` | 接收通道数 | 通道 |
| `rangeFftSize` | 距离 FFT 点数 | 点 |
| `dopplerFftSize` | Doppler FFT 点数 | 点 |
| `adcSampleRate` | ADC 采样率 | Hz |
| `slope` | 调频斜率 | Hz/s |
| `startFreq` | 起始频率 | Hz |
| `chirpPeriod` | Chirp 周期 | s |
| `framePeriod` | 物理帧周期 | s |

## 短时处理

| 参数 | 含义 |
|---|---|
| `winSize` | 实际参与相干处理的 Chirp 数 |
| `winStep` | 相邻短时窗口起点间隔 |
| `slowTimeMeanRemoval` | 是否在 Doppler FFT 前沿 Chirp 维减去复数均值 |
| `useFullAliasedVelocityAxis` | 是否保留完整有模糊速度轴 |
| `highSpeedMin` | 非完整速度轴模式下保留的最小绝对有模糊速度 |

## 候选点

| 参数 | 含义 |
|---|---|
| `candidateRangeMin/Max` | 候选距离门 |
| `candidateThresholdDb` | 相对二维 RD 背景的候选门限 |
| `rangeSmoothBins` | 距离轮廓移动平均格点数 |
| `minCandidateSeparation` | 同窗口候选最小距离间隔 |
| `maxCandidatesPerWindow` | 每窗口最大候选数 |

## 轨迹拟合

| 参数 | 含义 |
|---|---|
| `fitSpeedMin/Max` | 两点轨迹假设和最终距离斜率范围 |
| `minHypothesisSpanMs` | 两点生成假设时的最小时间跨度 |
| `trackTolerance` | 候选距离与假设直线的最大偏差 |
| `useVelocityHardGate` | 是否使用循环速度残差硬门限 |
| `velocityTolerance` | 循环速度硬门限或归一化尺度 |
| `minTrackWindows` | 有效轨迹至少覆盖的窗口数 |
| `trackStartTimeMs/trackEndTimeMs` | 允许参与轨迹搜索的时间范围 |

## 解模糊

| 参数 | 含义 |
|---|---|
| `measuredSpeed` | 外部实测速度软先验 |
| `measuredSpeedStd` | 实测速度先验尺度 |
| `distanceFitSpeedStd` | 距离拟合速度尺度 |
| `unwrapContinuityStd` | 相邻解模糊速度连续性尺度 |
| `ambiguityNumberMin/Max` | 搜索的模糊数范围 |
| `unwrapSpeedMin/Max` | 合理真实速度范围 |

## 调参原则

- `candidateThresholdDb` 太高会漏掉弱目标，太低会产生大量杂波候选。
- `trackTolerance` 不应明显小于真实距离分辨率。
- `rangeSmoothBins` 以 FFT 格点为单位，改变距离 FFT 点数后需要重新评估。
- 超高速目标可能折叠到零 Doppler，不能固定使用有模糊速度绝对值门限。
- 外部实测速度不是严格径向真值，因此只作为软约束。
