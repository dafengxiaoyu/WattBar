import CoreFoundation
import Foundation
import IOKit
import IOKit.ps

enum RegistryBattery {
    static func parse(_ fields: [String: Any]) -> BatteryReading {
        let connected = flag(fields["ExternalConnected"])
        guard flag(fields["BatteryInstalled"]) != false else {
            return BatteryReading(externalConnected: connected)
        }

        return BatteryReading(
            level: percentage(current: fields["CurrentCapacity"], maximum: fields["MaxCapacity"]),
            externalConnected: connected,
            externalChargeCapable: flag(fields["ExternalChargeCapable"]),
            isCharging: flag(fields["IsCharging"]),
            isFull: flag(fields["FullyCharged"]),
            gauge: gauge(voltage: fields["Voltage"], amperage: fields["Amperage"])
        )
    }

    static func percentage(current: Any?, maximum: Any?) -> Int? {
        guard let current = integer(current), let maximum = integer(maximum),
              maximum > 0, current >= 0, current <= maximum else { return nil }
        return Int((Double(current) / Double(maximum) * 100).rounded())
    }

    static func flag(_ value: Any?) -> Bool? {
        value as? Bool
    }

    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFNumberGetTypeID(),
              !CFNumberIsFloatType(unsafeBitCast(number, to: CFNumber.self)) else { return nil }
        return Int(number.int64Value)
    }

    private static func gauge(voltage: Any?, amperage: Any?) -> BatteryGauge? {
        guard let voltage = integer(voltage), (1_000...30_000).contains(voltage),
              let amperage = integer(amperage) else { return nil }

        // IORegistry may print negative current as an unsigned two's-complement value.
        // NSNumber resolves the 64-bit form; also accept an unsigned 32-bit encoding.
        let signed = (Int(Int32.max) + 1...Int(UInt32.max)).contains(amperage)
            ? Int(Int32(bitPattern: UInt32(amperage)))
            : amperage
        guard (-30_000...30_000).contains(signed) else { return nil }
        return BatteryGauge(millivolts: voltage, milliamps: signed, source: .registry)
    }
}

actor BatteryReader {
    private let supportsSMC = WattBarSMCSupportsCurrentMac()
    private var connection: io_connect_t = IO_OBJECT_NULL
    private var reopenAfter: ContinuousClock.Instant?

    deinit {
        if connection != IO_OBJECT_NULL { IOServiceClose(connection) }
    }

    func read() -> BatteryReading {
        autoreleasepool {
            var reading = RegistryBattery.parse(registrySnapshot())
            if reading.level == nil || reading.externalConnected == nil || reading.isCharging == nil {
                applyPowerSourceFallback(to: &reading)
            }
            applySMC(to: &reading)
            if reading.externalConnected != false,
               let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() {
                let details = details as NSDictionary
                let watts = RegistryBattery.integer(details[kIOPSPowerAdapterWattsKey]).flatMap {
                    $0 > 0 ? $0 : nil
                }
                let name = (details["Name"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if watts != nil || name?.isEmpty == false {
                    reading.adapter = PowerAdapter(reportedWatts: watts, name: name)
                }
            }
            return reading
        }
    }

    private func applySMC(to reading: inout BatteryReading) {
        guard supportsSMC else { return }
        let now = ContinuousClock().now
        if connection == IO_OBJECT_NULL {
            if let reopenAfter, now < reopenAfter { return }
            connection = WattBarSMCOpen()
            guard connection != IO_OBJECT_NULL else {
                reopenAfter = now.advanced(by: .seconds(15))
                return
            }
        }

        let smc = WattBarSMCRead(connection)
        if smc.hasBattery {
            let gauge = BatteryGauge(
                millivolts: Int(smc.millivolts),
                milliamps: Int(smc.milliamps),
                source: .smc
            )
            reading.gauge = gauge
        }
        if smc.hasInput, reading.externalConnected == true {
            reading.inputWatts = smc.inputWatts
        }
        if !smc.hasBattery && !smc.hasInput {
            IOServiceClose(connection)
            connection = IO_OBJECT_NULL
            reopenAfter = now.advanced(by: .seconds(15))
        }
    }

    private func registrySnapshot() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return [:] }
        defer { IOObjectRelease(service) }

        var fields: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &fields, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let fields else { return [:] }
        return fields.takeRetainedValue() as NSDictionary as? [String: Any] ?? [:]
    }

    private func applyPowerSourceFallback(to reading: inout BatteryReading) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() else {
                continue
            }
            let fields = description as NSDictionary
            guard fields[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  RegistryBattery.flag(fields[kIOPSIsPresentKey]) != false else { continue }

            reading.level = reading.level ?? RegistryBattery.percentage(
                current: fields[kIOPSCurrentCapacityKey], maximum: fields[kIOPSMaxCapacityKey]
            )
            if reading.externalConnected == nil {
                switch fields[kIOPSPowerSourceStateKey] as? String {
                case kIOPSACPowerValue: reading.externalConnected = true
                case kIOPSBatteryPowerValue: reading.externalConnected = false
                default: break
                }
            }
            reading.isCharging = reading.isCharging ?? RegistryBattery.flag(fields[kIOPSIsChargingKey])
            return
        }
    }
}
