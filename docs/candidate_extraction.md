# 候选点提取

## 核心定义

一个候选点包含：

```text
窗口编号、中心时刻、候选距离、有模糊速度、相对背景增强量
```

## 步骤 1：二维 RD 沿速度维压缩

对每个窗口和每个距离单元：

```text
E_R(r,w) = max_v E_RD(r,v,w)
```

同时记录最大值对应的速度：

```text
v_alias(r,w) = argmax_v E_RD(r,v,w)
```

因此一张二维 RD 图被转换为一条一维距离增强轮廓。

## 步骤 2：距离门

仅在：

```text
candidateRangeMin ≤ range ≤ candidateRangeMax
```

范围内寻找候选点，排除明显无关的近端耦合和远距离杂波。

## 步骤 3：距离轮廓平滑

使用 `rangeSmoothBins` 点移动平均降低单格波动。该参数以 FFT 格点为单位，改变距离 FFT 点数后，其实际物理宽度会改变。

## 步骤 4：局部峰和门限

距离单元必须比左右邻居高，并且增强量不低于：

```text
candidateThresholdDb
```

才成为初始局部峰。

## 步骤 5：强度排序和最小距离间隔

局部峰按增强量从大到小排序。新峰与已经保留的峰之间必须满足：

```text
|R_new - R_selected| ≥ minCandidateSeparation
```

这相当于距离维非极大值抑制，可避免一个主瓣或旁瓣簇生成多个重复候选。

## 步骤 6：限制每窗口候选数量

每个窗口最多保留 `maxCandidatesPerWindow` 个峰，避免后续两点直线假设组合数量过大。

## 输出

候选点表包含：

- `GlobalWindow`
- `PhysicalFrame`
- `WindowInFrame`
- `Time_ms`
- `Range_m`
- `AliasedVelocity_mps`
- `RelativeStrength_dB`
- `RangeBin`

候选点不是最终轨迹点。最终轨迹只从候选表中选择满足跨窗口连续性的点。
