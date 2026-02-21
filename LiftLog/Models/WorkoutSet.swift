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
    var rir: Int?
    var notes: String
    var bodyWeightKg: Double?
    var waistCm: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        exercise: Exercise? = nil,
        date: Date = Date(),
        weightKg: Double = 0,
        reps: Int = 0,
        durationSeconds: Int = 0,
        setNumber: Int = 1,
        rir: Int? = nil,
        notes: String = "",
        bodyWeightKg: Double? = nil,
        waistCm: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.exercise = exercise
        self.date = date
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.setNumber = setNumber
        self.rir = rir
        self.notes = notes
        self.bodyWeightKg = bodyWeightKg
        self.waistCm = waistCm
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

extension WorkoutSet {
    /// Whether this set is a personal best reached for the first time.
    /// Repeated ties do not count as PB again.
    func isPersonalBest(in exerciseSets: [WorkoutSet]) -> Bool {
        guard exercise != nil else { return false }
        let comparable = exerciseSets.filter { $0.exercise?.id == exercise?.id }
        let ordered = comparable.sorted(by: WorkoutSet.trainingOrder(lhs:rhs:))

        guard let currentIndex = ordered.firstIndex(where: { $0.id == id }) else { return false }
        let prior = Array(ordered.prefix(currentIndex))
        let previousMaxWeight = prior.map(\.weightKg).max() ?? 0
        let previousMaxVolume = prior.map(\.volume).max() ?? 0
        let previousMaxDuration = prior.map(\.durationSeconds).max() ?? 0
        let previousMaxReps = prior.map(\.reps).max() ?? 0

        if exercise?.isTimeOnly == true {
            return durationSeconds > 0 && durationSeconds > previousMaxDuration
        }
        if exercise?.isRepsOnly == true {
            return reps > 0 && reps > previousMaxReps
        }
        return (weightKg > 0 && weightKg > previousMaxWeight) || (volume > 0 && volume > previousMaxVolume)
    }

    static func trainingOrder(lhs: WorkoutSet, rhs: WorkoutSet) -> Bool {
        let calendar = Calendar.current
        let lhsDay = calendar.startOfDay(for: lhs.date)
        let rhsDay = calendar.startOfDay(for: rhs.date)
        if lhsDay != rhsDay { return lhsDay < rhsDay }
        if lhs.setNumber != rhs.setNumber { return lhs.setNumber < rhs.setNumber }
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func latestBodyMetrics(from sets: [WorkoutSet]) -> (bodyWeightKg: Double?, waistCm: Double?) {
        let ordered = sets.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        let bodyWeight = ordered.compactMap(\.bodyWeightKg).first
        let waist = ordered.compactMap(\.waistCm).first
        return (bodyWeight, waist)
    }
}
