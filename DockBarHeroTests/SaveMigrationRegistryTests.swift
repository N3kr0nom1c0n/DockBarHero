import Foundation
import XCTest
@testable import DockBarHero

final class SaveMigrationRegistryTests: XCTestCase {
    func testCurrentVersionReturnsOriginalDataWithoutMigration() throws {
        let registry = try SaveMigrationRegistry(currentVersion: 1, migrations: [])
        let data = Data(#"{"schemaVersion":1}"#.utf8)

        XCTAssertEqual(try registry.migrateToCurrent(data, from: 1), data)
    }

    func testRegistryAppliesSequentialMigrations() throws {
        let registry = try SaveMigrationRegistry(
            currentVersion: 2,
            migrations: [
                HeaderMigration(sourceVersion: 0, targetVersion: 1),
                HeaderMigration(sourceVersion: 1, targetVersion: 2),
            ]
        )

        let migrated = try registry.migrateToCurrent(
            Data(#"{"schemaVersion":0}"#.utf8),
            from: 0
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: migrated) as? [String: Any])

        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
    }

    func testDuplicateSourceRegistrationIsRejected() {
        XCTAssertThrowsError(
            try SaveMigrationRegistry(
                currentVersion: 2,
                migrations: [
                    HeaderMigration(sourceVersion: 0, targetVersion: 1),
                    HeaderMigration(sourceVersion: 0, targetVersion: 1),
                ]
            )
        ) { error in
            XCTAssertEqual(error as? SaveMigrationError, .duplicateSourceVersion(0))
        }
    }

    func testMigrationMustAdvanceExactlyOneVersion() {
        XCTAssertThrowsError(
            try SaveMigrationRegistry(
                currentVersion: 2,
                migrations: [HeaderMigration(sourceVersion: 0, targetVersion: 2)]
            )
        ) { error in
            XCTAssertEqual(
                error as? SaveMigrationError,
                .invalidStep(source: 0, target: 2)
            )
        }
    }

    func testMissingStepIsReportedDuringMigration() throws {
        let registry = try SaveMigrationRegistry(
            currentVersion: 2,
            migrations: [HeaderMigration(sourceVersion: 0, targetVersion: 1)]
        )

        XCTAssertThrowsError(
            try registry.migrateToCurrent(Data(#"{"schemaVersion":0}"#.utf8), from: 0)
        ) { error in
            XCTAssertEqual(error as? SaveMigrationError, .missingStep(1))
        }
    }
}

private struct HeaderMigration: SaveMigration {
    let sourceVersion: Int
    let targetVersion: Int

    func migrate(_ data: Data) throws -> Data {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["schemaVersion"] = targetVersion
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
