struct VictoryReward: Equatable, Sendable {
    let state: GameState
    let events: [GameEvent]
}

struct RewardResolver: Sendable {
    func applyVictory(
        defeatedLevel: Int,
        to state: GameState,
        balance: BalanceConfiguration
    ) throws -> VictoryReward {
        try applyVictory(
            defeatedLevel: defeatedLevel,
            tier: state.encounter.tier,
            to: state,
            balance: balance
        )
    }

    func applyVictory(
        defeatedLevel: Int,
        tier: EnemyTierID,
        to state: GameState,
        balance: BalanceConfiguration
    ) throws -> VictoryReward {
        guard state.party.heroes.count == 1,
              state.party.heroes[0].level >= 1,
              state.party.heroes[0].currentXP >= 0,
              state.economy.gold >= 0 else {
            throw SimulationError.invalidState
        }
        var result = state
        let progression = ProgressionConfiguration.standard
        var hero = result.party.heroes[0]
        var events: [GameEvent] = []

        do {
            let xp = try progression.xpReward(
                enemyLevel: defeatedLevel,
                heroLevel: hero.level,
                tier: tier
            )
            hero.currentXP = try checkedAdd(hero.currentXP, xp)
            events.append(.xpGained(classID: hero.classID, amount: xp))

            while hero.currentXP >= (try progression.xpRequired(for: hero.level)) {
                let required = try progression.xpRequired(for: hero.level)
                hero.currentXP -= required
                hero.level = try checkedIncrement(hero.level)
                hero.combat = try leveledCombat(for: hero, progression: progression)
                events.append(.heroLeveled(classID: hero.classID, level: hero.level))
            }

            let gold = try progression.goldReward(enemyLevel: defeatedLevel, tier: tier)
            result.economy.gold = try checkedAdd(result.economy.gold, gold)
            events.append(.goldGained(amount: gold))
        } catch let error as SimulationError {
            throw error
        } catch ProgressionError.arithmeticOverflow {
            throw SimulationError.arithmeticOverflow
        } catch {
            throw SimulationError.invalidState
        }

        result.party.heroes[0] = hero
        var loot = LootSystem(balance: balance)
        let item = try loot.drop(defeatedLevel: defeatedLevel, tier: tier, state: &result)
        events.append(.loot(item))

        if result.autoEquipEnabled, try CombatResolver().isStrictUpgrade(item, in: result) {
            result.equipment[item.slot] = item.id
            events.append(.equipped(slot: item.slot, itemID: item.id))
        }

        return VictoryReward(state: result, events: events)
    }

    private func checkedAdd(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return value
    }

    private func checkedIncrement(_ value: Int) throws -> Int {
        let (incremented, overflow) = value.addingReportingOverflow(1)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return incremented
    }

    private func leveledCombat(
        for hero: HeroState,
        progression: ProgressionConfiguration
    ) throws -> CombatantState {
        let definition = progression.classDefinition(for: hero.classID)
        let maxHealth = try progression.scaledStat(
            raw: definition.baseHealth,
            level: hero.level,
            growthBasisPoints: definition.healthGrowthBasisPoints
        )
        return CombatantState(
            id: .hero,
            currentHealth: min(hero.combat.currentHealth, maxHealth),
            maxHealth: maxHealth,
            baseAttack: hero.combat.baseAttack,
            baseDefense: hero.combat.baseDefense,
            attackInterval: hero.combat.attackInterval,
            timeUntilNextAttack: hero.combat.timeUntilNextAttack
        )
    }
}
