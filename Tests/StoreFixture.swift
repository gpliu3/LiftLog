import Foundation
import SwiftData

enum StoreFixture {
    static func container(at url: URL) throws -> ModelContainer {
        let schema = Schema([Exercise.self, WorkoutSet.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
    }

    static func populate(_ context: ModelContext) throws {
        let squat = Exercise(name: "Squat", notes: "保留旧备注，pain after 2 days", muscleGroup: "Legs")
        squat.category = nil
        squat.isActive = nil
        let plank = Exercise(name: "Plank", muscleGroup: "Core", exerciseType: "timeOnly")
        let pullUps = Exercise(name: "Pull-ups", muscleGroup: "Back", exerciseType: "repsOnly")
        let cardio = Exercise(name: "Swimming", exerciseType: "cardio", category: .cardio)
        let inactive = Exercise(name: "用户停用动作", notes: "不要重新启用", isActive: false)
        inactive.category = "unknown-legacy-category"
        let exercises = [squat, plank, pullUps, cardio, inactive]
        for exercise in exercises { context.insert(exercise) }

        let start = Date(timeIntervalSince1970: 1_780_272_000)
        for index in 0..<611 {
            let exercise = exercises[index % exercises.count]
            let day = Calendar.current.date(byAdding: .day, value: index / 7, to: start)!
            let set = WorkoutSet(
                exercise: exercise, date: day, weightKg: exercise.isWeightReps ? 125.5 : 0,
                reps: exercise.isWeightReps || exercise.isRepsOnly ? 12 : 0,
                durationSeconds: exercise.isCardio ? 25 * 60 : (exercise.isTimeOnly ? 45 : 0),
                setNumber: index % 7 + 1, rir: index % 3 == 0 ? 2 : nil,
                notes: "原始记录 \(index), recovery", dayNote: index % 7 == 0 ? "今日训练备注\nPain + 中文" : nil,
                averageHeartRate: exercise.isCardio && index % 2 == 0 ? 131 : nil,
                maxHeartRate: exercise.isCardio ? 156 : nil, createdAt: day.addingTimeInterval(Double(index))
            )
            context.insert(set)
        }
        try context.save()
    }

    /// Compare every persisted scalar and relationship, including nil versus empty.
    static func fingerprint(_ context: ModelContext) throws -> Data {
        func optional(_ value: Any?) -> Any { value ?? NSNull() }
        let exercises = try context.fetch(FetchDescriptor<Exercise>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let sets = try context.fetch(FetchDescriptor<WorkoutSet>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let exerciseRows: [[String: Any]] = exercises.map { exercise in
            ["id": exercise.id.uuidString, "name": exercise.name, "notes": exercise.notes,
             "muscleGroup": exercise.muscleGroup, "exerciseType": exercise.exerciseType,
             "category": optional(exercise.category), "isActive": optional(exercise.isActive),
             "createdAt": exercise.createdAt.timeIntervalSinceReferenceDate,
             "sets": exercise.workoutSets.map { $0.id.uuidString }.sorted()]
        }
        let setRows: [[String: Any]] = sets.map { set in
            ["id": set.id.uuidString, "exercise": optional(set.exercise?.id.uuidString),
             "date": set.date.timeIntervalSinceReferenceDate, "weightKg": set.weightKg,
             "reps": set.reps, "durationSeconds": set.durationSeconds, "setNumber": set.setNumber,
             "rir": optional(set.rir), "notes": set.notes, "dayNote": optional(set.dayNote),
             "averageHeartRate": optional(set.averageHeartRate), "maxHeartRate": optional(set.maxHeartRate),
             "createdAt": set.createdAt.timeIntervalSinceReferenceDate]
        }
        return try JSONSerialization.data(withJSONObject: ["exercises": exerciseRows, "sets": setRows], options: [.sortedKeys])
    }
}
