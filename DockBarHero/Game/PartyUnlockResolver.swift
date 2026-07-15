struct PartyUnlockResolver: Sendable {
    func beginSecondUnlock(afterDefeating level: Int, in state: GameState) throws -> GameState {
        guard level == 25,
              state.encounter.enemyLevel == level,
              state.encounter.tier == .boss,
              state.enemy.currentHealth == 0,
              state.party.heroes.count == 1,
              state.party.unlocks == .locked else {
            throw SimulationError.invalidState
        }

        var result = state
        let currentClass = result.party.heroes[0].classID
        result.party.unlocks = .pendingSecond(PendingPartyUnlock(
            milestone: .boss25,
            choices: HeroClassID.allCases.filter { $0 != currentClass }
        ))
        result.encounter.phase = .awaitingPartyChoice
        result.encounter.reviveRemaining = .zero
        return result
    }

    func completeSecondUnlock(
        classID: HeroClassID,
        in state: GameState,
        balance: BalanceConfiguration
    ) throws -> GameState {
        guard case let .pendingSecond(pending) = state.party.unlocks,
              pending.milestone == .boss25,
              pending.choices.contains(classID),
              state.party.heroes.count == 1,
              state.encounter.phase == .awaitingPartyChoice,
              state.encounter.enemyLevel == 25,
              state.enemy.currentHealth == 0 else {
            throw SimulationError.invalidState
        }

        var result = state
        result.party.heroes.append(try makeHero(
            classID: classID,
            level: try highestHeroLevel(in: result),
            balance: balance
        ))
        try equipStrongestUnusedItems(onHeroAt: result.party.heroes.count - 1, in: &result)
        result.party.unlocks = .secondUnlocked
        result.encounter.phase = .active
        return try EncounterDirector().completeDeferredVictory(in: result, balance: balance)
    }

    func addFinalHeroIfEarned(
        afterDefeating level: Int,
        in state: GameState,
        balance: BalanceConfiguration
    ) throws -> GameState {
        guard level == 100 else { return state }
        if state.party.unlocks == .complete { return state }
        guard state.party.unlocks == .secondUnlocked,
              state.party.heroes.count == 2 else {
            throw SimulationError.invalidState
        }
        let currentClasses = Set(state.party.heroes.map(\.classID))
        guard let missingClass = HeroClassID.allCases.first(where: { !currentClasses.contains($0) }) else {
            throw SimulationError.invalidState
        }

        var result = state
        result.party.heroes.append(try makeHero(
            classID: missingClass,
            level: try highestHeroLevel(in: result),
            balance: balance
        ))
        try equipStrongestUnusedItems(onHeroAt: result.party.heroes.count - 1, in: &result)
        result.party.unlocks = .complete
        return result
    }

    private func highestHeroLevel(in state: GameState) throws -> Int {
        guard let level = state.party.heroes.map(\.level).max(), level >= 1 else {
            throw SimulationError.invalidState
        }
        return level
    }

    private func makeHero(
        classID: HeroClassID,
        level: Int,
        balance: BalanceConfiguration
    ) throws -> HeroState {
        let progression = ProgressionConfiguration.standard
        let definition = progression.classDefinition(for: classID)
        let maximumHealth: Int
        do {
            maximumHealth = try progression.scaledStat(
                raw: definition.baseHealth,
                level: level,
                growthBasisPoints: definition.healthGrowthBasisPoints
            )
        } catch ProgressionError.arithmeticOverflow {
            throw SimulationError.arithmeticOverflow
        } catch {
            throw SimulationError.invalidState
        }
        return HeroState(
            classID: classID,
            level: level,
            currentXP: 0,
            combat: CombatantState(
                id: .hero,
                currentHealth: maximumHealth,
                maxHealth: maximumHealth,
                baseAttack: definition.baseAttack,
                baseDefense: definition.baseDefense,
                attackInterval: balance.heroAttackInterval,
                timeUntilNextAttack: balance.heroAttackInterval
            ),
            equipment: EquipmentState(weaponID: nil, armorID: nil)
        )
    }

    private func equipStrongestUnusedItems(onHeroAt heroSlot: Int, in state: inout GameState) throws {
        guard state.party.heroes.indices.contains(heroSlot) else {
            throw SimulationError.invalidState
        }
        let usedIDs = Set(state.party.heroes.enumerated().flatMap { slot, hero in
            guard slot != heroSlot else { return [ItemID]() }
            return EquipmentSlot.allCases.compactMap { hero.equipment[$0] }
        })
        for equipmentSlot in EquipmentSlot.allCases {
            let candidates = state.inventory
                .filter { $0.slot == equipmentSlot && !usedIDs.contains($0.id) }
            let scored = try candidates.map { item in
                (item: item, score: try ItemScoreResolver().compare(
                    item: item,
                    heroSlot: heroSlot,
                    in: state
                ).candidateScore)
            }
            let selected = scored.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.item.rarity != $1.item.rarity { return $0.item.rarity > $1.item.rarity }
                if $0.item.level != $1.item.level { return $0.item.level > $1.item.level }
                if $0.item.creationSequence != $1.item.creationSequence {
                    return $0.item.creationSequence < $1.item.creationSequence
                }
                return $0.item.id.rawValue < $1.item.id.rawValue
            }.first?.item
            if let selected {
                let extraction = try InventoryResolver().extractOne(itemID: selected.id, from: state)
                state = extraction.state
                state.party.heroes[heroSlot].equipment[equipmentSlot] = extraction.item.id
                state = try InventoryResolver().consolidateUnequippedStacks(in: state)
                guard state.inventory.count <= (try InventoryResolver().capacity(for: state)) else {
                    throw SimulationError.invalidState
                }
            } else {
                state.party.heroes[heroSlot].equipment[equipmentSlot] = nil
            }
        }
    }
}
