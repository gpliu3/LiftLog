import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var notes: String
    var muscleGroup: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var workoutSets: [WorkoutSet] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        muscleGroup: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.muscleGroup = muscleGroup
        self.createdAt = createdAt
    }

    var timesPerformed: Int {
        let uniqueDates = Set(workoutSets.map { Calendar.current.startOfDay(for: $0.date) })
        return uniqueDates.count
    }

    var lastWeight: Double? {
        workoutSets
            .sorted { $0.createdAt > $1.createdAt }
            .first?.weightKg
    }

    var localizedMuscleGroup: String {
        guard !muscleGroup.isEmpty else { return "" }
        return Exercise.localizedMuscleGroupName(for: muscleGroup)
    }
}

extension Exercise {
    static let muscleGroups = [
        "Chest",
        "Back",
        "Shoulders",
        "Arms",
        "Legs",
        "Core",
        "Other"
    ]

    static func localizedMuscleGroupName(for group: String) -> String {
        switch group {
        case "Chest": return "muscle.chest".localized
        case "Back": return "muscle.back".localized
        case "Shoulders": return "muscle.shoulders".localized
        case "Arms": return "muscle.arms".localized
        case "Legs": return "muscle.legs".localized
        case "Core": return "muscle.core".localized
        case "Other": return "muscle.other".localized
        default: return group
        }
    }

    static var localizedMuscleGroups: [(key: String, display: String)] {
        muscleGroups.map { ($0, localizedMuscleGroupName(for: $0)) }
    }

    static func sampleExercises() -> [Exercise] {
        [
            Exercise(name: "Bench Press", muscleGroup: "Chest"),
            Exercise(name: "Squat", muscleGroup: "Legs"),
            Exercise(name: "Deadlift", muscleGroup: "Back"),
            Exercise(name: "Overhead Press", muscleGroup: "Shoulders"),
            Exercise(name: "Barbell Row", muscleGroup: "Back"),
            Exercise(name: "Pull-ups", muscleGroup: "Back"),
            Exercise(name: "Dumbbell Curl", muscleGroup: "Arms"),
            Exercise(name: "Tricep Pushdown", muscleGroup: "Arms")
        ]
    }
}
