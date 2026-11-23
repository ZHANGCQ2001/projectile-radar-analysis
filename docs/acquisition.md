# 现有手动采集：路径、流程与限制

[返回文档索引](README.md) · [数据格式](data_format.md) · [常见问题](troubleshooting.md)

本文记录当前 `RadarControlMachineApp.m` 的实现，不是新硬件方案。当前只有人工启动的单次采集，没有目标自动触发、循环存储、预触发ADC、板端门控或常驻DLL服务。

## 1. 第三方文件放在哪里

源码运行时 `getAppRoot()` 返回 `uppermachine`，当前约定为：

```text
uppermachine/
├─ RadarControlMachineApp.m
├─ +radarui/
├─ third_party/ti_postproc/
│  ├─ DCA1000EVM_CLI_Control.exe
│  ├─ DCA1000EVM_CLI_Record.exe
│  ├─ AM273X_Capture.json
│  └─ CLI所需的配套DLL和资源
└─ data/channelCalibration_MRR.mat   # 可选；缺失时主界面回退为全1校准
```

不要在不改路径逻辑的情况下，把 `third_party` 迁到仓库根目录。使用已验证的完整CLI配套文件集，不凭文件名猜测哪一个DLL可以删除。该MAT标定路径与仓库根目录的裁剪样本 `data/` 是两个位置。

启动时 `initializeBundledPaths()` 选择自带目录和JSON模板，然后生成 `AM273X_Capture_runtime.json`。正常路径下运行时JSON写在CLI目录；数据默认写入 `C:\CaptureData`。配置目录有回退分支，但不能据此认为所有写入都已经迁到用户AppData。

不要直接修改上一次生成的runtime JSON来长期保存配置，程序会重写它。当前源码便携运行应放在普通用户可写目录，而不是依赖受保护安装目录的写权限。

## 2. 当前按钮流程

```text
配置FPGA
  → 尝试停止遗留record会话
  → CLI fpga
  → CLI record
开始采集
  → 生成带时间戳前缀的runtime JSON
  → CLI start_record
  → 统计本前缀所有_Raw_*.bin的字节总量
  → 达到目标量 / 人工停止 / 收到过数据后连续8秒不增长
  → CLI stop_record
```

采集调用经 `system()` 运行外部EXE；`start_record` 当前传入 `runAsync=false`，虽然邻近注释提到 `start /B`，实际这次调用并未进入该分支。代码未在此启动路径调用串口，也未测量第一包/第一完整帧延迟。

“配置FPGA”配置的是DCA采集链路，不是完整雷达固件启动器。雷达是否正确产生数据、设备网络与供电是否正常，要由现场核验；软件返回码不能代替这些检查。

## 3. 采集量与停止模式

界面采集量默认800 MB，按 **1 MB=1,000,000字节** 计算。模板内容会被 `prepareCaptureJson()` 覆盖：当前实际写入 `captureStopMode='infinite'`，再由MATLAB观察文件大小达到阈值后发停止命令；循环包含 `pause(0.1)`。

因此，800 MB不是采集板缓存容量，也不是经过硬件验证的精确无超量停止边界。分卷大小与总采集量也是两个参数。删除PC文件、缩小分卷文件或增加MATLAB内存，不等于修复采集板的输入/输出吞吐矛盾。

## 4. 已知限制（未由文档更新修复）

| 实现情况 | 使用时应注意 |
|---|---|
| 未实时识别DDR/LVDS溢出日志 | 文件继续增长仍可能伴随采集异常；保留并检查CLI日志 |
| 没有首数据超时；8秒停滞检查要求已收到数据 | 始终0字节时可能一直等待，需要人工停止/排查 |
| 没有独立最大采集时长保护 | 不把该版本用于无人值守长时间采集 |
| 停止函数无论返回码如何都会清除软件录制标志 | UI空闲状态不等于外部进程/设备确实停止 |
| 部分停止分支未检查返回码就显示成功；停滞退出也可能显示完成 | 区分命令执行与数据质量，不仅看成功弹窗 |
| 关闭窗口路径没有统一发送stop_record | 正常操作先点击停止、核对日志和进程，再关闭窗口；不要把关窗口当作硬件停止 |
| 首文件路径默认指向_Raw_0.bin | 总采集量可能跨多卷；后续分析按实际选择文件及帧边界核查 |

仓库 `CLI_LogFile.txt` 的历史记录中有2026-10-12的 `DDR is full` 和 `LVDS buffer full`。它只能证明该次运行出现过告警，不能推导统一安全采集时长或具体丢包量。

## 5. 当前人工操作建议

采集前确认CLI/JSON路径、实际网络配置、目标保存位置权限及可用磁盘；先做有限长度试采。采集期间不要同时进行大文件全局分析，避免额外资源竞争。结束后核对停止返回、文件数量/大小、帧余数以及CLI异常日志，再进行离线处理。

这些是操作检查，不是自动保护功能。发现异常时保留原始文件和日志，不覆盖重采记录。对外共享前按[发布检查清单](release_checklist.md)检查第三方文件与实验信息。

源码：[主界面采集实现](../uppermachine/RadarControlMachineApp.m)。
