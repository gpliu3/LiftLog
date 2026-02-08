import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
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
            // Migration failed — delete the old store and recreate
            let url = modelConfiguration.url
            print("ModelContainer migration failed, deleting store at \(url): \(error)")
            try? FileManager.default.removeItem(at: url)
            // Also remove journal/wal files
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
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

        do {
            let existingExercises = try context.fetch(descriptor)
            let existingNames = Set(existingExercises.map { $0.name })

            var changed = false
            for exercise in Exercise.sampleExercises() {
                if !existingNames.contains(exercise.name) {
                    context.insert(exercise)
                    changed = true
                }
            }

            // Update existing Plank to timeOnly if it's still weightReps
            if let plank = existingExercises.first(where: { $0.name == "Plank" }),
               plank.exerciseType == "weightReps" {
                plank.exerciseType = "timeOnly"
                changed = true
            }

            if changed {
                try context.save()
            }
        } catch {
            print("Failed to seed exercises: \(error)")
        }
    }
}
