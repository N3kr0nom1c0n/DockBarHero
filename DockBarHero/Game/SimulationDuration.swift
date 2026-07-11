import Foundation

struct SimulationDuration: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    let rawValue: Int64

    static let zero = SimulationDuration(rawValue: 0)
    static let minimumAttackInterval = SimulationDuration(rawValue: 1_000_000)
    static let maximumAdvance = SimulationDuration(rawValue: 10_000_000_000)

    static func nanoseconds(_ value: Int64) -> SimulationDuration {
        SimulationDuration(rawValue: value)
    }

    static func milliseconds(_ value: Int64) -> SimulationDuration? {
        multiplied(value, by: 1_000_000)
    }

    static func seconds(_ value: Int64) -> SimulationDuration? {
        multiplied(value, by: 1_000_000_000)
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue) / 1_000_000_000
    }

    static func < (lhs: SimulationDuration, rhs: SimulationDuration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func multiplied(_ value: Int64, by multiplier: Int64) -> SimulationDuration? {
        let (rawValue, overflow) = value.multipliedReportingOverflow(by: multiplier)
        guard !overflow else { return nil }
        return SimulationDuration(rawValue: rawValue)
    }
}
