enum CombatAction: Equatable, Sendable {
    case basicAttack
}

protocol ActionPolicy: Sendable {
    func action(for combatant: CombatantID, in state: GameState) -> CombatAction
}

struct BasicAttackPolicy: ActionPolicy {
    func action(for combatant: CombatantID, in state: GameState) -> CombatAction {
        .basicAttack
    }
}
