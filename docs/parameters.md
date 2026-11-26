# 参数说明：来源、单位与约束

[返回文档索引](README.md) · [使用说明](uppermachine_processing.md)

## 新默认解模糊参数

本分支默认 `unwrapMethod="closestApproach"`。`measuredSpeed` 仅为最近点合速率，允许关闭其先验；`radialDirection=0` 支持跨最近点。GUI物理速率范围独立设置为1～2000m/s，不随参考值变化。新增误差尺度、最近点时刻、运动模型和搜索参数见[新方法参数表](closest_approach_unwrapping.md#3-界面2设置)。

下方第4～6节中“固定一侧、每点参考代价、measuredAlias权重、unwrapMeasured/unwrapFit权重”仅在legacy模式生效；新模式不读取这些全程参考权重。实际值以导出的result.cfg为准。

## 1. 默认值的来源

参数优先级不是一个全局配置文件决定的。界面1使用 App 的 `cfg_*` 属性；界面2首次打开先经 `radarui.buildProcessingConfig()`，再由其控件收集参数；脚本使用 `pradar.defaultConfig()` 加案例覆盖。

| 参数 | 公共默认 | 界面2首次从界面1打开 |
|---|---:|---:|
| `winSize / winStep` | 64 / 64 | 通常 64 / 64（不超过每帧 Chirp 数） |
| `dopplerFftSize` | 256 | 通常 256 |
| `slowTimeMeanRemoval` | true | false，由独立勾选框控制 |
| `useVelocityHardGate` | false | true |
| `useFullAliasedVelocityAxis` | false（但 `highSpeedMin=0`） | true |
| `candidateRangeMin / Max` | 2 / 10 m | 继承公共默认 |
| `displayRangeMin / Max` | 0 / 10 m | 0 / 10 m |
| `measuredSpeed` | NaN；启用最近点先验时必须填写 | 400 m/s 初值，不是实测结果 |
| `fitSpeedMin / Max` | 200 / 1700 m/s | 1 / 2000 m/s，独立于参考值 |
| `perpendicularDistance` | 0 m | 0 m |
| `radialDirection` | +1 | 远离（距离增加） |
| `minRadialProjection` | 0.10 | 0.10 |
| `keepIntermediateData` | `defaultConfig` 未定义；Core 缺省按 false | false |

界面1的浏览窗默认 256/256，RD 去均值固定开启，Doppler FFT 等于窗长。界面2输入框创建时的占位数值可能随后被 `applyConfigToControls()` 覆盖，以最终界面值和导出 `result.cfg` 为准。

## 2. 雷达与数据参数

| 公共字段 | 含义与默认值 | 公共单位 / 界面1单位 |
|---|---|---|
| `numSamples` | 每 Chirp 每 RX 的复数 ADC 点数，64；不是 I/Q 两路整数总数 | 点 |
| `numChirpsPerFrame` | 每物理帧 Chirp 数，256 | Chirp |
| `numRx / numTx` | 默认 8 / 1；当前公共读取器只支持 numTx=1 | 通道 |
| `adcSampleRate` | 10e6 | Hz / Msps |
| `slope` | 60.01e12 | Hz/s / MHz/μs |
| `startFreq` | 77e9；是起始频率，不等于精确中心频率 | Hz / GHz |
| `chirpPeriod` | 12e-6 | s / μs |
| `framePeriod` | 3.5e-3；界面2可修改，界面1传入初值为3.5 ms | s / 界面2 ms |
| `rangeFftSize` | 256 | 点 |
| `dopplerFftSize` | 128；须为偶数且不小于 winSize | 点 |

配置桥接换算为 GHz×1e9、MHz/μs×1e12、Msps×1e6、μs×1e-6、ms×1e-3。软件参数必须匹配固件；修改处理参数不等于下发雷达采样配置。

公共推导：

```text
adcDuration = numSamples / adcSampleRate
bandwidth = slope * adcDuration
centerFreq = startFreq + bandwidth/2
lambda = c / centerFreq
rangeBinSpacing = c*adcSampleRate/(2*slope*rangeFftSize)
trueVelocityResolution = lambda/(2*winSize*chirpPeriod)
velocityGridSpacing = lambda/(2*dopplerFftSize*chirpPeriod)
Vmax = lambda/(4*chirpPeriod)
```

增加 FFT 点数细化网格，不改变由实际采样时长决定的物理分辨能力。

## 3. 帧、滑窗和时间门

| 字段 | 含义 |
|---|---|
| `backgroundFrameStart/End` | 当前 BIN 的背景物理帧，闭区间 |
| `targetFrameStart/End` | 当前 BIN 的目标物理帧，闭区间 |
| `winSize` | 参与单窗处理的 Chirp 数，界面2至少2，不超过每帧 Chirp 数 |
| `winStep` | 帧内相邻窗口起点的 Chirp 间隔，至少1 |
| `trackStartTimeMs/EndTimeMs` | 目标区间第一物理帧起点为零的相对时间门，单位ms |

`windowsPerFrame=floor((numChirpsPerFrame-winSize)/winStep)+1`。不跨物理帧拼窗。窗口时刻包含帧间隔和帧内中心偏移，不能把窗口序号直接乘一个固定步长当成全部时间轴。

界面1的参数对话框要求步进不大于窗长；界面2没有同样的上限检查，步进大于窗长会留下未处理 Chirp 区间。两者不是同一个配置入口。

## 4. 几何与速度参数

| 字段 | 物理含义 / 约束 |
|---|---|
| `perpendicularDistance` | 固定直线轨迹与雷达的最短距离d，m，非负 |
| `radialDirection` | +1 远离，-1 接近；选定片段不能跨最近点 |
| `minRadialProjection` | 最小绝对投影，范围(0,1]；默认0.10 |
| `measuredSpeed` | 沿轨迹参考速率，界面2必须为正数，非径向真值 |
| `fitSpeedMin/Max` | 几何轨迹的沿轨迹速率范围，不是斜距直线斜率范围 |
| `unwrapSpeedMin/Max` | 逐点几何折算候选的沿轨迹速率范围 |
| `ambiguityNumberMin/Max` | 径向 Doppler 模糊数整数搜索范围，公共默认 -12～12；GUI未单独暴露 |

界面2收集参数时将 `unwrapSpeedMin/Max` 与控件中的 `fitSpeedMin/Max` 同步。脚本配置仍可单独设置两组范围。接近时不要输入负的沿轨迹速率；使用 `radialDirection=-1` 表示方向。

## 5. 候选、显示与关联

| 字段 | 默认值与含义 |
|---|---|
| `rdProjectionMode` | `"range"`；`"velocity"` 为另一种候选入口 |
| `candidateThresholdDb` | 3 dB，相对独立背景的增强门限，不是界面1最大SNR门限 |
| `maxCandidatesPerWindow` | 6 |
| `rangeSmoothBins` | 3，距离网格平滑长度 |
| `minCandidateSeparation` | 0.25 m，同窗口距离峰间隔 |
| `velocitySmoothBins` | 3，速度投影模式平滑长度 |
| `minVelocityCandidateSeparation` | 10 m/s，速度候选间隔 |
| `highSpeedMin` | 0 m/s，最小绝对**有模糊径向速度**，不是目标真实最低速率 |
| `trackTolerance` | 0.55 m，几何预测斜距残差门限 |
| `minHypothesisSpanMs` | 0.40 ms，两点生成假设的最小时间跨度 |
| `minTrackWindows` | 5，最少关联窗口数 |
| `maxTrackIterations` | 6 |
| `velocityTolerance` | 70 m/s，模糊速度循环残差门限/尺度 |
| `measuredAliasTolerance` | 60 m/s，参考速率逐点投影后的循环残差尺度 |

显示距离门仅裁剪视图，不改变候选表；候选距离门才改变搜索范围。速度硬门限关闭不等于移除所有速度软代价；高真实速率可能折叠到零附近，不能仅靠 `highSpeedMin` 识别高速目标。

全局轨迹评分使用覆盖率、连续比例、平均增强和归一化残差。`trackCoverageWeight`、`trackContinuityWeight`、`trackMeanStrengthWeight`、`trackDistanceNormalizedPenalty`、`trackVelocityNormalizedPenalty`、`trackMeasuredAliasNormalizedPenalty` 为当前字段；旧 `trackCountWeight` 等兼容字段不应误当成现行评分主参数。

## 6. 解模糊权重与输出控制

`unwrapMeasuredWeight / unwrapFitWeight / unwrapContinuityWeight` 的公共默认值为 1.00 / 0.45 / 0.80。对应误差尺度 `measuredSpeedStd / distanceFitSpeedStd / unwrapContinuityStd` 默认为35 / 50 / 25 m/s；界面2配置桥接还会按初始参考速率设置尺度。这些是代价函数尺度，不是软件实测出的标准差或CRLB。

`applyRangeVelocityCouplingCorrection=false` 为默认；启用时修正用径向速度，符号由 `rangeVelocityCouplingSign` 控制。`plotVisible`、`generateRdGif`、`saveResults` 属于脚本输出设置；GUI调用Core并单独导出，不因这些字段自动写GIF。

`keepIntermediateData=false` 仅裁剪返回的重型数组，不能保证处理中不分配 RD Cube。

## 7. 当前校验边界

界面1实际读取 `cfg_Samples` 个复数采样点，设置保存处仍用 `2*newSamples` 检查最小 Range FFT 点数，属于已知不一致；不要为了通过提示就把采样点改成错误值。公共 `validateConfig` 也并未替代完整的硬件数据格式验证。解析错误、非法几何和未知方向不能用放宽门限来掩盖。

源码：[公共默认](../src/+pradar/defaultConfig.m)、[参数推导](../src/+pradar/deriveParameters.m)、[配置桥接](../uppermachine/+radarui/buildProcessingConfig.m)、[界面2参数收集](../uppermachine/+radarui/ProcessingWindow.m)、[校验](../src/+pradar/validateConfig.m)。
