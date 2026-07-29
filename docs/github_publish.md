# GitHub 公开发布步骤

## 发布前检查

1. 检查 `LICENSE` 中的作者名称是否正确。
2. 修改 `CITATION.cff` 中的 GitHub 用户名和仓库地址。
3. 确认代码、算法和实验结果允许公开。
4. 搜索并删除绝对路径、设备 IP、人员信息和内部项目名称。
5. 确认仓库内没有 `.bin`、`.raw`、`.mat`、日志和大体积 GIF。
6. 在 MATLAB 中运行 `tests/run_tests.m`。
7. 使用一份本地数据运行 `scripts/run_single_case.m`，确认结果输出正常。

## 初始化仓库

```bash
git init
git add .
git commit -m "Initial public release"
git branch -M main
git remote add origin <your-repository-url>
git push -u origin main
```

## 建议的首个 Release

- Tag：`v0.1.0`
- 标题：`Initial public release`
- 说明：不包含外场原始数据；提供三组配置和公共处理流程；端到端结果需要用户自行准备 DCA1000 BIN 数据验证。
