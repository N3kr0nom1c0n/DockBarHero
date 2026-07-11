struct DamageMetrics {
    private struct Sample {
        let timestamp: SimulationDuration
        let damage: Int
    }

    private static let rollingWindow = SimulationDuration.nanoseconds(5_000_000_000)
    private var samples: [Sample] = []

    mutating func record(damage: Int, at timestamp: SimulationDuration) {
        guard damage > 0 else { return }

        let windowStart = lowerBound(for: timestamp)
        samples.removeAll { $0.timestamp <= windowStart }

        let sample = Sample(timestamp: timestamp, damage: damage)
        if samples.last.map({ $0.timestamp <= timestamp }) ?? true {
            samples.append(sample)
        } else {
            let insertionIndex = samples.firstIndex { $0.timestamp > timestamp } ?? samples.endIndex
            samples.insert(sample, at: insertionIndex)
        }
    }

    func rollingDPS(at now: SimulationDuration, encounterElapsed: SimulationDuration) -> Double {
        guard encounterElapsed > .zero else { return 0 }

        let windowStart = lowerBound(for: now)
        let damage = samples
            .filter { $0.timestamp > windowStart && $0.timestamp <= now }
            .reduce(0) { $0 + $1.damage }
        let denominator = min(Self.rollingWindow.rawValue, encounterElapsed.rawValue)
        guard denominator > 0 else { return 0 }

        return Double(damage) / (Double(denominator) / 1_000_000_000)
    }

    static func encounterAverage(totalDamage: Int, elapsed: SimulationDuration) -> Double {
        guard totalDamage > 0, elapsed > .zero else { return 0 }
        return Double(totalDamage) / (Double(elapsed.rawValue) / 1_000_000_000)
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    private func lowerBound(for timestamp: SimulationDuration) -> SimulationDuration {
        let (rawValue, overflow) = timestamp.rawValue.subtractingReportingOverflow(Self.rollingWindow.rawValue)
        return SimulationDuration(rawValue: overflow ? Int64.min : rawValue)
    }
}
