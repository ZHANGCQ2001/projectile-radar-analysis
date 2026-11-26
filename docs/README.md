# 文档索引

本分支为 `feature/closest-approach-joint-unwrapping`，基于 `88d02d5`。新默认解模糊及参数含义以[最近点联合方法](closest_approach_unwrapping.md)为准；旧方法明确标为legacy。

| 任务 | 文档 |
|---|---|
| 最近点速度锚定、变速、跨最近点、诊断 | [联合解模糊](closest_approach_unwrapping.md) |
| 第一次启动、整体了解 | [项目 README](../README.md) |
| 界面1选帧、界面2精细处理 | [双界面使用说明](uppermachine_processing.md) |
| 理解两套 RD 路径与 dB 指标 | [算法流程](algorithm.md) |
| 参数单位、默认值及来源 | [参数说明](parameters.md) |
| 横向距离、方向、逐点折算和输出字段 | [几何轨迹拟合与解模糊](track_fitting.md) |
| 候选点如何产生 | [候选提取](candidate_extraction.md) |
| BIN 布局、帧号、分卷与尾部字节 | [数据格式](data_format.md) |
| 无雷达的样本验证 | [样本说明](../data/README.md) |
| 现有手动采集路径和限制 | [采集说明](acquisition.md) |
| 启动、显示和无轨迹排查 | [常见问题](troubleshooting.md) |
| 单元测试与 GUI 回归 | [测试说明](testing.md) |
| 修改代码与文档 | [贡献指南](../CONTRIBUTING.md) |
| 对外共享与版本发布 | [发布步骤](github_publish.md)、[发布检查清单](release_checklist.md) |

阅读顺序建议：README → 双界面使用说明 → 参数说明；需要解释测速结果时，再查几何拟合与数据格式。

文档中的“默认值”必须区分公共 `pradar.defaultConfig()`、界面1属性、`radarui.buildProcessingConfig()` 和案例配置。界面上输入的运行参数优先，历史结果图不是最新代码的自动验收证明。
