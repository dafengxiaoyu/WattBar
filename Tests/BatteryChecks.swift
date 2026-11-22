import Foundation

@main
struct BatteryChecks {
    static func main() async {
        var fields: [String: Any] = [
            "BatteryInstalled": true, "CurrentCapacity": 90, "MaxCapacity": 100,
            "ExternalConnected": true, "ExternalChargeCapable": true,
            "IsCharging": true, "FullyCharged": false,
            "Voltage": 12_533, "Amperage": 2_210
        ]

        var reading = RegistryBattery.parse(fields)
        precondition(reading.state == .charging && reading.level == 90)
        precondition(abs((reading.displayGauge?.watts ?? 0) - 27.69793) < 0.000001)

        fields["ExternalConnected"] = false
        fields["IsCharging"] = false
        reading = RegistryBattery.parse(fields)
        precondition(reading.state == .discharging && reading.isWaitingForPower)
        precondition(reading.displayGauge == nil)

        fields["Amperage"] = NSNumber(value: UInt64(bitPattern: -1_847))
        reading = RegistryBattery.parse(fields)
        precondition(reading.displayGauge?.milliamps == -1_847)
        fields["Amperage"] = NSNumber(value: UInt32(bitPattern: -2_512))
        precondition(RegistryBattery.parse(fields).displayGauge?.milliamps == -2_512)

        fields["ExternalConnected"] = true
        fields["Amperage"] = 0
        reading = RegistryBattery.parse(fields)
        precondition(reading.state == .paused && reading.displayGauge?.watts == 0)
        fields["FullyCharged"] = true
        precondition(RegistryBattery.parse(fields).state == .full)
        fields["FullyCharged"] = false
        fields["ExternalChargeCapable"] = false
        precondition(RegistryBattery.parse(fields).state == .externalNotCharging)

        fields.removeValue(forKey: "Voltage")
        reading = RegistryBattery.parse(fields)
        precondition(reading.displayGauge == nil && reading.level == 90 && !reading.isWaitingForPower)
        fields["Voltage"] = 65_535
        precondition(RegistryBattery.parse(fields).displayGauge == nil)
        fields["Voltage"] = 12_000
        fields["Amperage"] = 32_767
        precondition(RegistryBattery.parse(fields).displayGauge == nil)
        fields["Amperage"] = true
        precondition(RegistryBattery.parse(fields).displayGauge == nil)
        reading = RegistryBattery.parse([:])
        precondition(reading.state == .unknown && reading.displayGauge == nil)
        print("PASS: current decoding, signed watts, charge states, unplug lag and unavailable data")

        if CommandLine.arguments.contains("--live") {
            let reader = BatteryReader()
            for _ in 0..<5 {
                reading = await reader.read()
                print("LIVE: \(reading)")
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
