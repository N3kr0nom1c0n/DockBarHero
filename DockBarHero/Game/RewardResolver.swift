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
        guard (1...3).contains(state.party.heroes.count),
              state.party.heroes.allSatisfy({ $0.level >= 1 && $0.currentXP >= 0 }),
              state.economy.gold >= 0 else {
            throw SimulationError.invalidState
        }
        var result = state
        let progression = ProgressionConfiguration.standard
        var events: [GameEvent] = []

        do {
            for slot in result.party.heroes.indices {
                var hero = result.party.heroes[slot]
                let fullXP = try progression.xpReward(
                    enemyLevel: defeatedLevel,
                    heroLevel: hero.level,
                    tier: tier
                )
                let xp = try proportionalXP(
                    fullXP: fullXP,
                    aliveDuration: hero.encounterAliveDuration,
                    encounterDuration: result.encounter.activeElapsed,
                    isAliveAtResolution: hero.combat.currentHealth > 0
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
                if hero.wasDownThisEncounter {
                    hero.consecutiveDeaths = try checkedIncrement(hero.consecutiveDeaths)
                } else {
                    hero.consecutiveDeaths = 0
                }
                result.party.heroes[slot] = hero
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

        var loot = LootSystem(balance: balance)
        let item = try loot.drop(defeatedLevel: defeatedLevel, tier: tier, state: &result)
        events.append(.loot(item))

        if result.autoEquipEnabled {
            let resolver = ItemScoreResolver()
            let candidates = try result.party.heroes.indices.compactMap { slot -> (slot: Int, amount: Int64)? in
                let comparison = try resolver.compare(item: item, heroSlot: slot, in: result)
                guard comparison.isStrictUpgrade else {
                    return nil
                }
                return (slot, comparison.improvement)
            }
            if let selected = candidates.sorted(by: {
                $0.amount != $1.amount ? $0.amount > $1.amount : $0.slot < $1.slot
            }).first {
                result.party.heroes[selected.slot].equipment[item.slot] = item.id
                if result.party.heroes.count == 1 {
                    events.append(.equipped(slot: item.slot, itemID: item.id))
                } else {
                    events.append(.equippedHero(
                        heroSlot: selected.slot,
                        slot: item.slot,
                        itemID: item.id
                    ))
                }
            }
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

    private func proportionalXP(
        fullXP: Int64,
        aliveDuration: SimulationDuration,
        encounterDuration: SimulationDuration,
        isAliveAtResolution: Bool
    ) throws -> Int64 {
        guard aliveDuration >= .zero,
              encounterDuration >= .zero,
              aliveDuration <= encounterDuration else {
            throw SimulationError.invalidState
        }
        if encounterDuration == .zero {
            return isAliveAtResolution ? fullXP : 0
        }
        let (product, overflow) = fullXP.multipliedReportingOverflow(by: aliveDuration.rawValue)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        let proportional = product / encounterDuration.rawValue
        return aliveDuration > .zero ? max(1, proportional) : 0
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
