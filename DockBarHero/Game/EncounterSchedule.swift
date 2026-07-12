struct EncounterSchedule: Sendable {
    static let standard = EncounterSchedule()

    func tier(for level: Int) -> EnemyTierID? {
        guard level >= 1 else { return nil }
        if level.isMultiple(of: 25) { return .boss }
        if level.isMultiple(of: 5) { return .elite }
        return .normal
    }
}
