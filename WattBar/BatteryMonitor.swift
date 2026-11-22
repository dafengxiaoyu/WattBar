import Foundation
import Combine

enum PollingInterval: Int, CaseIterable {
    case one = 1
    case two = 2
    case five = 5
}

@MainActor
final class BatteryMonitor: ObservableObject {
    private static let intervalKey = "PollingIntervalSeconds"
    @Published private(set) var reading: BatteryReading?

    @Published var interval: PollingInterval {
        didSet {
            guard interval != oldValue else { return }
            UserDefaults.standard.set(interval.rawValue, forKey: Self.intervalKey)
            start()
        }
    }

    private let reader = BatteryReader()
    private var polling: Task<Void, Never>?
    private var lastChange: ContinuousClock.Instant?
    private var previousPoll: ContinuousClock.Instant?

    init() {
        interval = PollingInterval(rawValue: UserDefaults.standard.integer(forKey: Self.intervalKey)) ?? .two
        start()
    }

    private func start() {
        polling?.cancel()
        let delay = Duration.seconds(interval.rawValue)
        let reader = self.reader
        polling = Task { [weak self] in
            let clock = ContinuousClock()
            while !Task.isCancelled {
                let current = await reader.read()
                guard !Task.isCancelled else { return }
                self?.update(current, at: clock.now)
                do {
                    try await clock.sleep(for: delay, tolerance: .milliseconds(100))
                } catch {
                    return
                }
            }
        }
    }

    var unchangedSeconds: Int {
        guard let lastChange else { return 0 }
        return Int(lastChange.duration(to: ContinuousClock().now).components.seconds)
    }

    private func update(_ current: BatteryReading, at now: ContinuousClock.Instant) {
        let gap = previousPoll.map { $0.duration(to: now) } ?? .zero
        previousPoll = now
        if current.displayGauge == nil {
            lastChange = nil
        } else if lastChange == nil || current.displayGauge != reading?.displayGauge || gap > .seconds(15) {
            lastChange = now
        }
        if reading != current { reading = current }
    }
}
