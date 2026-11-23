# 测试与验证范围

[返回文档索引](README.md) · [贡献指南](../CONTRIBUTING.md)

## 1. 测试前准备

从功能分支的完整工程根目录运行，保留 `data/123207_frames_126_135.bin` 和JSON模板。GUI回归会创建App并初始化本地配置/目录，但**不执行配置FPGA、开始采集或停止采集命令**。界面1相关测试需要 Signal Processing Toolbox。

## 2. 单元测试

```matlab
startup
run('tests/run_tests.m')
```

脚本使用 `testsuite(...,'IncludeSubfolders',true)`，展示结果并要求全部 `Passed`。样本缺失时，Core样本测试可能标记为不完整；不能将其等同于完整通过。

覆盖包含：候选提取、循环速度差、功率增强、wrap、单窗处理、Core样本运行、轨迹评分、几何投影、接近/远离轨迹、逐点解模糊，以及帧级SNR汇总。确切测试数以本次结果为准，不仅检查“有没有红字”。

## 3. 两个界面的离线功能检查

```matlab
startup
smoke_test_interfaces(fullfile(tempdir,'radar-ui-smoke'), false)
```

检查界面1构建/样本加载/SNR曲线、旧解模糊控件移除、目标帧范围传递、几何/参考速率/速度上下限保留，以及界面2运行完成和导出按钮状态。

第二个参数 `false` 跳过截图。需要桌面图形环境且确实要导出截图时再用 `true`；`exportapp` 在无显示环境失败不一定代表处理算法失败，但功能断言仍需通过。

## 4. SNR当前帧标记回归

```matlab
startup
regression_snr_frame_marker(fullfile(tempdir,'radar-snr-marker-test'))
```

脚本创建临时短BIN，验证前后跳帧、重复访问、切换视图、隐藏旧标记清理、长/短文件反复加载、每帧4个窗口、参数失效清理、坐标轴重置后恢复，以及SNR数据不被标记移动改变。

检查图形对象使用 `findall`，防止 `HandleVisibility='off'` 对象被普通查找遗漏。通过后会输出 `snr-frame-marker-passed.txt`；脚本结束清理临时文件和App。

## 5. 不依赖GUI的最小样本处理

示例与 `tests/test_runAnalysisCore.m` 的配置结构一致，用于检查流程，**不宣称所选两帧必然产生正确弹丸轨迹**：

```matlab
startup
cfg = pradar.defaultConfig();
cfg.measuredSpeed = 428.62203;
cfg.slowTimeMeanRemoval = false;
cfg.useFullAliasedVelocityAxis = true;
cfg.backgroundFrameStart = 1;
cfg.backgroundFrameEnd = 1;
cfg.targetFrameStart = 2;
cfg.targetFrameEnd = 2;
cfg.fitSpeedMin = 200;
cfg.fitSpeedMax = 800;
cfg.unwrapSpeedMin = 150;
cfg.unwrapSpeedMax = 850;
cfg.keepIntermediateData = false;
result = pradar.runAnalysisCore(cfg, ...
    fullfile(pwd,'data','123207_frames_126_135.bin'));
assert(result.totalFrames == 10);
disp(result.fitInfo);
```

Core不创建figure/GIF或主动导出CSV；主界面的数据与速度图并不是这个无GUI示例的自动输出。

## 6. 既有验证记录与本次文档更新

2026-11-23 的SNR标记修复已在 MATLAB R2025b / Ubuntu 24.04 完成：32项单元测试、双界面功能检查、标记切换文件回归。该记录针对相应修复代码，不等于确定了所有MATLAB版本兼容性，也不等于Windows采集卡验证。

本次文档整理不修改MATLAB代码，不把文档链接检查表述为重新运行单元测试。后续发布应记录本次实际环境、提交号、通过/失败/不完整数量和GUI检查结果。

离线回归不覆盖：真实UDP收包质量、DCA溢出、真实触发延迟、Windows部署安装、交互截图布局验收或实弹测速精度。它们必须在相应环境分别验证，不可相互替代。

源码：[测试入口](../tests/run_tests.m)、[Core样本测试](../tests/test_runAnalysisCore.m)、[双界面检查](../scripts/smoke_test_interfaces.m)、[标记回归](../scripts/regression_snr_frame_marker.m)。
