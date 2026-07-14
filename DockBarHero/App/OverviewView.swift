import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    private var presentation: GamePresentation { model.game }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressionSection
                combatSection
                dpsSection
                equipmentSection
                Text(ManagementFormat.saveStatus(model.saveStatus))
                    .foregroundStyle(model.saveStatus.isFailure ? Color.red : Color.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Overview")
    }

    private var progressionSection: some View {
        let state = presentation.state
        return VStack(alignment: .leading, spacing: 10) {
            Text("Progression").font(.title2.weight(.semibold))
            if let campaign = presentation.campaign {
                labeledValue("Area", campaign.areaFullName)
            }
            ForEach(Array(state.party.heroes.enumerated()), id: \.offset) { slot, hero in
                let requiredXP = (try? ProgressionConfiguration.standard.xpRequired(for: hero.level)) ?? 0
                let stats = presentation.heroes.first(where: { $0.slot == slot })
                HStack(spacing: 20) {
                    labeledValue("Hero \(slot + 1)", hero.classID.displayName)
                    labeledValue("Level", ManagementFormat.heroLevel(hero.level))
                    labeledValue("XP", "\(hero.currentXP)/\(requiredXP)")
                    labeledValue("Health", hero.combat.currentHealth > 0
                        ? "\(hero.combat.currentHealth)/\(hero.combat.maxHealth)"
                        : "Down")
                    labeledValue("Attack", "\(stats?.attack ?? hero.combat.baseAttack)")
                    labeledValue("Defense", "\(stats?.defense ?? hero.combat.baseDefense)")
                    labeledValue("Deaths", "\(hero.consecutiveDeaths)")
                }
            }
            HStack(spacing: 24) {
                labeledValue(
                    "Enemy",
                    [presentation.campaign?.enemyName, state.encounter.tier.rawValue.capitalized,
                     ManagementFormat.enemyLevel(state.encounter.enemyLevel)]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                )
                labeledValue("Gold", "\(state.economy.gold)")
            }
            HStack(spacing: 16) {
                Text("Frontier: \(state.campaign.highestUnlockedLevel)")
                Text("Selected: \(state.campaign.selectedLevel)")
                Text("Mode: \(state.campaign.mode.rawValue.capitalized)")
                if let queued = state.campaign.queuedLevel {
                    Text("Queued: \(queued)").foregroundStyle(.secondary)
                }
            }
            HStack {
                Menu("Farm Cleared Level") {
                    ForEach(1..<state.campaign.highestUnlockedLevel, id: \.self) { level in
                        Button(ManagementFormat.destination(level: level)) {
                            model.send(ManagementIntent.selectLevel(level))
                        }
                    }
                }
                .disabled(state.campaign.highestUnlockedLevel <= 1)
                Button("Return to Frontier") {
                    model.send(ManagementIntent.returnToFrontier)
                }
                .disabled(state.campaign.mode == .push && state.campaign.queuedLevel == nil)
            }
        }
    }

    private var combatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat").font(.title2.weight(.semibold))
            HStack(alignment: .top, spacing: 28) {
                statGrid(
                    title: "Enemy",
                    values: [
                        ("Health", "\(presentation.state.enemy.currentHealth)/\(presentation.state.enemy.maxHealth)"),
                        ("Attack", "\(presentation.state.enemy.baseAttack)"),
                        ("Defense", "\(presentation.state.enemy.baseDefense)"),
                        ("Interval", ManagementFormat.interval(presentation.state.enemy.attackInterval)),
                        ("Level", ManagementFormat.enemyLevel(presentation.state.encounter.enemyLevel)),
                    ]
                )
            }
        }
    }

    private var dpsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Damage per second").font(.headline)
            HStack(spacing: 32) {
                metric("Rolling", ManagementFormat.dps(presentation.rollingDPS))
                metric("Encounter average", ManagementFormat.dps(presentation.encounterDPS))
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Equipment").font(.headline)
            ForEach(Array(presentation.state.party.heroes.enumerated()), id: \.offset) { slot, hero in
                Text("Hero \(slot + 1) · \(hero.classID.displayName)").font(.subheadline.weight(.semibold))
                equipmentRow(for: .weapon, heroSlot: slot)
                equipmentRow(for: .armor, heroSlot: slot)
            }
        }
    }

    @ViewBuilder
    private func statGrid(title: String, values: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(values, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(.caption).foregroundStyle(.secondary)
                        Text(value)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value) DPS").font(.title3.monospacedDigit())
        }
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit())
        }
    }

    private func equipmentRow(for slot: EquipmentSlot, heroSlot: Int) -> some View {
        let equipment = presentation.state.party.heroes[heroSlot].equipment
        let item = presentation.state.inventory.first { $0.id == equipment[slot] }
        return HStack {
            Text(slot.rawValue.capitalized).frame(width: 80, alignment: .leading)
            if let item {
                Text("\(ManagementFormat.itemLevel(item.level))  +\(item.primaryStat)")
            } else {
                Text("None").foregroundStyle(.secondary)
            }
        }
    }
}
