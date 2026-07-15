import XCTest
@testable import DockBarHero

final class EnemyFactoryTests: XCTestCase {
    func testFactoryAppliesSlimeProfileWithCheckedRounding() throws {
        let resolved = try CampaignResolver().resolve(level: 1)
        let enemy = try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        )

        XCTAssertEqual(enemy.maxHealth, 39)
        XCTAssertEqual(enemy.currentHealth, 39)
        XCTAssertEqual(enemy.baseAttack, 3)
        XCTAssertEqual(enemy.baseDefense, 0)
        XCTAssertEqual(enemy.attackInterval, .nanoseconds(1_950_000_000))
        XCTAssertEqual(enemy.timeUntilNextAttack, enemy.attackInterval)
    }

    func testFactoryAppliesAllAuthoredEliteAndBossProfiles() throws {
        let expected: [(Int, Int, Int, Int, SimulationDuration)] = [
            (5, 68, 4, 3, .nanoseconds(1_650_000_000)),
            (10, 62, 5, 1, .nanoseconds(1_050_000_000)),
            (15, 106, 6, 2, .nanoseconds(1_275_000_000)),
            (20, 205, 7, 4, .nanoseconds(2_250_000_000)),
            (25, 303, 8, 0, .nanoseconds(1_500_000_000)),
        ]

        for (level, health, attack, defense, interval) in expected {
            let resolved = try CampaignResolver().resolve(level: level)
            let enemy = try EnemyFactory().makeEnemy(
                for: resolved,
                balance: .standard,
                progression: .standard
            )
            XCTAssertEqual(enemy.maxHealth, health, "level \(level)")
            XCTAssertEqual(enemy.baseAttack, attack, "level \(level)")
            XCTAssertEqual(enemy.baseDefense, defense, "level \(level)")
            XCTAssertEqual(enemy.attackInterval, interval, "level \(level)")
        }
    }

    func testFactoryLeavesProceduralEnemiesUnchanged() throws {
        for level in [26, 50, 100, 192] {
            let resolved = try CampaignResolver().resolve(level: level)
            let expected = try XCTUnwrap(BalanceConfiguration.standard.enemy(
                level: level,
                tier: resolved.tier,
                progression: .standard
            ))

            XCTAssertEqual(
                try EnemyFactory().makeEnemy(
                    for: resolved,
                    balance: .standard,
                    progression: .standard
                ),
                expected,
                "level \(level)"
            )
        }
    }

    func testFactoryRejectsAttackIntervalBelowMinimum() {
        let resolved = authored(profile: profile(interval: 1))

        XCTAssertThrowsError(try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        ))
    }

    func testFactoryRejectsProfileArithmeticOverflow() {
        let resolved = authored(profile: profile(health: .max))

        XCTAssertThrowsError(try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        )) { error in
            XCTAssertEqual(error as? ProgressionError, .arithmeticOverflow)
        }
    }

    func testFactoryRejectsDefenseOverflow() {
        let balance = BalanceConfiguration(
            heroMaxHealth: 100,
            heroBaseAttack: 10,
            heroBaseDefense: 0,
            heroAttackInterval: .nanoseconds(1_000_000_000),
            enemyBaseHealth: 30,
            enemyBaseAttack: 3,
            enemyBaseDefense: .max,
            enemyAttackInterval: .nanoseconds(1_500_000_000),
            reviveDelay: .nanoseconds(3_000_000_000)
        )
        let resolved = authored(profile: profile(defense: 1))

        XCTAssertThrowsError(try EnemyFactory().makeEnemy(
            for: resolved,
            balance: balance,
            progression: .standard
        ))
    }

    func testFactoryRejectsNonpositiveLevel() {
        let resolved = ResolvedCampaignEncounter(
            level: 0,
            tier: .normal,
            area: nil,
            enemy: nil
        )

        XCTAssertThrowsError(try EnemyFactory().makeEnemy(
            for: resolved,
            balance: .standard,
            progression: .standard
        ))
    }

    private func authored(profile: EnemyStatProfile) -> ResolvedCampaignEncounter {
        ResolvedCampaignEncounter(
            level: 1,
            tier: .normal,
            area: CampaignCatalog.standard.areas[0],
            enemy: EnemyDefinition(
                id: .slime,
                displayName: "Slime",
                tier: .normal,
                spriteID: .slime,
                profile: profile
            )
        )
    }

    private func profile(
        health: Int64 = 10_000,
        attack: Int64 = 10_000,
        defense: Int = 0,
        interval: Int64 = 10_000
    ) -> EnemyStatProfile {
        EnemyStatProfile(
            healthBasisPoints: health,
            attackBasisPoints: attack,
            defenseBonus: defense,
            attackIntervalBasisPoints: interval
        )
    }
}
