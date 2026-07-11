import XCTest
@testable import DockBarHero

@MainActor
final class SimulationDriverTests: XCTestCase {
    func testStartPublishesInitialPresentation() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        var presentations: [GamePresentation] = []
        driver.onPresentation = { presentations.append($0) }

        driver.start(startLoop: false)

        XCTAssertEqual(presentations.count, 1)
        XCTAssertEqual(presentations.first?.state, driver.currentState)
    }

    func testLargeClockGapAdvancesOnlyOneSecond() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        driver.start(startLoop: false)

        clock.now = 20_000_000_000
        driver.step(at: clock.now)

        XCTAssertEqual(driver.currentState.enemy.currentHealth, 20)
        XCTAssertEqual(driver.currentState.encounter.activeElapsed, .nanoseconds(1_000_000_000))
    }

    func testPresentationPublishesAtMostEvery250Milliseconds() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        var presentations: [GamePresentation] = []
        driver.onPresentation = { presentations.append($0) }
        driver.start(startLoop: false)

        clock.now += 249_000_000
        driver.step(at: clock.now)
        XCTAssertEqual(presentations.count, 1)

        clock.now += 1_000_000
        driver.step(at: clock.now)
        XCTAssertEqual(presentations.count, 2)
    }

    func testEventsAreDeliveredImmediatelyWithoutWaitingForPresentationThrottle() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        var state = GameState.newGame(balance: .standard)
        state.hero.timeUntilNextAttack = SimulationDuration.zero
        let driver = SimulationDriver(now: { clock.now })
        var presentations: [GamePresentation] = []
        var eventBatches: [[GameEvent]] = []
        driver.onPresentation = { presentations.append($0) }
        driver.onEvents = { eventBatches.append($0) }
        driver.start(startLoop: false)
        driver.replaceState(state)

        driver.step(at: clock.now)

        XCTAssertEqual(presentations.count, 2)
        XCTAssertEqual(eventBatches, [[.attack(attacker: .hero, defender: .enemy, damage: 10)]])
    }

    func testBackwardClockStepIsIgnored() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        driver.start(startLoop: false)

        clock.now += 500_000_000
        driver.step(at: clock.now)
        let stateAfterForwardStep = driver.currentState

        clock.now -= 100_000_000
        driver.step(at: clock.now)

        XCTAssertEqual(driver.currentState, stateAfterForwardStep)

        clock.now += 200_000_000
        driver.step(at: clock.now)
        XCTAssertEqual(driver.currentState.encounter.activeElapsed, .nanoseconds(600_000_000))
    }

    func testReplaceStateResetsTransientPresentationAndTiming() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        var presentations: [GamePresentation] = []
        driver.onPresentation = { presentations.append($0) }
        driver.start(startLoop: false)

        clock.now += 1_000_000_000
        driver.step(at: clock.now)
        XCTAssertGreaterThan(driver.currentState.encounter.heroDamage, 0)

        let restoredState = GameState.newGame(balance: .standard)
        driver.replaceState(restoredState)

        XCTAssertEqual(driver.currentState, restoredState)
        XCTAssertEqual(presentations.last?.rollingDPS, 0)
        XCTAssertEqual(presentations.last?.encounterDPS, 0)

        clock.now += 100_000_000
        driver.step(at: clock.now)
        XCTAssertEqual(driver.currentState.encounter.activeElapsed, .nanoseconds(100_000_000))
    }

    func testStartAndStopAreIdempotent() {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        var presentationCount = 0
        driver.onPresentation = { _ in presentationCount += 1 }

        driver.start(startLoop: false)
        driver.start(startLoop: false)
        driver.stop()
        driver.stop()

        XCTAssertEqual(presentationCount, 1)
    }

    func testSendPublishesIntentEventsAndPresentationImmediately() throws {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        let driver = SimulationDriver(now: { clock.now })
        var presentations: [GamePresentation] = []
        var eventBatches: [[GameEvent]] = []
        driver.onPresentation = { presentations.append($0) }
        driver.onEvents = { eventBatches.append($0) }
        driver.start(startLoop: false)

        try driver.send(.setAutoEquip(false))

        XCTAssertEqual(eventBatches, [[.autoEquipChanged(false)]])
        XCTAssertEqual(presentations.count, 2)
        XCTAssertFalse(driver.currentState.autoEquipEnabled)
        XCTAssertFalse(presentations.last!.state.autoEquipEnabled)
    }

    func testSendEquipForwardsToSimulationAndPublishesImmediately() throws {
        let clock = TestMonotonicClock(now: 10_000_000_000)
        var state = GameState.newGame(balance: .standard)
        let item = Item(id: ItemID(rawValue: 1), level: 1, slot: .weapon, primaryStat: 5, creationSequence: 1)
        state.inventory = [item]
        let driver = SimulationDriver(simulation: GameSimulation(state: state), now: { clock.now })
        var eventBatches: [[GameEvent]] = []
        var presentations: [GamePresentation] = []
        driver.onEvents = { eventBatches.append($0) }
        driver.onPresentation = { presentations.append($0) }
        driver.start(startLoop: false)

        try driver.send(.equip(item.id))

        XCTAssertEqual(eventBatches, [[.equipped(slot: .weapon, itemID: item.id)]])
        XCTAssertEqual(presentations.count, 2)
        XCTAssertEqual(driver.currentState.equipment.weaponID, item.id)
        XCTAssertEqual(presentations.last!.state.equipment.weaponID, item.id)
    }
}

@MainActor
private final class TestMonotonicClock {
    var now: UInt64

    init(now: UInt64) {
        self.now = now
    }
}
