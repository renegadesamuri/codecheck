//
//  DataMigrator.swift
//  CodeCheck
//
//  Phase 3 Optimization: Data Migration
//  Handles one-time migration from UserDefaults to Core Data
//  With backup/restore for safe migration
//

import Foundation

/// Handles migration of data from UserDefaults to Core Data
class DataMigrator {

    /// UserDefaults key to track migration status
    private static let migrationCompletedKey = "coredata_migration_completed_v1"

    /// UserDefaults key for old project data
    private static let oldProjectsKey = "saved_projects"

    /// UserDefaults key for backup data (safety net)
    private static let backupProjectsKey = "saved_projects_backup"

    // MARK: - Migration Check

    /// Check if migration has already been completed
    static var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationCompletedKey)
    }

    /// Check if there's data that needs migration
    static var needsMigration: Bool {
        !isMigrationCompleted && hasLegacyData
    }

    /// Check if legacy UserDefaults data exists
    static var hasLegacyData: Bool {
        UserDefaults.standard.data(forKey: oldProjectsKey) != nil
    }

    /// Check if a backup exists (indicates a previous failed migration)
    static var hasBackup: Bool {
        UserDefaults.standard.data(forKey: backupProjectsKey) != nil
    }

    // MARK: - Backup & Restore

    /// Create a backup of legacy data before migration
    /// Returns true if backup was created or already exists
    private static func createBackup() -> Bool {
        // If backup already exists, don't overwrite (previous migration may have failed)
        if hasBackup {
            print("Backup already exists from previous migration attempt")
            return true
        }

        guard let data = UserDefaults.standard.data(forKey: oldProjectsKey) else {
            print("No legacy data to backup")
            return false
        }

        UserDefaults.standard.set(data, forKey: backupProjectsKey)
        UserDefaults.standard.synchronize()
        print("Created backup of legacy data")
        return true
    }

    /// Restore legacy data from backup (used on migration failure)
    private static func restoreFromBackup() {
        guard let backup = UserDefaults.standard.data(forKey: backupProjectsKey) else {
            print("No backup to restore")
            return
        }

        UserDefaults.standard.set(backup, forKey: oldProjectsKey)
        UserDefaults.standard.synchronize()
        print("Restored legacy data from backup")
    }

    /// Clear backup after successful migration
    private static func clearBackup() {
        UserDefaults.standard.removeObject(forKey: backupProjectsKey)
        UserDefaults.standard.synchronize()
        print("Cleared migration backup")
    }

    // MARK: - Migration

    /// Perform migration if needed
    /// Should be called once on app startup
    @MainActor
    static func migrateIfNeeded() async {
        // Check if previous migration failed and restore backup
        if hasBackup && !isMigrationCompleted {
            print("Previous migration may have failed - restoring from backup")
            restoreFromBackup()
        }

        guard needsMigration else {
            if isMigrationCompleted {
                print("Migration already completed")
                // Clean up any leftover backup
                if hasBackup {
                    clearBackup()
                }
            } else {
                print("No legacy data to migrate")
                markMigrationComplete()
            }
            return
        }

        print("Starting data migration from UserDefaults to Core Data...")

        // Step 1: Create backup before migration
        guard createBackup() else {
            print("Failed to create backup - aborting migration")
            return
        }

        do {
            // Step 2: Perform migration
            try await performMigration()

            // Step 3: Verify migration succeeded
            try verifyMigration()

            // Step 4: Mark complete and cleanup
            markMigrationComplete()
            clearLegacyData()
            clearBackup()
            print("Migration completed successfully")
        } catch {
            print("Migration failed: \(error)")
            // Restore from backup
            restoreFromBackup()
            // Don't mark as complete - will retry on next launch
            print("Data restored from backup - will retry migration on next launch")
        }
    }

    /// Perform the actual migration
    private static func performMigration() async throws {
        // Load legacy projects from UserDefaults
        guard let legacyData = UserDefaults.standard.data(forKey: oldProjectsKey) else {
            throw MigrationError.noDataToMigrate
        }

        let decoder = JSONDecoder()
        let legacyProjects: [Project]

        do {
            legacyProjects = try decoder.decode([Project].self, from: legacyData)
        } catch {
            throw MigrationError.decodingFailed(error)
        }

        print("Found \(legacyProjects.count) projects to migrate")

        // Check if Core Data already has projects (avoid duplicate migration)
        let existingCount = CoreDataManager.shared.projectCount()
        if existingCount > 0 {
            print("Core Data already has \(existingCount) projects - skipping migration")
            return
        }

        // Migrate each project
        for project in legacyProjects {
            CoreDataManager.shared.createProject(from: project)
            print("Migrated project: \(project.name)")
        }
    }

    /// Verify that migration completed successfully
    private static func verifyMigration() throws {
        // Load legacy data to get expected count
        guard let legacyData = UserDefaults.standard.data(forKey: oldProjectsKey),
              let legacyProjects = try? JSONDecoder().decode([Project].self, from: legacyData) else {
            // No legacy data means nothing to verify
            return
        }

        let migratedCount = CoreDataManager.shared.projectCount()

        if migratedCount != legacyProjects.count {
            throw MigrationError.verificationFailed
        }

        print("Verification passed: \(migratedCount) projects migrated")
    }

    /// Mark migration as complete
    private static func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        UserDefaults.standard.synchronize()
    }

    /// Clear legacy UserDefaults data
    private static func clearLegacyData() {
        UserDefaults.standard.removeObject(forKey: oldProjectsKey)
        UserDefaults.standard.synchronize()
        print("Legacy project data cleared from UserDefaults")
    }

    // MARK: - Reset (for testing)

    /// Reset migration status (for testing purposes)
    static func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        UserDefaults.standard.synchronize()
        print("Migration status reset")
    }

    /// Force re-migration (for testing purposes)
    @MainActor
    static func forceMigration() async {
        resetMigration()
        await migrateIfNeeded()
    }

    // MARK: - Rollback

    /// Rollback to UserDefaults (emergency recovery)
    @MainActor
    static func rollbackToUserDefaults() async {
        let projects = CoreDataManager.shared.fetchProjects().toProjects()

        guard !projects.isEmpty else {
            print("No projects to rollback")
            return
        }

        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(projects)
            UserDefaults.standard.set(data, forKey: oldProjectsKey)
            UserDefaults.standard.synchronize()
            print("Rolled back \(projects.count) projects to UserDefaults")
        } catch {
            print("Rollback failed: \(error)")
        }
    }
}

// MARK: - Migration Errors

extension DataMigrator {
    enum MigrationError: LocalizedError {
        case noDataToMigrate
        case decodingFailed(Error)
        case saveFailed(Error)
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .noDataToMigrate:
                return "No legacy data found to migrate"
            case .decodingFailed(let error):
                return "Failed to decode legacy data: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Failed to save to Core Data: \(error.localizedDescription)"
            case .verificationFailed:
                return "Migration verification failed"
            }
        }
    }
}

// MARK: - Migration Status

extension DataMigrator {
    /// Get detailed migration status
    static func getMigrationStatus() -> MigrationStatus {
        MigrationStatus(
            isCompleted: isMigrationCompleted,
            hasLegacyData: hasLegacyData,
            coreDataProjectCount: CoreDataManager.shared.projectCount()
        )
    }

    struct MigrationStatus {
        let isCompleted: Bool
        let hasLegacyData: Bool
        let coreDataProjectCount: Int

        var description: String {
            """
            Migration Status:
            - Completed: \(isCompleted)
            - Legacy Data Exists: \(hasLegacyData)
            - Core Data Projects: \(coreDataProjectCount)
            """
        }
    }
}
