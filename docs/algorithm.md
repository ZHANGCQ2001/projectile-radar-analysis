# 数据处理算法流程

[返回文档索引](README.md) · [参数说明](parameters.md) · [几何拟合](track_fitting.md)

## 1. 两个界面不是同一条 RD 处理链

| 内容 | 界面1整体浏览 | 界面2/公共精细处理 |
|---|---|---|
| 入口 | `RadarControlMachineApp.computeWindowRd` | `pradar.processWindow` |
| 输入 | 从 BIN 定位并读取当前滑窗 | 已重排的 Sample × Chirp × Rx 窗口 |
| 中值滤波 | 每 RX 的实部/虚部沿 Chirp 做 3 点 `medfilt1` | 没有这一步 |
| 慢时间去均值 | 固定开启 | 由 `cfg.slowTimeMeanRemoval` 决定 |
| FFT | 距离 Hann + FFT；Doppler Hann + 窗长 FFT | 距离/Doppler Hann + 可配置 FFT 点数 |
| RX 合并 | 归一化校准后各 RX 幅度求和，再 `20*log10` | 各 RX 模平方求和，再 `10*log10` |
| 后续 | 局部对比指标与每帧最大值，用于选帧 | 独立背景功率增强、候选、轨迹、几何解模糊 |

因此，不能要求两个界面使用相同参数时所有 dB 值也完全一致。主界面校准载入的是通道归一化相位；合并路径是幅度和，不是相干波束形成。

## 2. 界面1最大 SNR 的实际定义

记主界面 RD 对数结果为 `L(r,k)`，去除保护区并归一化的训练核为 `K`：

```text
localFloor = conv2(L, K, 'same')
snrMap = L - localFloor
windowMaximum = max(snrMap within valid bins)
frameMaximum = max(valid windowMaximum values in the physical frame)
```

最大值搜索排除边缘单元，并应用界面1的距离与**有模糊径向速度**门。训练区在 dB 域求均值，这个量更准确地说是局部对数对比指标；保留界面的“SNR”名称，但不将其解释为经过热噪声标定的功率信噪比。

最大点搜索本身不以 `cfg_offset_dB` 做目标存在性判决。对大多数噪声窗口也能找到最大值；“有限最大值”不能作为“有弹丸”的证据。增减门范围、窗长会改变所搜索的单元集合，跨配置对比需记录参数。

小 Doppler 窗需要特别检查边缘屏蔽：代码取 `edgeD=Td+Gd+1`，两侧各屏蔽 `edgeD` 列。若 `WinSize<=2*edgeD`，可能无剩余列；默认 Td=4、Gd=2 时，16 点窗口也仅剩 2 列。当前没有自动按窗长缩放此边缘策略。

## 3. 界面2的短时 RD 与背景增强

```text
BIN → 小端 I/Q 恢复 → Sample × Chirp × Rx
    → 逐帧切短时窗 → 可选慢时间去均值
    → Range Hann / FFT → Doppler Hann / FFT / fftshift
    → RX 功率非相干合并
    → 所选背景窗口中位数 → 目标/背景功率比
    → 候选提取 → 几何轨迹关联 → 全局解模糊与逐点折算
```

对第 m 个 RX：

```text
P_RD(r,k,w) = sum_m abs(X_m(r,k,w))^2
B_RD(r,k) = median_w P_RD_background(r,k,w)
E_RD(r,k,w) = 10*log10((P_RD(r,k,w)+epsilon)/(B_RD(r,k)+epsilon))
```

`E_RD` 是目标窗口功率相对所选背景功率的增强量，不是界面1 `snrMap`。背景必须来自相同采样/处理配置下的无目标区间；背景中含目标会改变增强结果。负增强值保留在数据中，图的色轴下限不等于数据被置零。

`processFrameRange` 另算逐 Chirp Range FFT 用于距离—时间产品；该路径不等于已去均值的短时 RD 结果。

## 4. 候选与几何轨迹

`range`：沿 Doppler 取最大增强，保留距离和对应模糊径向速度；`velocity`：在距离门内沿距离取最大增强，保留速度和对应距离。局部峰、门限、间距和数量限制见[候选提取](candidate_extraction.md)。

两种模式都将候选交给 `selectTrack`。当前模型为已知固定横向距离 d、同侧直线近似恒速：

```text
x(t) = x0 + V*t
R_pred(t) = hypot(d, x(t))
v_r,pred(t) = V*x(t)/R_pred(t)
```

候选关联比较斜距残差、周期性模糊径向速度差、按各点投影后的参考速率以及背景增强强度。d>0 时在斜距域优化距离残差，不再无条件假设 `R(t)=V*t+R0`。初始位置自由估计，详见[几何拟合](track_fitting.md)。

## 5. 解模糊和指标

每个点先枚举 `v_r(k)=v_alias+2*k*Vmax`，再除以其带符号几何投影得到沿轨迹速率候选。有效点按时间倒序排列，动态规划以目标运动结束帧的参考速率为锚点逆向求解，代价包含末帧参考速率差、相邻有效点速率差和模糊数跳变惩罚；距离模型拟合速率默认不再进入锚点。没有实现距离/速度联合最大似然估计或严格加速度模型。

指标优先使用 `TargetSpeed_mps` 的有限值：

```text
error_i = TargetSpeed_i - cfg.measuredSpeed
MAE = mean(abs(error_i))
RMSE = sqrt(mean(error_i^2))
```

参考值也用于解模糊，所以这些是相对参考值的差异，不能自动作为独立精度验收。无轨迹或无可行解时应保留失败/NaN 状态，不把默认参考速率当成结果。

## 6. 距离—速度耦合与盲速边界

可选耦合修正使用 `centerFreq/slope * UnwrappedRadialVelocity_mps`，加减由配置符号决定；不能代入沿轨迹速率。当前修正是后处理，未与几何估计迭代联立。默认不开启。

理想固定慢时间正弦模型下，沿 Chirp 去均值抑制折叠到零 Doppler 的分量；对应径向速度周期为 `lambda/(2*chirpPeriod)`。零填充改变速度网格，不增加实际相干观测时间，也不消除该模糊周期。研究入口见 [`+studies/`](../+studies/)。

## 源码

[界面1](../uppermachine/RadarControlMachineApp.m) · [单窗处理](../src/+pradar/processWindow.m) · [背景增强](../src/+pradar/enhancePower.m) · [帧处理](../src/+pradar/processFrameRange.m) · [处理核心](../src/+pradar/runAnalysisCore.m) · [指标](../src/+pradar/computeVelocityMetrics.m)
