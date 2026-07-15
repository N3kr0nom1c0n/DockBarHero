enum SimulationError: Error, Equatable {
    case invalidElapsed
    case invalidTimer
    case invalidState
    case invalidBalance
    case arithmeticOverflow
}

enum GameIntentError: Error, Equatable, Sendable {
    case itemNotFound
    case slotMismatch
    case itemInUse
}

struct GameSimulation {
    private(set) var state: GameState
    let balance: BalanceConfiguration
    private let policy: any ActionPolicy
    private let combatResolver: CombatResolver
    private let encounterDirector: EncounterDirector
    private let rewardResolver: RewardResolver
    private let abilityResolver: AbilityResolver
    private var simulationTime: SimulationDuration = .zero
    private var damageMetrics = DamageMetrics()

    init(balance: BalanceConfiguration = .standard, policy: any ActionPolicy = BasicAttackPolicy()) {
        self.state = .newGame(balance: balance)
        self.balance = balance
        self.policy = policy
        self.combatResolver = CombatResolver()
        self.encounterDirector = EncounterDirector()
        self.rewardResolver = RewardResolver()
        self.abilityResolver = AbilityResolver()
    }

    init(state: GameState, balance: BalanceConfiguration = .standard, policy: any ActionPolicy = BasicAttackPolicy()) {
        self.state = state
        self.balance = balance
        self.policy = policy
        self.combatResolver = CombatResolver()
        self.encounterDirector = EncounterDirector()
        self.rewardResolver = RewardResolver()
        self.abilityResolver = AbilityResolver()
    }

    var presentation: GamePresentation {
        let fallbackHero = state.party.heroes.first?.combat
        let campaign = (try? CampaignResolver().resolve(level: state.encounter.enemyLevel))
            .flatMap { resolved -> CampaignPresentation? in
                guard let area = resolved.area, let enemy = resolved.enemy else { return nil }
                return CampaignPresentation(
                    areaID: area.id,
                    areaFullName: area.fullName,
                    areaShortName: area.shortName,
                    enemyID: enemy.id,
                    enemyName: enemy.displayName,
                    enemySpriteID: enemy.spriteID,
                    tier: resolved.tier,
                    level: resolved.level
                )
            }
        return GamePresentation(
            state: state,
            heroAttack: (try? combatResolver.effectiveAttack(for: .hero, in: state)) ?? fallbackHero?.baseAttack ?? 0,
            heroDefense: (try? combatResolver.effectiveDefense(for: .hero, in: state)) ?? fallbackHero?.baseDefense ?? 0,
            rollingDPS: damageMetrics.rollingDPS(
                at: simulationTime,
                encounterElapsed: state.encounter.activeElapsed
            ),
            encounterDPS: DamageMetrics.encounterAverage(
                totalDamage: state.encounter.heroDamage,
                elapsed: state.encounter.activeElapsed
            ),
            heroes: state.party.heroes.indices.map { slot in
                HeroCombatPresentation(
                    slot: slot,
                    attack: (try? combatResolver.effectiveAttack(forHeroAt: slot, in: state))
                        ?? state.party.heroes[slot].combat.baseAttack,
                    defense: (try? combatResolver.effectiveDefense(forHeroAt: slot, in: state))
                        ?? state.party.heroes[slot].combat.baseDefense
                )
            },
            campaign: campaign
        )
    }

    mutating func advance(by elapsed: SimulationDuration) throws -> [GameEvent] {
        guard elapsed >= .zero, elapsed <= .maximumAdvance else {
            throw SimulationError.invalidElapsed
        }

        var candidate = self
        let events = try candidate.advanceCandidate(by: elapsed)
        self = candidate
        return events
    }

    mutating func apply(_ intent: GameIntent) throws -> [GameEvent] {
        var candidate = self
        let events = try candidate.applyCandidate(intent)
        self = candidate
        return events
    }

    private mutating func applyCandidate(_ intent: GameIntent) throws -> [GameEvent] {
        switch intent {
        case let .setAutoEquip(enabled):
            guard state.autoEquipEnabled != enabled else { return [] }
            state.autoEquipEnabled = enabled
            return [.autoEquipChanged(enabled)]

        case let .equip(itemID):
            return try equip(itemID: itemID, heroSlot: 0, legacyEvent: true)

        case let .equipHero(slot, itemID):
            return try equip(itemID: itemID, heroSlot: slot, legacyEvent: false)

        case let .selectLevel(level):
            state = try encounterDirector.queue(level: level, in: state)
            return [.destinationQueued(level)]

        case .returnToFrontier:
            state = try encounterDirector.queueFrontier(in: state)
            return [.destinationQueued(state.campaign.highestUnlockedLevel)]

        case let .castAction(heroSlot, actionID):
            let resolution = try abilityResolver.resolve(
                heroSlot: heroSlot,
                actionID: actionID,
                in: state
            )
            state = resolution.state
            var events = resolution.events
            if resolution.damageDealt > 0 {
                damageMetrics.record(damage: resolution.damageDealt, at: simulationTime)
            }
            if resolution.enemyDefeated {
                try completeVictory(defeatedLevel: state.encounter.enemyLevel, into: &events)
            }
            return events

        case let .setItemLocked(itemID, isLocked):
            let matches = state.inventory.indices.filter { state.inventory[$0].id == itemID }
            guard matches.count == 1, let index = matches.first else {
                throw GameIntentError.itemNotFound
            }
            guard state.inventory[index].rarity != .unique || isLocked else {
                throw SimulationError.invalidState
            }
            guard state.inventory[index].isLocked != isLocked else { return [] }
            state.inventory[index].isLocked = isLocked
            return [.itemLockChanged(itemID: itemID, isLocked: isLocked)]

        case .purchaseInventoryCapacity:
            let purchase = try InventoryResolver().purchaseCapacity(in: state)
            state = purchase.state
            return [.inventoryCapacityPurchased(capacity: purchase.capacity, cost: purchase.cost)]

        case let .moveOverflow(itemID, quantity):
            state = try InventoryResolver().moveOverflow(
                itemID: itemID,
                quantity: quantity,
                in: state
            )
            return [.overflowMoved(itemID: itemID, quantity: quantity)]

        case let .salvage(selections):
            let result = try SalvageResolver().salvage(selections, in: state)
            state = result.state
            return [.itemsSalvaged(quantity: result.quantity, gold: result.goldGranted)]
        }
    }

    private mutating func equip(
        itemID: ItemID,
        heroSlot: Int,
        legacyEvent: Bool
    ) throws -> [GameEvent] {
        guard state.party.heroes.indices.contains(heroSlot) else {
            throw GameIntentError.slotMismatch
        }
        let matchingIndices = state.inventory.indices.filter { state.inventory[$0].id == itemID }
        guard matchingIndices.count == 1, let itemIndex = matchingIndices.first else {
            if matchingIndices.count > 1 { throw GameIntentError.slotMismatch }
            throw GameIntentError.itemNotFound
        }
        var item = state.inventory[itemIndex]
        guard item.level >= 1, item.primaryStat >= 0 else {
            throw GameIntentError.slotMismatch
        }
        let isUsedByAnotherHero = state.party.heroes.indices.contains { slot in
            slot != heroSlot && EquipmentSlot.allCases.contains {
                state.party.heroes[slot].equipment[$0] == itemID
            }
        }
        guard !isUsedByAnotherHero else { throw GameIntentError.itemInUse }
        let extraction = try InventoryResolver().extractOne(itemID: item.id, from: state)
        state = extraction.state
        item = extraction.item
        let priorStats = try ItemStatResolver().stats(heroSlot: heroSlot, in: state)
        state.party.heroes[heroSlot].equipment[item.slot] = item.id
        state = try InventoryResolver().consolidateUnequippedStacks(in: state)
        guard state.inventory.count <= (try InventoryResolver().capacity(for: state)) else {
            throw SimulationError.invalidState
        }
        let nextStats = try ItemStatResolver().stats(heroSlot: heroSlot, in: state)
        let priorHealth = state.party.heroes[heroSlot].combat.currentHealth
        let (missingHealth, missingOverflow) = priorStats.maximumHealth.subtractingReportingOverflow(priorHealth)
        guard !missingOverflow else { throw SimulationError.arithmeticOverflow }
        state.party.heroes[heroSlot].combat.maxHealth = nextStats.maximumHealth
        if priorHealth == 0 {
            state.party.heroes[heroSlot].combat.currentHealth = 0
        } else {
            let (adjusted, adjustedOverflow) = nextStats.maximumHealth.subtractingReportingOverflow(missingHealth)
            guard !adjustedOverflow else { throw SimulationError.arithmeticOverflow }
            state.party.heroes[heroSlot].combat.currentHealth = max(1, min(nextStats.maximumHealth, adjusted))
        }
        state.party.heroes[heroSlot].combat.timeUntilNextAttack = min(
            state.party.heroes[heroSlot].combat.timeUntilNextAttack,
            nextStats.attackInterval
        )
        if legacyEvent, state.party.heroes.count == 1 {
            return [.equipped(slot: item.slot, itemID: item.id)]
        }
        return [.equippedHero(heroSlot: heroSlot, slot: item.slot, itemID: item.id)]
    }

    private mutating func advanceCandidate(by elapsed: SimulationDuration) throws -> [GameEvent] {
        try validateStateAndBalance()

        var remaining = elapsed
        var events: [GameEvent] = []

        while true {
            switch state.encounter.phase {
            case .active:
                guard let nextHeroAction = state.party.heroes
                    .filter({ $0.combat.currentHealth > 0 })
                    .map({ $0.combat.timeUntilNextAttack })
                    .min() else {
                    throw SimulationError.invalidState
                }
                let step = min(remaining, nextHeroAction, state.enemy.timeUntilNextAttack)
                if step > .zero {
                    try consumeActiveTime(step, into: &events)
                    remaining = try subtracting(step, from: remaining)
                }

                let readyHeroSlots = state.party.heroes.indices.filter {
                    state.party.heroes[$0].combat.currentHealth > 0 &&
                    state.party.heroes[$0].combat.timeUntilNextAttack == .zero
                }
                let enemyReady = state.enemy.timeUntilNextAttack == .zero
                guard !readyHeroSlots.isEmpty || enemyReady else { return events }

                var heroWon = false
                for slot in readyHeroSlots {
                    heroWon = try resolveHeroAction(slot: slot, into: &events)
                    if heroWon { break }
                }

                if enemyReady, !heroWon, state.encounter.phase == .active {
                    try resolveEnemyAction(into: &events)
                }

            case .reviving:
                let step = min(remaining, state.encounter.reviveRemaining)
                if step > .zero {
                    state.encounter.reviveRemaining = try subtracting(step, from: state.encounter.reviveRemaining)
                    simulationTime = try adding(step, to: simulationTime)
                    remaining = try subtracting(step, from: remaining)
                }

                guard state.encounter.reviveRemaining == .zero else { return events }
                let enemyLevel = state.encounter.enemyLevel
                let priorCampaign = state.campaign
                state = try encounterDirector.finishRevive(in: state, balance: balance)
                damageMetrics.reset()
                events.append(.revived(enemyLevel: enemyLevel))
                appendCampaignTransition(from: priorCampaign, into: &events)
            case .awaitingPartyChoice:
                return events
            }

            if remaining == .zero {
                let hasReadyActor = state.encounter.phase == .active &&
                    (state.party.heroes.contains(where: {
                        $0.combat.currentHealth > 0 && $0.combat.timeUntilNextAttack == .zero
                    }) || state.enemy.timeUntilNextAttack == .zero)
                let reviveIsDue = state.encounter.phase == .reviving && state.encounter.reviveRemaining == .zero
                if !hasReadyActor && !reviveIsDue {
                    return events
                }
            }
        }
    }

    private mutating func resolveHeroAction(slot: Int, into events: inout [GameEvent]) throws -> Bool {
        switch policy.action(for: .hero, in: state) {
        case .basicAttack:
            let attack = try combatResolver.effectiveAttack(forHeroAt: slot, in: state)
            let (difference, overflow) = attack.subtractingReportingOverflow(state.enemy.baseDefense)
            guard !overflow else { throw SimulationError.arithmeticOverflow }
            let damage = max(1, difference)
            let enemyHealth = try combatResolver.health(afterTaking: damage, from: state.enemy.currentHealth)
            let (actualDamage, damageOverflow) = state.enemy.currentHealth.subtractingReportingOverflow(enemyHealth)
            guard !damageOverflow else { throw SimulationError.arithmeticOverflow }
            let heroDamage = try adding(actualDamage, to: state.encounter.heroDamage)
            state.enemy.currentHealth = enemyHealth
            state.party.heroes[slot].combat.timeUntilNextAttack = try ItemStatResolver()
                .stats(heroSlot: slot, in: state)
                .attackInterval
            state.encounter.heroDamage = heroDamage
            damageMetrics.record(damage: actualDamage, at: simulationTime)
            if state.party.heroes.count == 1 {
                events.append(.attack(attacker: .hero, defender: .enemy, damage: damage))
            } else {
                events.append(.heroAttack(slot: slot, damage: damage))
            }

            guard state.enemy.currentHealth == 0 else { return false }
            try completeVictory(defeatedLevel: state.encounter.enemyLevel, into: &events)
            return true
        }
    }

    private mutating func resolveEnemyAction(into events: inout [GameEvent]) throws {
        switch policy.action(for: .enemy, in: state) {
        case .basicAttack:
            let guardSlot = state.party.heroes.firstIndex(where: {
                $0.combat.currentHealth > 0 && $0.classAction.guardActive
            })
            guard let targetSlot = guardSlot ?? state.party.heroes.firstIndex(where: {
                $0.combat.currentHealth > 0
            }) else {
                throw SimulationError.invalidState
            }
            let normalDamage = try combatResolver.enemyDamage(
                targetingHeroAt: targetSlot,
                in: state,
                tier: state.encounter.tier
            )
            let damage: Int
            if guardSlot != nil {
                let definition = try ClassActionConfiguration.standard.definition(for: .guardAction)
                let scaled: Int64
                do {
                    scaled = try ProgressionConfiguration.standard.applying(
                        Ratio(numerator: definition.powerBasisPoints, denominator: 10_000),
                        to: Int64(normalDamage),
                        rounding: .down
                    )
                } catch {
                    throw SimulationError.arithmeticOverflow
                }
                guard scaled <= Int64(Int.max) else { throw SimulationError.arithmeticOverflow }
                damage = max(1, Int(scaled))
                state.party.heroes[targetSlot].classAction.guardActive = false
            } else {
                damage = normalDamage
            }
            let heroHealth = try combatResolver.health(
                afterTaking: damage,
                from: state.party.heroes[targetSlot].combat.currentHealth
            )
            state.party.heroes[targetSlot].combat.currentHealth = heroHealth
            state.enemy.timeUntilNextAttack = state.enemy.attackInterval
            if guardSlot != nil {
                events.append(.guardIntercepted(heroSlot: targetSlot, damage: damage))
            }
            if state.party.heroes.count == 1 {
                events.append(.attack(attacker: .enemy, defender: .hero, damage: damage))
            } else {
                events.append(.enemyAttack(targetSlot: targetSlot, damage: damage))
            }

            guard heroHealth == 0 else { return }
            state.party.heroes[targetSlot].wasDownThisEncounter = true
            if state.party.heroes.count > 1 {
                events.append(.heroDown(slot: targetSlot))
            }
            guard !state.party.heroes.contains(where: { $0.combat.currentHealth > 0 }) else { return }
            let enemyLevel = state.encounter.enemyLevel
            events.append(.defeat(enemyLevel: enemyLevel))
            state = try encounterDirector.beginDefeat(in: state, balance: balance)
            for slot in state.party.heroes.indices {
                state.party.heroes[slot].classAction.guardActive = false
            }
            damageMetrics.reset()
        }
    }

    private mutating func completeVictory(
        defeatedLevel: Int,
        into events: inout [GameEvent]
    ) throws {
        events.append(.victory(defeatedLevel: defeatedLevel))
        let reward = try rewardResolver.applyVictory(
            defeatedLevel: defeatedLevel,
            to: state,
            balance: balance
        )
        state = reward.state
        events.append(contentsOf: reward.events)
        for slot in state.party.heroes.indices {
            state.party.heroes[slot].classAction.guardActive = false
        }
        if defeatedLevel == 25, state.party.unlocks == .locked {
            state = try PartyUnlockResolver().beginSecondUnlock(
                afterDefeating: defeatedLevel,
                in: state
            )
            events.append(.partyUnlockPending(.boss25))
            damageMetrics.reset()
            return
        }
        state = try PartyUnlockResolver().addFinalHeroIfEarned(
            afterDefeating: defeatedLevel,
            in: state,
            balance: balance
        )
        let priorCampaign = state.campaign
        state = try encounterDirector.completeVictory(in: state, balance: balance)
        appendCampaignTransition(from: priorCampaign, into: &events)
        damageMetrics.reset()
    }

    private mutating func consumeActiveTime(
        _ elapsed: SimulationDuration,
        into events: inout [GameEvent]
    ) throws {
        for slot in state.party.heroes.indices where state.party.heroes[slot].combat.currentHealth > 0 {
            state.party.heroes[slot].combat.timeUntilNextAttack = try subtracting(
                elapsed,
                from: state.party.heroes[slot].combat.timeUntilNextAttack
            )
            state.party.heroes[slot].encounterAliveDuration = try adding(
                elapsed,
                to: state.party.heroes[slot].encounterAliveDuration
            )
            let priorCooldown = state.party.heroes[slot].classAction.cooldownRemaining
            let cooldownStep = min(elapsed, priorCooldown)
            state.party.heroes[slot].classAction.cooldownRemaining = try subtracting(
                cooldownStep,
                from: priorCooldown
            )
            if priorCooldown > .zero,
               state.party.heroes[slot].classAction.cooldownRemaining == .zero {
                events.append(.classActionReady(
                    heroSlot: slot,
                    actionID: state.party.heroes[slot].classAction.actionID
                ))
            }
        }
        state.enemy.timeUntilNextAttack = try subtracting(elapsed, from: state.enemy.timeUntilNextAttack)
        state.encounter.activeElapsed = try adding(elapsed, to: state.encounter.activeElapsed)
        simulationTime = try adding(elapsed, to: simulationTime)
    }

    private func validateStateAndBalance() throws {
        try validateBalance()
        guard (1...3).contains(state.party.heroes.count),
              Set(state.party.heroes.map(\.classID)).count == state.party.heroes.count else {
            throw SimulationError.invalidState
        }
        guard let resolved = try? CampaignResolver().resolve(level: state.encounter.enemyLevel),
              resolved.tier == state.encounter.tier else {
            throw SimulationError.invalidState
        }
        guard state.campaign.highestUnlockedLevel >= 1,
              state.campaign.selectedLevel >= 1,
              state.campaign.selectedLevel <= state.campaign.highestUnlockedLevel,
              state.campaign.consecutiveDefeats >= 0,
              state.campaign.mode != .push ||
                  state.campaign.selectedLevel == state.campaign.highestUnlockedLevel,
              state.encounter.enemyLevel == state.campaign.selectedLevel,
              state.campaign.queuedLevel.map({
                  $0 >= 1 && $0 <= state.campaign.highestUnlockedLevel
              }) ?? true else {
            throw SimulationError.invalidState
        }
        for hero in state.party.heroes {
            try validateCombatant(hero.combat, expectedID: .hero)
            let actionConfiguration = ClassActionConfiguration.standard
            guard let definition = try? actionConfiguration.definition(for: hero.classAction.actionID),
                  hero.classAction.actionID == actionConfiguration.action(for: hero.classID),
                  definition.heroClass == hero.classID,
                  hero.classAction.cooldownRemaining >= .zero,
                  hero.classAction.cooldownRemaining <= definition.cooldown,
                  !hero.classAction.guardActive || (
                      hero.classID == .tank &&
                      hero.combat.currentHealth > 0 &&
                      state.encounter.phase == .active
                  ) else {
                throw SimulationError.invalidState
            }
        }
        try validateCombatant(state.enemy, expectedID: .enemy)

        guard state.encounter.enemyLevel >= 1,
              state.encounter.heroDamage >= 0 else {
            throw SimulationError.invalidState
        }

        switch state.encounter.phase {
        case .active:
            guard state.party.heroes.contains(where: { $0.combat.currentHealth > 0 }),
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining == .zero else {
                throw SimulationError.invalidState
            }
        case .reviving:
            guard state.party.heroes.allSatisfy({ $0.combat.currentHealth == 0 }),
                  state.enemy.currentHealth > 0,
                  state.encounter.reviveRemaining <= balance.reviveDelay else {
                throw SimulationError.invalidState
            }
        case .awaitingPartyChoice:
            guard state.party.unlocks.pendingUnlock != nil,
                  state.enemy.currentHealth == 0,
                  state.encounter.reviveRemaining == .zero else {
                throw SimulationError.invalidState
            }
        }

        for slot in state.party.heroes.indices {
            _ = try combatResolver.effectiveAttack(forHeroAt: slot, in: state)
            _ = try combatResolver.effectiveDefense(forHeroAt: slot, in: state)
        }
        try validateEnemyScaling()
        try validateTimerState()
    }

    private func validateBalance() throws {
        guard balance.heroMaxHealth > 0,
              balance.heroBaseAttack >= 0,
              balance.heroBaseDefense >= 0,
              balance.enemyBaseHealth > 0,
              balance.enemyBaseAttack >= 0,
              balance.enemyBaseDefense >= 0,
              balance.heroAttackInterval >= .minimumAttackInterval,
              balance.enemyAttackInterval >= .minimumAttackInterval,
              balance.reviveDelay >= .zero,
              balance.reviveDelay <= .maximumAdvance else {
            throw SimulationError.invalidBalance
        }
    }

    private func validateCombatant(_ combatant: CombatantState, expectedID: CombatantID) throws {
        guard combatant.id == expectedID,
              combatant.maxHealth > 0,
              combatant.currentHealth >= 0,
              combatant.currentHealth <= combatant.maxHealth,
              combatant.baseAttack >= 0,
              combatant.baseDefense >= 0 else {
            throw SimulationError.invalidState
        }
    }

    private func validateEnemyScaling() throws {
        guard balance.enemy(
            level: state.encounter.enemyLevel,
            tier: state.encounter.tier,
            progression: .standard
        ) != nil else {
            throw SimulationError.invalidBalance
        }
        let (nextLevel, overflow) = state.encounter.enemyLevel.addingReportingOverflow(1)
        guard !overflow,
              let nextResolved = try? CampaignResolver().resolve(level: nextLevel),
              balance.enemy(
                  level: nextLevel,
                  tier: nextResolved.tier,
                  progression: .standard
              ) != nil else {
            throw SimulationError.invalidBalance
        }
    }

    private func validateTimerState() throws {
        let attackIntervals = [
            state.enemy.attackInterval,
            balance.heroAttackInterval,
            balance.enemyAttackInterval
        ] + state.party.heroes.map(\.combat.attackInterval)
        let countdowns = [
            state.enemy.timeUntilNextAttack
        ] + state.party.heroes.map(\.combat.timeUntilNextAttack)

        guard attackIntervals.allSatisfy({ $0 >= .minimumAttackInterval }),
              countdowns.allSatisfy({ $0 >= .zero }),
              state.encounter.activeElapsed >= .zero,
              state.encounter.reviveRemaining >= .zero,
              state.encounter.reviveRemaining <= .maximumAdvance else {
            throw SimulationError.invalidTimer
        }
    }

    private func adding(_ amount: SimulationDuration, to value: SimulationDuration) throws -> SimulationDuration {
        let (rawValue, overflow) = value.rawValue.addingReportingOverflow(amount.rawValue)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return SimulationDuration(rawValue: rawValue)
    }

    private func subtracting(_ amount: SimulationDuration, from value: SimulationDuration) throws -> SimulationDuration {
        let (rawValue, overflow) = value.rawValue.subtractingReportingOverflow(amount.rawValue)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return SimulationDuration(rawValue: rawValue)
    }

    private func adding(_ amount: Int, to value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(amount)
        guard !overflow else { throw SimulationError.arithmeticOverflow }
        return result
    }

    private func appendCampaignTransition(
        from prior: CampaignState,
        into events: inout [GameEvent]
    ) {
        let isAutomaticRetreat = prior.consecutiveDefeats >= 3 && state.campaign.mode == .farming
        guard prior.queuedLevel != nil || isAutomaticRetreat else { return }
        guard state.campaign.selectedLevel != prior.selectedLevel ||
                state.campaign.mode != prior.mode else { return }
        switch state.campaign.mode {
        case .farming:
            events.append(.farmingStarted(state.campaign.selectedLevel))
        case .push:
            events.append(.returnedToFrontier(state.campaign.selectedLevel))
        }
    }

}
