import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    private let initialSeedCompletedKey = "hasCompletedInitialExerciseSeed"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutSet.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Never delete user data on migration/open failure.
            fatalError("Could not create ModelContainer without data loss: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    seedSampleExercisesIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedSampleExercisesIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Exercise>()
        let defaults = UserDefaults.standard

        do {
            let existingExercises = try context.fetch(descriptor)
            let hasCompletedInitialSeed = defaults.bool(forKey: initialSeedCompletedKey)
            var changed = false

            // Seed defaults only once for an empty library.
            // Existing users are marked as seeded and their exercise changes are respected.
            if !hasCompletedInitialSeed {
                if existingExercises.isEmpty {
                    for exercise in Exercise.sampleExercises() {
                        context.insert(exercise)
                        changed = true
                    }
                }
                defaults.set(true, forKey: initialSeedCompletedKey)
            }

            if changed {
                try context.save()
            }

            normalizeSetNumbersIfNeeded(context: context)
        } catch {
            print("Failed to seed exercises: \(error)")
        }
    }

    /// Repair legacy data where set numbers are duplicated/invalid for the same exercise/day.
    private func normalizeSetNumbersIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSet>()
        let calendar = Calendar.current

        do {
            let allSets = try context.fetch(descriptor)
            let grouped = Dictionary(grouping: allSets) { set in
                let day = calendar.startOfDay(for: set.date)
                let exerciseId = set.exercise?.id.uuidString ?? "none"
                return "\(exerciseId)|\(day.timeIntervalSinceReferenceDate)"
            }

            var changed = false

            for (_, sets) in grouped {
                guard sets.count > 1 else { continue }

                let numbers = sets.map { $0.setNumber }
                let hasInvalidNumber = numbers.contains { $0 <= 0 }
                let hasDuplicateNumber = Set(numbers).count != numbers.count

                guard hasInvalidNumber || hasDuplicateNumber else { continue }

                let orderedSets = sets.sorted {
                    if $0.setNumber != $1.setNumber {
                        return $0.setNumber < $1.setNumber
                    }
                    if $0.createdAt != $1.createdAt {
                        return $0.createdAt < $1.createdAt
                    }
                    if $0.date != $1.date {
                        return $0.date < $1.date
                    }
                    return $0.id.uuidString < $1.id.uuidString
                }

                for (index, set) in orderedSets.enumerated() {
                    let expected = index + 1
                    if set.setNumber != expected {
                        set.setNumber = expected
                        changed = true
                    }
                }
            }

            if changed {
                try context.save()
            }
        } catch {
            print("Failed to normalize set numbers: \(error)")
        }
    }
}
