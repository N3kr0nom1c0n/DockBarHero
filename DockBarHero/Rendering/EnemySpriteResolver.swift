enum EnemySpriteResolver {
    private static let normal: [SpriteToken] = [
        .goblin, .skeleton, .bandit, .wolf, .orc, .bat, .slime,
        .harpy, .mimic, .ghost, .darkMage, .zombie,
        .elementalSlimeNormal, .plantMonster,
    ]

    private static let elite: [SpriteToken] = [
        .eliteKnight, .dreadSkeleton, .infernalBrute, .frostWraith,
        .poisonNaga, .stormLich, .dragonWhelp, .ancientGolem,
    ]

    private static let boss: [SpriteToken] = [
        .ironrootWarchief, .ossuarySovereign, .embermawColossus, .astralWyrm,
    ]

    static func token(level: Int, tier: EnemyTierID) -> SpriteToken {
        guard level > 0 else { return .enemy }
        switch tier {
        case .normal:
            return normal[(level - 1) % normal.count]
        case .elite:
            return elite[max(0, level / 5 - 1) % elite.count]
        case .boss:
            return boss[max(0, level / 25 - 1) % boss.count]
        }
    }
}
