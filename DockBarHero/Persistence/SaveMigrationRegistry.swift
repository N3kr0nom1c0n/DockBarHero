import Foundation

protocol SaveMigration: Sendable {
    var sourceVersion: Int { get }
    var targetVersion: Int { get }
    func migrate(_ data: Data) throws -> Data
}

enum SaveMigrationError: Error, Equatable {
    case duplicateSourceVersion(Int)
    case invalidStep(source: Int, target: Int)
    case missingStep(Int)
}

struct SaveMigrationRegistry: Sendable {
    private let currentVersion: Int
    private let migrationsBySource: [Int: any SaveMigration]

    init(currentVersion: Int, migrations: [any SaveMigration]) throws {
        var migrationsBySource: [Int: any SaveMigration] = [:]

        for migration in migrations {
            let (expectedTarget, overflow) = migration.sourceVersion.addingReportingOverflow(1)
            guard !overflow, migration.targetVersion == expectedTarget else {
                throw SaveMigrationError.invalidStep(
                    source: migration.sourceVersion,
                    target: migration.targetVersion
                )
            }
            guard migrationsBySource[migration.sourceVersion] == nil else {
                throw SaveMigrationError.duplicateSourceVersion(migration.sourceVersion)
            }
            migrationsBySource[migration.sourceVersion] = migration
        }

        self.currentVersion = currentVersion
        self.migrationsBySource = migrationsBySource
    }

    func migrateToCurrent(_ data: Data, from sourceVersion: Int) throws -> Data {
        var data = data
        var version = sourceVersion

        while version < currentVersion {
            guard let migration = migrationsBySource[version] else {
                throw SaveMigrationError.missingStep(version)
            }
            data = try migration.migrate(data)
            version = migration.targetVersion
        }

        return data
    }

    static func empty(currentVersion: Int) -> SaveMigrationRegistry {
        SaveMigrationRegistry(currentVersion: currentVersion, migrationsBySource: [:])
    }

    private init(
        currentVersion: Int,
        migrationsBySource: [Int: any SaveMigration]
    ) {
        self.currentVersion = currentVersion
        self.migrationsBySource = migrationsBySource
    }
}
