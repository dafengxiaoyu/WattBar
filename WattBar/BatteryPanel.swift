import AppKit
import SwiftUI

struct BatteryPanel: View {
    @ObservedObject var monitor: BatteryMonitor
    @ObservedObject var loginItem: LoginItem
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            headline

            if let level = monitor.reading?.level {
                ProgressView(value: Double(level), total: 100)
                    .tint(.accentColor)
                    .accessibilityLabel("电池电量")
                    .accessibilityValue("\(level)%")
            }

            Divider()

            VStack(spacing: 8) {
                detailRow("电池电量", monitor.reading?.level.map { "\($0)%" } ?? "—")
                detailRow(
                    "Mac 直流输入",
                    monitor.reading?.inputWatts.map { powerLabel($0) }
                        ?? (monitor.reading?.externalConnected == false ? "未接电" : "不可用")
                )
                adapterSection
            }
            TimelineView(.periodic(from: .now, by: Double(monitor.interval.rawValue))) { _ in
                samplingNote
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.setEnabled)) {
                    Label("开机启动", systemImage: "power")
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                if loginItem.requiresApproval {
                    Button("在系统设置中允许开机启动", action: loginItem.openLoginItems)
                        .buttonStyle(.link)
                        .font(.caption)
                }
                if let error = loginItem.error {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button {
                        openSettings()
                        NSApp.activate()
                    } label: {
                        Label("设置…", systemImage: "gearshape")
                    }
                    .keyboardShortcut(",", modifiers: .command)

                    Spacer()

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("退出", systemImage: "xmark.circle")
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 310)
        .onAppear(perform: loginItem.refresh)
    }

    private var headline: some View {
        let sample = monitor.reading
        let state = sample?.state ?? .unknown
        let gauge = sample?.displayGauge
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("电池净功率")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(gauge.map { powerLabel($0.watts, showPlus: true) } ?? "—")
                    .font(.system(size: 29, weight: .semibold))
                    .monospacedDigit()
                    .accessibilityLabel(gauge.map { powerLabel($0.watts, showPlus: true) } ?? "电池净功率不可用")

                Label(sample == nil ? "正在读取电池…" : state.title, systemImage: state.symbol)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: gauge == nil ? "bolt.slash" : state.symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(gauge != nil && state == .charging ? Color.accentColor : .secondary)
                .accessibilityHidden(true)
        }
    }

    private var adapterSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let adapter = monitor.reading?.adapter {
                detailRow("适配器额定功率", adapter.reportedWatts.map { "\($0) W" } ?? "不可用")
                if let name = adapter.name, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                detailRow("电源适配器", monitor.reading?.externalConnected == false ? "未连接" : "信息不可用")
            }
        }
    }

    private var samplingNote: some View {
        let interval = monitor.interval.rawValue
        let note: String
        if monitor.reading == nil {
            note = "正在等待首次采样。"
        } else if monitor.reading?.isWaitingForPower == true {
            note = "电源已断开，等待系统更新电池电流。"
        } else if monitor.reading?.displayGauge == nil {
            note = "电池电压或电流不可用。每 \(interval) 秒重试。"
        } else if let source = monitor.reading?.displayGauge?.source {
            let seconds = monitor.unchangedSeconds
            if seconds >= 5 {
                note = "\(source.title) · 每 \(interval) 秒读取 · 电压和电流已 \(seconds) 秒未变化。"
            } else if source == .registry {
                note = "IOKit 电池快照 · 每 \(interval) 秒读取。底层更新可能更慢。"
            } else {
                note = "SMC 电池传感器 · 每 \(interval) 秒读取。"
            }
        } else {
            note = "电池净功率不可用。"
        }
        return Label(note, systemImage: "clock")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
        } label: {
            Text(title).foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}
