import AppKit
import SwiftUI

@main
struct WattBarApp: App {
    @NSApplicationDelegateAdaptor(WattBarLifecycle.self) private var lifecycle
    @StateObject private var monitor = BatteryMonitor()
    @StateObject private var loginItem = LoginItem()

    var body: some Scene {
        Window("WattBar", id: "overview") {
            BatteryPanel(monitor: monitor, loginItem: loginItem)
                .fixedSize(horizontal: false, vertical: true)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            BatteryPanel(monitor: monitor, loginItem: loginItem)
        } label: {
            MenuBarLabel(reading: monitor.reading)
        }
        .menuBarExtraStyle(.window)

        Settings {
            WattBarSettings(monitor: monitor, loginItem: loginItem)
        }
    }
}

private final class WattBarLifecycle: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarLabel: View {
    let reading: BatteryReading?

    var body: some View {
        let gauge = reading?.displayGauge
        let value = gauge.map { powerLabel($0.watts) } ?? "—"
        let symbol = gauge == nil ? "bolt.slash" : (reading?.state.symbol ?? "bolt")

        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(value).monospacedDigit()
        }
        .accessibilityLabel(
            gauge == nil ? "WattBar，电池净功率不可用" : "WattBar，电池净功率 \(value)"
        )
    }
}
