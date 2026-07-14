import SwiftUI

struct ClassActionCard: Identifiable, Equatable {
    let id: Int
    let actionID: ClassActionID
    let heroLabel: String
    let title: String
    let effect: String
    let cooldownLabel: String
    let disabledReason: String?

    static func cards(for state: GameState) -> [ClassActionCard] {
        state.party.heroes.enumerated().map { slot, hero in
            let actionID = hero.classAction.actionID
            let definition = try? ClassActionConfiguration.standard.definition(for: actionID)
            return ClassActionCard(
                id: slot,
                actionID: actionID,
                heroLabel: "Hero \(slot + 1) · \(hero.classID.displayName)",
                title: title(for: actionID),
                effect: effect(for: actionID),
                cooldownLabel: "Cooldown \(ManagementFormat.interval(definition?.cooldown ?? .zero))",
                disabledReason: disabledReason(for: hero, actionID: actionID, in: state)
            )
        }
    }

    private static func disabledReason(
        for hero: HeroState,
        actionID: ClassActionID,
        in state: GameState
    ) -> String? {
        guard state.encounter.phase == .active else { return "Encounter inactive" }
        guard hero.combat.currentHealth > 0 else { return "Hero is down" }
        guard hero.classAction.cooldownRemaining == .zero else {
            return "Ready in \(ManagementFormat.interval(hero.classAction.cooldownRemaining))"
        }
        if actionID == .guardAction, hero.classAction.guardActive {
            return "Guard is already active"
        }
        if actionID == .mend,
           !state.party.heroes.contains(where: {
               $0.combat.currentHealth > 0 && $0.combat.currentHealth < $0.combat.maxHealth
           }) {
            return "Everyone is at full health"
        }
        return nil
    }

    private static func title(for actionID: ClassActionID) -> String {
        switch actionID {
        case .guardAction: "Guard"
        case .powerStrike: "Power Strike"
        case .mend: "Mend"
        }
    }

    private static func effect(for actionID: ClassActionID) -> String {
        switch actionID {
        case .guardAction: "Intercept the next enemy attack and take 50% reduced damage."
        case .powerStrike: "Strike immediately for 250% attack."
        case .mend: "Heal the lowest-health living hero for 35% max health."
        }
    }
}

struct ClassActionsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Class Actions")
                    .font(.title2.bold())
                ForEach(ClassActionCard.cards(for: model.game.state)) { card in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(card.heroLabel)
                                .foregroundStyle(.secondary)
                            Text(card.effect)
                            Text(card.cooldownLabel)
                                .font(.caption.monospacedDigit())
                            Button("Cast") {
                                model.send(ManagementIntent.cast(
                                    heroSlot: card.id,
                                    actionID: card.actionID
                                ))
                            }
                            .disabled(card.disabledReason != nil)
                            .accessibilityIdentifier(
                                "class-action-\(card.id)-\(card.actionID.rawValue)"
                            )
                            if let reason = card.disabledReason {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text(card.title)
                            .font(.headline)
                    }
                }
            }
            .padding()
        }
    }
}
