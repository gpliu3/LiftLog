import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var id: UUID
    var exercise: Exercise?
    var date: Date
    var weightKg: Double
    var reps: Int
    var durationSeconds: Int
    var setNumber: Int
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        exercise: Exercise? = nil,
        date: Date = Date(),
        weightKg: Double = 0,
        reps: Int = 0,
        durationSeconds: Int = 0,
        setNumber: Int = 1,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.exercise = exercise
        self.date = date
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.setNumber = setNumber
        self.notes = notes
        self.createdAt = createdAt
    }

    var volume: Double {
        weightKg * Double(reps)
    }

    var estimatedOneRepMax: Double {
        // Epley Formula: weight × (1 + reps / 30)
        weightKg * (1 + Double(reps) / 30)
    }

    static func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes):\(String(format: "%02d", secs))" : "\(minutes):00"
        }
        return "\(seconds)s"
    }

    var formattedDuration: String {
        WorkoutSet.formatDuration(durationSeconds)
    }
}
