import Foundation

enum ClassActionID: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case guardAction = "guard"
    case powerStrike
    case mend
}

struct ClassActionState: Codable, Equatable, Sendable {
    let actionID: ClassActionID
    var cooldownRemaining: SimulationDuration
    var guardActive: Bool
}

struct ClassActionDefinition: Equatable, Sendable {
    let id: ClassActionID
    let heroClass: HeroClassID
    let cooldown: SimulationDuration
    let powerBasisPoints: Int64
}

struct ClassActionConfiguration: Sendable {
    static let standard = ClassActionConfiguration(definitions: [
        ClassActionDefinition(
            id: .guardAction,
            heroClass: .tank,
            cooldown: SimulationDuration.seconds(8)!,
            powerBasisPoints: 5_000
        ),
        ClassActionDefinition(
            id: .powerStrike,
            heroClass: .dps,
            cooldown: SimulationDuration.seconds(6)!,
            powerBasisPoints: 25_000
        ),
        ClassActionDefinition(
            id: .mend,
            heroClass: .healer,
            cooldown: SimulationDuration.seconds(10)!,
            powerBasisPoints: 3_500
        ),
    ])

    let definitions: [ClassActionDefinition]

    func definition(for id: ClassActionID) throws -> ClassActionDefinition {
        let matches = definitions.filter { $0.id == id }
        guard matches.count == 1,
              let definition = matches.first,
              definition.cooldown >= .minimumAttackInterval,
              definition.powerBasisPoints > 0 else {
            throw SimulationError.invalidBalance
        }
        return definition
    }

    func action(for heroClass: HeroClassID) -> ClassActionID {
        switch heroClass {
        case .tank: .guardAction
        case .dps: .powerStrike
        case .healer: .mend
        }
    }
}
