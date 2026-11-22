import AppKit
import SwiftUI

struct WattBarSettings: View {
    @ObservedObject var monitor: BatteryMonitor
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        Form {
            Section {
                Picker("读取间隔", selection: $monitor.interval) {
                    ForEach(PollingInterval.allCases, id: \.self) { interval in
                        Text("\(interval.rawValue) 秒").tag(interval)
                    }
                }
                .pickerStyle(.segmented)

                Text("此设置控制 WattBar 的读取间隔。底层电池数据可能在多个读取周期内保持不变。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("开机启动", isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.setEnabled))
                Text("登录 macOS 后自动打开 WattBar。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if loginItem.requiresApproval {
                    Button("打开系统登录项设置", action: loginItem.openLoginItems)
                }
                if let error = loginItem.error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: loginItem.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }
}
