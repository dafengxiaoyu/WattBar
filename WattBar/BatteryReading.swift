import Foundation

enum BatteryGaugeSource: Equatable, Sendable {
    case smc, registry

    var title: String {
        switch self {
        case .smc: "SMC 电池传感器"
        case .registry: "IOKit 电池快照"
        }
    }
}

struct BatteryGauge: Equatable, Sendable {
    let millivolts: Int
    let milliamps: Int
    let source: BatteryGaugeSource

    var watts: Double {
        Double(millivolts) * Double(milliamps) / 1_000_000
    }
}

struct PowerAdapter: Equatable, Sendable {
    let reportedWatts: Int?
    let name: String?
}

struct BatteryReading: Equatable, Sendable {
    var level: Int?
    var externalConnected: Bool?
    var externalChargeCapable: Bool?
    var isCharging: Bool?
    var isFull: Bool?
    var gauge: BatteryGauge?
    var adapter: PowerAdapter?
    var inputWatts: Double?

    var isWaitingForPower: Bool {
        // The connection flag can update before the current drops after unplugging.
        externalConnected == false && (gauge?.milliamps ?? 0) > 0
    }

    var displayGauge: BatteryGauge? {
        isWaitingForPower ? nil : gauge
    }

    var state: ChargeState {
        if externalConnected == false { return .discharging }
        if isCharging == true { return .charging }
        guard externalConnected == true, isCharging == false else { return .unknown }
        if isFull == true { return .full }
        if externalChargeCapable == true { return .paused }
        return .externalNotCharging
    }
}

enum ChargeState: Equatable {
    case charging, discharging, full, paused, externalNotCharging, unknown

    var title: String {
        switch self {
        case .charging: "正在充电"
        case .discharging: "电池供电"
        case .full: "电池已充满"
        case .paused: "充电暂停"
        case .externalNotCharging: "已接电 · 未充电"
        case .unknown: "充电状态未知"
        }
    }

    var symbol: String {
        switch self {
        case .charging: "bolt.fill"
        case .discharging: "battery.50percent"
        case .full: "battery.100percent"
        case .paused: "pause.circle"
        case .externalNotCharging: "powerplug"
        case .unknown: "questionmark.circle"
        }
    }
}

func powerLabel(_ watts: Double, showPlus: Bool = false) -> String {
    let tenths = (watts * 10).rounded()
    let magnitude = (abs(tenths) / 10).formatted(.number.precision(.fractionLength(1)))
    let sign = tenths < 0 ? "−" : (showPlus && tenths > 0 ? "+" : "")
    return "\(sign)\(magnitude) W"
}
