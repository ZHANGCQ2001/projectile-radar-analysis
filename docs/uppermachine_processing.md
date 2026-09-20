# 上位机数据处理功能

本分支在原有 `uppermachine/RadarControlMachineApp.m` 的采集、原始 ADC、1D FFT 和 RD 显示功能之外，增加了一个独立的数据处理窗口。

## 入口

运行：

```matlab
startup
app = RadarControlMachineApp;
```

主窗口左侧采集控制区域增加了 **数据处理** 按钮。

点击后会打开 `radarui.ProcessingWindow`。当前 BIN 路径和雷达基础参数会自动从主上位机传入，数据处理参数仍可在处理窗口中单独修改。

## 处理链

```text
DCA1000 BIN
  -> I/Q 恢复
  -> Range FFT
  -> 短时 Doppler FFT
  -> RX 功率非相干累加
  -> 背景 RD 中位数建模
  -> 目标/背景功率比增强
  -> 候选点提取
  -> 距离-时间轨迹搜索
  -> 全局速度解模糊
  -> 结果显示与导出
```

核心算法仍使用 `src/+pradar`，上位机没有复制第二套候选、轨迹或解模糊算法。

## 新增文件

- `src/+pradar/processWindow.m`
  - 公共单窗 Sample x Chirp x Rx 处理函数。
  - 统一 Range FFT、Doppler FFT、慢时间去均值和 RX 功率合并。

- `src/+pradar/runAnalysisCore.m`
  - 面向 GUI 的纯处理入口。
  - 不创建独立 figure、GIF，也不主动写 CSV。
  - 支持进度回调和取消回调。

- `uppermachine/+radarui/buildProcessingConfig.m`
  - 将上位机中的 GHz、MHz/us、Msps、us 等参数统一换算为 `pradar` 使用的 SI 单位。

- `uppermachine/+radarui/ProcessingController.m`
  - 管理一次处理任务的运行状态、取消请求和结果。

- `uppermachine/+radarui/ProcessingWindow.m`
  - 数据处理参数、进度、结果图和导出功能。

## 处理窗口主要参数

### 帧范围

- 背景起始帧 / 背景终止帧：应选弹丸出现之前的纯背景区间。
- 目标起始帧 / 目标终止帧：应覆盖弹丸经过雷达视场的区间。

背景帧和目标帧不要求相邻，但必须位于当前 BIN 文件的完整物理帧范围内。

### 短时 RD

推荐初始值：

```text
winSize        = 16 chirps
winStep        = 16 chirps
dopplerFftSize = 128
```

这里与旧上位机用于浏览 RD 的 `cfg_WinSize` 分离。旧上位机默认可能使用整帧 256 Chirp；弹丸轨迹处理更适合短时 Doppler 窗。

### 帧周期

当前旧上位机没有独立的 frame period 配置项，因此处理窗口初始采用仓库算法默认值：

```text
3.5 ms
```

如果实际固件配置不同，必须在处理窗口中修改，否则跨物理帧的时间轴和距离-时间拟合速度会产生系统误差。

### 参考速度

参考速度参与全局速度解模糊，并用于显示相对参考速度的 RMSE/MAE。

主上位机“大致速度”非零时会自动带入；否则处理窗口初始值为 400 m/s。正式试验时应按当前工况确认。

## 结果页

处理完成后包含：

1. **结果摘要**
   - 候选点数量
   - 最终轨迹点数量
   - 距离-时间拟合速度
   - 距离拟合 RMSE
   - 平均解模糊速度
   - 相对参考速度 RMSE/MAE

2. **背景增强 RD**
   - 目标帧范围内所有短时窗口的平均背景增强 RD。

3. **候选与轨迹**
   - 全部候选点
   - 最终关联轨迹
   - 距离拟合线

4. **速度**
   - 有模糊速度
   - 解模糊速度
   - 参考速度

## 导出

点击 **导出结果** 后生成：

```text
<bin>_processing_result.mat
<bin>_candidates.csv
<bin>_track.csv
<bin>_summary.txt
```

默认 `keepIntermediateData=false`，MAT 文件不保存完整三维 RD Cube，只保存背景图、平均/最大增强 RD、候选表、轨迹表和必要元数据。

如果勾选“保留完整 RD Cube”，结果 MAT 会明显增大。

## 内存提示

当前第一版算法仍会在处理期间构建所选帧范围对应的背景 RD Cube 和目标 RD Cube。处理窗口会估算峰值数组内存；估算超过约 1.5 GiB 时会提示。

对于 800 MB 甚至更大的完整采集文件，推荐先确定事件帧，再只处理事件前的少量背景帧和覆盖弹丸的目标帧，不建议直接将整个采集区间一次性处理。

后续如果需要长时间准实时处理，可以进一步改为流式背景更新和逐帧候选提取，避免目标 RD Cube 全量驻留内存。

## 测试

新增：

- `tests/test_processWindow.m`
- `tests/test_runAnalysisCore.m`

后者使用仓库自带 `data/123207_frames_126_135.bin` 做最小处理链回归。

运行：

```matlab
startup
run('tests/run_tests.m')
```

## 注意

本分支保留原 `RadarControlMachineApp` 的采集、文件加载、原始 ADC、1D FFT、RD 浏览、最大 SNR 趋势和旧拟合功能。新数据处理作为独立窗口接入，因此算法调试不会继续扩大主 App 中 UI 与算法的耦合。


## 候选门、显示范围与轨迹评分

当前版本将“算法搜索范围”和“图像显示范围”分开：

- **候选距离下限/上限**：只决定候选提取在哪个距离范围内工作。
- **显示距离下限/上限**：只决定“候选目标RD”页面显示多大的现场范围。
- “候选目标RD”会用两条白色虚线标出候选距离门，即使候选上限设置为 3 m，也可以继续显示到 6 m 或更远。

轨迹搜索增加了以下可调约束：

- 轨迹起始/终止时间；
- 启用速度硬门限；
- 速度容差；
- 最小绝对有模糊速度。

轨迹全局评分已由原来的“原始点数固定高奖励”改为平衡评分，综合考虑：

- 候选窗口覆盖率；
- 连续窗口比例；
- 平均背景增强强度；
- 归一化距离残差；
- 归一化速度残差；
- 相对参考速度折叠值的残差。

因此，一条点数略多但整体较暗的杂波路径，不再仅因为多几个候选点就获得压倒性的评分优势。
