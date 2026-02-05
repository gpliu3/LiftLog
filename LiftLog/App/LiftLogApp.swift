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
            fatalError("Could not create ModelContainer: \(error)")
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
            if existingExercises.isEmpty {
                for exercise in Exercise.sampleExercises() {
                    context.insert(exercise)
                }
                try context.save()
            }
        } catch {
            print("Failed to seed exercises: \(error)")
        }
    }
}
