import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var notes: String
    var muscleGroup: String
    var exerciseType: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var workoutSets: [WorkoutSet] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        muscleGroup: String = "",
        exerciseType: String = "weightReps",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.muscleGroup = muscleGroup
        self.exerciseType = exerciseType
        self.createdAt = createdAt
    }

    var isWeightReps: Bool { exerciseType == "weightReps" }
    var isRepsOnly: Bool { exerciseType == "repsOnly" }
    var isTimeOnly: Bool { exerciseType == "timeOnly" }

    var localizedExerciseType: String {
        Exercise.localizedExerciseTypeName(for: exerciseType)
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

    var lastTrainedDate: Date? {
        workoutSets.map(\.date).max()
    }

    var localizedMuscleGroup: String {
        guard !muscleGroup.isEmpty else { return "" }
        return Exercise.localizedMuscleGroupName(for: muscleGroup)
    }

    /// Returns localized name for predefined exercises, raw name otherwise
    var displayName: String {
        if let key = Exercise.predefinedExerciseKeys[name] {
            return key.localized
        }
        return name
    }

    /// Returns localized default notes for predefined exercises (if user hasn't set custom notes), otherwise user's notes
    var displayNotes: String {
        if !notes.isEmpty {
            return notes
        }
        if let key = Exercise.predefinedExerciseKeys[name] {
            let notesKey = "\(key).notes"
            let localized = notesKey.localized
            // If localization returns the key itself, there are no notes
            if localized != notesKey {
                return localized
            }
        }
        return ""
    }
}

extension Exercise {
    /// Maps canonical English exercise names to localization keys
    static let predefinedExerciseKeys: [String: String] = [
        "Bench Press": "exercise.benchPress",
        "Squat": "exercise.squat",
        "Deadlift": "exercise.deadlift",
        "Overhead Press": "exercise.overheadPress",
        "Barbell Row": "exercise.barbellRow",
        "Pull-ups": "exercise.pullUps",
        "Dumbbell Curl": "exercise.dumbbellCurl",
        "Tricep Pushdown": "exercise.tricepPushdown",
        "Lat Pulldown": "exercise.latPulldown",
        "Leg Press": "exercise.legPress",
        "Dumbbell Bench Press": "exercise.dumbbellBenchPress",
        "Dumbbell Shoulder Press": "exercise.dumbbellShoulderPress",
        "Romanian Deadlift": "exercise.romanianDeadlift",
        "Leg Curl": "exercise.legCurl",
        "Leg Extension": "exercise.legExtension",
        "Cable Fly": "exercise.cableFly",
        "Face Pull": "exercise.facePull",
        "Lateral Raise": "exercise.lateralRaise",
        "Barbell Curl": "exercise.barbellCurl",
        "Plank": "exercise.plank",
    ]

    static let exerciseTypes = ["weightReps", "repsOnly", "timeOnly"]

    static func localizedExerciseTypeName(for type: String) -> String {
        switch type {
        case "weightReps": return "exerciseType.weightReps".localized
        case "repsOnly": return "exerciseType.repsOnly".localized
        case "timeOnly": return "exerciseType.timeOnly".localized
        default: return type
        }
    }

    static var localizedExerciseTypes: [(key: String, display: String)] {
        exerciseTypes.map { ($0, localizedExerciseTypeName(for: $0)) }
    }

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
            Exercise(name: "Tricep Pushdown", muscleGroup: "Arms"),
            Exercise(name: "Lat Pulldown", muscleGroup: "Back"),
            Exercise(name: "Leg Press", muscleGroup: "Legs"),
            Exercise(name: "Dumbbell Bench Press", muscleGroup: "Chest"),
            Exercise(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders"),
            Exercise(name: "Romanian Deadlift", muscleGroup: "Legs"),
            Exercise(name: "Leg Curl", muscleGroup: "Legs"),
            Exercise(name: "Leg Extension", muscleGroup: "Legs"),
            Exercise(name: "Cable Fly", muscleGroup: "Chest"),
            Exercise(name: "Face Pull", muscleGroup: "Shoulders"),
            Exercise(name: "Lateral Raise", muscleGroup: "Shoulders"),
            Exercise(name: "Barbell Curl", muscleGroup: "Arms"),
            Exercise(name: "Plank", muscleGroup: "Core", exerciseType: "timeOnly"),
        ]
    }
}
