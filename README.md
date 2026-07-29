# Projectile Radar Data Analysis

用于 **AWR2243-2X-CAS-EVM + AM2732R + DCA1000** 外场弹丸数据的 MATLAB 分析代码。项目实现复数 ADC 数据恢复、短时距离–Doppler 处理、二维 RD 功率背景增强、候选点提取、距离–时间轨迹拟合、速度解模糊以及误差评价。

本仓库**不包含任何原始 BIN 数据**。用户需要自行准备符合 `docs/data_format.md` 说明的 DCA1000 数据。

## 主要功能

- DCA1000 单发射、8 接收通道复数 ADC 数据读取
- 逐 Chirp 距离 FFT 与短时 Doppler FFT
- 接收通道功率非相干累加
- 枪击前二维 RD 线性功率背景建模
- 目标/背景功率比增强
- 距离候选点提取与有模糊速度附加
- 多候选距离–时间轨迹搜索和迭代最小二乘拟合
- 基于实测速度先验的全局动态规划速度解模糊
- 距离拟合 RMSE、速度 MAE、速度 RMSE、最小绝对误差及相对误差
- Figure 1–4 和二维 RD 连续变化 GIF

## 仓库结构

```text
projectile-radar-analysis/
├─ README.md
├─ LICENSE
├─ CITATION.cff
├─ .gitignore
├─ src/+pradar/               # 推荐使用的配置驱动公共算法
├─ configs/                   # 三组外场数据配置
├─ scripts/                   # 单组、批量运行入口
├─ examples/                  # 不依赖原始 BIN 的候选点演示
├─ tests/                     # MATLAB 单元测试
├─ docs/                      # 算法、数据格式和参数说明
├─ legacy_cases/              # 保留原始单组分析脚本，便于结果追溯
├─ data/                      # 仅有说明文件；原始数据被忽略
└─ results/                   # 本地输出目录；结果文件被忽略
```

## 快速开始

### 1. 克隆并进入仓库

```bash
git clone <your-repository-url>
cd projectile-radar-analysis
```

### 2. 在 MATLAB 中初始化路径

```matlab
startup
```

### 3. 运行单组数据

打开 `scripts/run_single_case.m`，修改：

```matlab
caseId = "0725_123207";
dataFile = "";
```

`dataFile` 留空时会弹出文件选择框。然后运行：

```matlab
run("scripts/run_single_case.m")
```

可用配置：

- `0725_123207`：实测速度 428.62203 m/s
- `0725_135656`：实测速度 432.09819 m/s
- `0725_143411`：实测速度 1207.82892 m/s

### 4. 运行测试

```matlab
run("tests/run_tests.m")
```

### 5. 运行不依赖原始数据的候选点演示

```matlab
run("examples/demo_candidate_extraction.m")
```

## 默认雷达参数

| 参数 | 数值 |
|---|---:|
| ADC 采样点数 | 64 |
| 每物理帧 Chirp 数 | 256 |
| 接收通道数 | 8 |
| 发射通道数 | 1 |
| ADC 采样率 | 10 MHz |
| 调频斜率 | 60.01 MHz/μs |
| 起始频率 | 77 GHz |
| Chirp 周期 | 12 μs |
| 物理帧周期 | 3.5 ms |
| 短时窗口长度 | 16 Chirp |
| 窗口步进 | 16 Chirp |
| Doppler FFT 点数 | 128 |

各数据组的距离 FFT 点数、背景帧、目标帧、距离门和轨迹参数由 `configs/` 中的配置文件单独定义。

## 处理流程

```text
DCA1000 BIN
→ I/Q 复数恢复
→ Sample × Chirp × Rx 数据重排
→ 逐 Chirp 距离 FFT
→ 16 Chirp 短时窗口
→ Doppler FFT
→ 8 通道功率非相干累加
→ 枪击前二维 RD 功率背景
→ 目标/背景功率比增强
→ 距离候选点提取
→ 距离–时间轨迹关联与迭代拟合
→ 有模糊速度全局动态规划解模糊
→ 误差指标与图像输出
```

完整说明见：

- [`docs/algorithm.md`](docs/algorithm.md)
- [`docs/candidate_extraction.md`](docs/candidate_extraction.md)
- [`docs/track_fitting.md`](docs/track_fitting.md)
- [`docs/data_format.md`](docs/data_format.md)
- [`docs/parameters.md`](docs/parameters.md)

## 原始数据

原始外场 BIN 文件体积较大，也可能包含实验室或项目敏感信息，因此不随仓库发布。`.gitignore` 已排除 `*.bin`、`*.raw`、`*.dat`、`*.mat`、GIF、视频和本地结果文件。

不要将以下内容提交到公开仓库：

- 外场原始 BIN 数据
- 设备日志和包含网络地址的配置
- 厂商 SDK 或不允许再分发的源代码
- 单位内部路径、人员信息和实验敏感参数
- 尚未公开的专利或论文核心材料

## MATLAB 版本与依赖

建议在你实际验证过的 MATLAB 版本上运行。核心算法仅使用常见 MATLAB 数值、表格和绘图函数。GIF 输出使用图像转换函数；若本机环境不支持，可设置：

```matlab
cfg.generateRdGif = false;
```

本仓库中的公共版本由现有单组脚本重构而成，已进行静态检查，但未在当前交付环境中使用 MATLAB 和原始 BIN 数据完成端到端运行验证。`legacy_cases/` 保留了三组结果对应的原始脚本，便于逐项核对。

## 引用

软件引用信息见 [`CITATION.cff`](CITATION.cff)。

## 许可证

代码默认采用 MIT License。发布前请确认代码、算法、实验结果和相关知识产权允许公开。
