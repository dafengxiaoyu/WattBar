# WattBar

适用于 Apple Silicon Mac 的原生菜单栏电池功率监视器，使用 Swift 6、SwiftUI、AppKit 和 IOKit，无第三方依赖。

## 使用

- 系统要求为 Apple Silicon 和 macOS 14 或更新版本。从 [Releases](../../releases/latest) 下载应用。
- 双击 `WattBar.app` 打开功率窗口。关闭窗口后，仍可从菜单栏查看电池净功率。
- 设置中的读取间隔可选 1、2 或 5 秒，默认为 2 秒，也可选择登录时启动。

## 三种功率

| 指标 | 来源 |
| --- | --- |
| 电池净功率 | 电压（mV）× 有符号电流（mA）÷ 1,000,000。正值表示充电，负值表示放电。 |
| Mac 直流输入 | 在已验证的 MacBookPro18,1 上读取 AppleSMC 的 `PDTR`，显示接电时 Mac 侧的直流输入功率。 |
| 适配器额定功率 | 由 `IOPSCopyExternalPowerAdapterDetails` 提供。例如 140 W 表示适配器额定功率。 |

MacBookPro18,1 优先使用 AppleSMC 的 `B0AV` 和 `B0AC` 读取电池电压和电流，失败时回退到 `AppleSmartBattery` 的 `Voltage` 与 `Amperage`。其他机型走 IOKit 路径，可用性取决于硬件和系统版本。AppleSMC 底层协议未公开，读数缺失时界面会明确标记。界面保留一位小数，绝对误差未经外部仪表校准。

在一台 2021 款 16 英寸 MacBook Pro（M1 Pro）上，SMC 的一秒采样多数有变化，IOKit 电池快照在持续充电时曾约 60 秒才变化一次。界面会提示数值未变化的时长。拔电后若系统暂时仍报告正电流，WattBar 会暂时隐藏功率，直到读数一致。

## 构建与测试

用支持 Swift 6 的 Xcode 打开 `WattBar.xcodeproj`，选择 WattBar 方案和 My Mac，按 **⌘R**。也可使用 Apple Command Line Tools 构建。

```sh
bash build.sh
open build/WattBar.app
bash test.sh
bash test.sh --live
```

发布包使用临时签名，未经过 Apple 公证。从 GitHub 下载的应用若被 macOS 拦截，可通过上述源码构建方式运行。

## 许可证

[MIT](LICENSE)
