enum ProgressionError: Error, Equatable {
    case invalidLevel
    case invalidRatio
    case arithmeticOverflow
    case missingTier(EnemyTierID)
}

enum IntegerRounding: Equatable, Sendable {
    case down
    case up
}

struct Ratio: Codable, Equatable, Sendable {
    let numerator: Int64
    let denominator: Int64
}

struct HeroClassDefinition: Equatable, Sendable {
    let id: HeroClassID
    let baseHealth: Int
    let baseAttack: Int
    let baseDefense: Int
    let healthGrowthBasisPoints: Int64
    let attackGrowthBasisPoints: Int64
    let defenseGrowthBasisPoints: Int64
}

struct EnemyTierDefinition: Equatable, Sendable {
    let id: EnemyTierID
    let healthRatio: Ratio
    let damageRatio: Ratio
    let xpRatio: Ratio
    let itemStatRatio: Ratio
    let goldRatio: Ratio
}

struct ProgressionConfiguration: Sendable {
    static let standard = ProgressionConfiguration(
        classes: [
            .init(
                id: .tank,
                baseHealth: 130,
                baseAttack: 8,
                baseDefense: 2,
                healthGrowthBasisPoints: 150,
                attackGrowthBasisPoints: 25,
                defenseGrowthBasisPoints: 100
            ),
            .init(
                id: .dps,
                baseHealth: 100,
                baseAttack: 12,
                baseDefense: 0,
                healthGrowthBasisPoints: 75,
                attackGrowthBasisPoints: 125,
                defenseGrowthBasisPoints: 40
            ),
            .init(
                id: .healer,
                baseHealth: 110,
                baseAttack: 9,
                baseDefense: 1,
                healthGrowthBasisPoints: 100,
                attackGrowthBasisPoints: 60,
                defenseGrowthBasisPoints: 75
            ),
        ],
        tiers: [
            .init(
                id: .normal,
                healthRatio: .init(numerator: 1, denominator: 1),
                damageRatio: .init(numerator: 1, denominator: 1),
                xpRatio: .init(numerator: 1, denominator: 1),
                itemStatRatio: .init(numerator: 1, denominator: 1),
                goldRatio: .init(numerator: 1, denominator: 1)
            ),
            .init(
                id: .elite,
                healthRatio: .init(numerator: 7, denominator: 5),
                damageRatio: .init(numerator: 7, denominator: 5),
                xpRatio: .init(numerator: 7, denominator: 4),
                itemStatRatio: .init(numerator: 11, denominator: 10),
                goldRatio: .init(numerator: 3, denominator: 2)
            ),
            .init(
                id: .boss,
                healthRatio: .init(numerator: 5, denominator: 2),
                damageRatio: .init(numerator: 9, denominator: 4),
                xpRatio: .init(numerator: 7, denominator: 2),
                itemStatRatio: .init(numerator: 6, denominator: 5),
                goldRatio: .init(numerator: 2, denominator: 1)
            ),
        ]
    )

    private let classesByID: [HeroClassID: HeroClassDefinition]
    private let tiersByID: [EnemyTierID: EnemyTierDefinition]

    init(classes: [HeroClassDefinition], tiers: [EnemyTierDefinition]) {
        classesByID = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        tiersByID = Dictionary(uniqueKeysWithValues: tiers.map { ($0.id, $0) })
    }

    func classDefinition(for id: HeroClassID) -> HeroClassDefinition? {
        classesByID[id]
    }

    func tierDefinition(for id: EnemyTierID) -> EnemyTierDefinition? {
        tiersByID[id]
    }

    func xpRequired(for heroLevel: Int) throws -> Int64 {
        let level = try positiveInt64(heroLevel)
        return try multiplied(try multiplied(100, level), level)
    }

    func xpReward(
        enemyLevel: Int,
        heroLevel: Int,
        tier: EnemyTierID
    ) throws -> Int64 {
        let enemy = try positiveInt64(enemyLevel)
        let hero = try positiveInt64(heroLevel)
        guard let definition = tierDefinition(for: tier) else {
            throw ProgressionError.missingTier(tier)
        }

        let baseXP = try multiplied(try multiplied(25, enemy), enemy)
        let tierXP = try applying(definition.xpRatio, to: baseXP, rounding: .down)
        let (levelDifference, differenceOverflow) = hero.subtractingReportingOverflow(enemy)
        guard !differenceOverflow else { throw ProgressionError.arithmeticOverflow }
        let (gapOffset, gapOverflow) = levelDifference.subtractingReportingOverflow(5)
        guard !gapOverflow else { throw ProgressionError.arithmeticOverflow }
        let gap = max(gapOffset, 0)
        let penaltyLoss = try multiplied(15, gap)
        let (unclampedPenalty, penaltyOverflow) = Int64(100).subtractingReportingOverflow(penaltyLoss)
        guard !penaltyOverflow else { throw ProgressionError.arithmeticOverflow }
        let penalty = max(25, unclampedPenalty)
        return try applying(.init(numerator: penalty, denominator: 100), to: tierXP, rounding: .down)
    }

    func goldReward(enemyLevel: Int, tier: EnemyTierID) throws -> Int64 {
        let level = try positiveInt64(enemyLevel)
        guard let definition = tierDefinition(for: tier) else {
            throw ProgressionError.missingTier(tier)
        }

        let square = try multiplied(level, level)
        let linear = try multiplied(4, level)
        let baseGold = try added(try added(20, linear), square / 40)
        return try applying(definition.goldRatio, to: baseGold, rounding: .down)
    }

    func scaledStat(
        raw: Int,
        level: Int,
        growthBasisPoints: Int64
    ) throws -> Int {
        guard raw >= 0, level >= 1, growthBasisPoints >= 0 else {
            throw ProgressionError.invalidLevel
        }
        let offset = try positiveOrZeroInt64(level - 1)
        let growth = try multiplied(growthBasisPoints, offset)
        let basisPoints = try added(10_000, growth)
        let scaled = try applying(
            .init(numerator: basisPoints, denominator: 10_000),
            to: Int64(raw),
            rounding: .down
        )
        guard scaled <= Int64(Int.max) else { throw ProgressionError.arithmeticOverflow }
        return Int(scaled)
    }

    func applying(
        _ ratio: Ratio,
        to value: Int64,
        rounding: IntegerRounding
    ) throws -> Int64 {
        guard value >= 0, ratio.numerator >= 0, ratio.denominator > 0 else {
            throw ProgressionError.invalidRatio
        }
        let product = try multiplied(value, ratio.numerator)
        let quotient = product / ratio.denominator
        guard rounding == .up, product % ratio.denominator != 0 else {
            return quotient
        }
        return try added(quotient, 1)
    }

    private func positiveInt64(_ value: Int) throws -> Int64 {
        guard value >= 1 else { throw ProgressionError.invalidLevel }
        return Int64(value)
    }

    private func positiveOrZeroInt64(_ value: Int) throws -> Int64 {
        guard value >= 0 else { throw ProgressionError.invalidLevel }
        return Int64(value)
    }

    private func multiplied(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow else { throw ProgressionError.arithmeticOverflow }
        return value
    }

    private func added(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw ProgressionError.arithmeticOverflow }
        return value
    }
}
