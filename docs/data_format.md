# BIN 数据格式、帧号与时间轴

[返回文档索引](README.md) · [样本说明](../data/README.md)

## 1. 当前读取器的假设

`pradar.readDca1000Frame` 按以下格式读取，不自动识别任意雷达/SDK的输出格式：

- `numTx=1`，公共校验明确拒绝其他Tx数量；默认8Rx、64个复数Sample、256个Chirp。
- 每个复数样本由交替的16位I、Q构成，小端、有符号二补码；读取uint16后转换负数。
- 文件是可直接按帧长度定位的连续ADC字节，不含需要另行解释的UDP包头、序号或自定义帧头。
- 数据顺序等价于先形成 `[Sample, Rx, Chirp]`，再置换为 `[Sample, Chirp, Rx]`。

计数参数可配置不代表任意多TX、lane或IQ布局自动兼容。若当前采集程序输出带包元数据的文件，必须先核实并转换；读取器没有自动剥离UDP头、重排网络包或恢复丢失帧的能力。不能只凭文件名 `_Raw_*.bin` 判断格式。

## 2. 单帧字节数

对于当前1Tx复数格式：

```text
bytesPerComplexSample = 2(I/Q) * 2 bytes = 4 bytes
bytesPerChirp = numSamples * numRx * 4
bytesPerFrame = numSamples * numRx * numChirpsPerFrame * 4
```

默认值：

```text
64 * 8 * 4 = 2,048 bytes / chirp
64 * 8 * 256 * 4 = 524,288 bytes / frame = 512 KiB
```

`numSamples=64` 是64个复数采样点，不是将I/Q分别计数后得到的128。界面1设置校验里遗留的两倍点数检查不应当反过来修改真实数据解释。

内部维度：

```text
ADC frame:  Sample × Chirp × Rx       (默认 64 × 256 × 8)
ADC window: Sample × winSize × Rx
RD power:   Range bin × Doppler bin × Window
```

## 3. 物理帧、滑窗和时间不是同一个索引

文件内物理帧以1为起点。帧内滑窗不跨帧；令子窗索引q从0开始：

```text
windowsPerFrame = floor((numChirpsPerFrame-winSize)/winStep) + 1
physicalFrame = floor((globalWindow-1)/windowsPerFrame) + 1
q = mod(globalWindow-1, windowsPerFrame)
chirpOffset = q*winStep
```

上式 `globalWindow` 指界面1从整文件起点计数的滑窗序号。界面2候选表的 `GlobalWindow` 则从所选目标区间重新计数，对应文件物理帧应为 `targetFrameStart + floor((GlobalWindow-1)/windowsPerFrame)`；不要漏加目标起始帧偏移。

在界面2目标区间中，窗口中心时间为：

```text
t = (physicalFrame-targetFrameStart)*framePeriod
    + (chirpOffset+(winSize-1)/2)*chirpPeriod
Time_ms = t*1000
```

因此跨帧时要包含真实帧周期，不能忽略帧空闲时间。界面1的SNR横轴是物理帧号，界面2轨迹时间门是目标区间相对毫秒，两者不能直接互填。

## 4. 裁剪样本和分卷

`data/123207_frames_126_135.bin` 是10帧裁剪样本。其文件内帧号1～10对应源文件126～135；程序不会从文件名自动恢复原始帧号。使用完整案例配置前必须重新映射帧范围，且裁剪文件不包含源文件的全部背景帧。

TI CLI可能产生同前缀 `_Raw_0.bin`、`_Raw_1.bin` 等分卷。界面只分析当前选择的单个文件，不自动拼接，也不自动保证某分卷的首字节就是物理帧起点。先确认实际输出格式、分卷字节边界、连续性和丢包情况，再决定是否可以拼接/裁剪；不能任意拼接带头文件。

## 5. 完整性检查的含义

Core和界面2用 `floor(fileBytes/bytesPerFrame)` 计算完整帧数，并报告余数字节；处理范围限制在完整帧内。这个检查只能发现不整帧尾部，**不能证明中间无丢包、无补零或无帧错位**。

采集日志出现 `DDR is full` 或 `LVDS buffer full` 时，保留异常记录，不把“文件大小正常”视为有效数据证明。当前程序不自动给出每一帧的网络质量标签。

跨配置移交数据时，至少保存：采样点/Chirp/RX/TX、IQ顺序和位宽、lane布局说明、Chirp及帧周期、采集文件前缀/分卷顺序、裁剪起止源帧、日志和几何测量信息。当前BIN本身不嵌入这些全部信息，需要随实验记录保存。

源码：[读取器](../src/+pradar/readDca1000Frame.m)、[参数推导](../src/+pradar/deriveParameters.m)、[时序生成](../src/+pradar/processFrameRange.m)、[Core帧范围校验](../src/+pradar/runAnalysisCore.m)。
