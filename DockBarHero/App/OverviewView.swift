import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    private var presentation: GamePresentation { model.game }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

    private var combatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combat").font(.title2.weight(.semibold))
            HStack(alignment: .top, spacing: 28) {
                statGrid(
                    title: "Hero",
                    values: [
                        ("Health", "\(presentation.state.hero.currentHealth)/\(presentation.state.hero.maxHealth)"),
                        ("Attack", "\(presentation.heroAttack)"),
                        ("Defense", "\(presentation.heroDefense)"),
                        ("Interval", ManagementFormat.interval(presentation.state.hero.attackInterval)),
                    ]
                )
                statGrid(
                    title: "Enemy",
                    values: [
                        ("Health", "\(presentation.state.enemy.currentHealth)/\(presentation.state.enemy.maxHealth)"),
                        ("Attack", "\(presentation.state.enemy.baseAttack)"),
                        ("Defense", "\(presentation.state.enemy.baseDefense)"),
                        ("Interval", ManagementFormat.interval(presentation.state.enemy.attackInterval)),
                        ("Enemy level", "\(presentation.state.encounter.enemyLevel)"),
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
            equipmentRow(for: .weapon)
            equipmentRow(for: .armor)
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

    private func equipmentRow(for slot: EquipmentSlot) -> some View {
        let item = presentation.state.inventory.first { $0.id == presentation.state.equipment[slot] }
        return HStack {
            Text(slot.rawValue.capitalized).frame(width: 80, alignment: .leading)
            if let item {
                Text("Lv. \(item.level)  +\(item.primaryStat)")
            } else {
                Text("None").foregroundStyle(.secondary)
            }
        }
    }
}
