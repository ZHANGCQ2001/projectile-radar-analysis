# DCA1000 数据格式

## 当前支持范围

- 单发射通道；
- 8 个接收通道；
- 复数 ADC 数据；
- I/Q 交替存储；
- 小端字节序；
- 每物理帧 256 个 Chirp；
- 每 Chirp 64 个复数 ADC 采样点。

## 单帧数据量

单个接收通道、单个 Chirp：

```text
64 samples × 2(I/Q) × 2 bytes = 256 bytes
```

8 个接收通道、单个 Chirp：

```text
64 × 8 × 2 × 2 = 2048 bytes
```

单物理帧：

```text
2048 × 256 = 524288 bytes = 512 KiB
```

## 程序内部维度

原始重排后：

```text
Sample × Chirp × Rx
```

当前默认尺寸：

```text
64 × 256 × 8
```

短时 RD 功率立方体：

```text
Range bin × Doppler bin × Window
```

## 注意事项

若采集软件的通道顺序、I/Q 顺序、发射通道数或帧结构不同，必须修改 `readDca1000Frame.m`。不要仅通过观察图像“看起来合理”判断数据解析正确，应使用已知距离、静态角反射器或测试源验证。
