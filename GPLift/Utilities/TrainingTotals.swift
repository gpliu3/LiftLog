import Foundation

/// Shared totals for Today, History and day details. Exercise volume remains
/// available for rehab records, but only Strength contributes to strength totals.
struct TrainingTotals: Sendable {
    private(set) var strengthSets = 0
    private(set) var strengthVolume: Double = 0
    private(set) var rehabilitationSets = 0
    private(set) var cardioSessions = 0
    private(set) var cardioMinutes = 0
    private var heartRateWeightedTotal = 0
    private var heartRateRecordedMinutes = 0

    var averageCardioHeartRate: Int? {
        guard heartRateRecordedMinutes > 0 else { return nil }
        return Int((Double(heartRateWeightedTotal) / Double(heartRateRecordedMinutes)).rounded())
    }

    init() {}

    init(sets: [WorkoutSet]) {
        for set in sets {
            guard let exercise = set.exercise else { continue }
            record(category: exercise.resolvedCategory, volume: set.volume,
                   minutes: set.cardioMinutes, averageHeartRate: set.averageHeartRate)
        }
    }

    mutating func record(category: ExerciseCategory, volume: Double, minutes: Int, averageHeartRate: Int?) {
        switch category {
        case .strength:
            strengthSets += 1
            strengthVolume += volume
        case .rehabilitation:
            rehabilitationSets += 1
        case .cardio:
            cardioSessions += 1
            cardioMinutes += minutes
            if minutes > 0, let averageHeartRate, averageHeartRate > 0 {
                heartRateWeightedTotal += averageHeartRate * minutes
                heartRateRecordedMinutes += minutes
            }
        }
    }

    static func combined(_ summaries: [TrainingTotals]) -> TrainingTotals {
        summaries.reduce(into: TrainingTotals()) { result, summary in
            result.strengthSets += summary.strengthSets
            result.strengthVolume += summary.strengthVolume
            result.rehabilitationSets += summary.rehabilitationSets
            result.cardioSessions += summary.cardioSessions
            result.cardioMinutes += summary.cardioMinutes
            result.heartRateWeightedTotal += summary.heartRateWeightedTotal
            result.heartRateRecordedMinutes += summary.heartRateRecordedMinutes
        }
    }
}

enum CardioDuration {
    static let adjustmentMinutes = 5
    static let allowedMinutes = 1...1440

    static func adjusted(_ minutes: Int, increasing: Bool) -> Int {
        let clamped = min(allowedMinutes.upperBound, max(allowedMinutes.lowerBound, minutes))
        return min(allowedMinutes.upperBound,
                   max(allowedMinutes.lowerBound, clamped + (increasing ? adjustmentMinutes : -adjustmentMinutes)))
    }
}
