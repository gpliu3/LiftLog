import Foundation

struct HistorySetSnapshot: Sendable {
    let id: UUID
    let date: Date
    let exerciseID: UUID
    let exerciseName: String
    let category: ExerciseCategory
    let durationMinutes: Int
    let averageHeartRate: Int?
    let volume: Double
    let setNumber: Int
    let createdAt: Date
    let dayNote: String

    init?(workoutSet: WorkoutSet) {
        guard let exercise = workoutSet.exercise else { return nil }
        id = workoutSet.id
        date = workoutSet.date
        exerciseID = exercise.id
        exerciseName = exercise.displayName
        category = exercise.resolvedCategory
        durationMinutes = workoutSet.cardioMinutes
        averageHeartRate = workoutSet.averageHeartRate
        volume = workoutSet.volume
        setNumber = workoutSet.setNumber
        createdAt = workoutSet.createdAt
        dayNote = workoutSet.dayNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct HistoryDaySnapshot: Identifiable, Sendable {
    struct ExerciseSummary: Identifiable, Sendable {
        let id: UUID
        let name: String
        let count: Int
        let category: ExerciseCategory
        let totalMinutes: Int
        let latestDate: Date
    }

    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    let date: Date
    let totals: TrainingTotals
    var setCount: Int { totals.strengthSets }
    var totalVolume: Double { totals.strengthVolume }
    let exerciseSummaries: [ExerciseSummary]
    let dayNote: String

    func summaryText(for category: ExerciseCategory) -> String {
        exerciseSummaries
            .filter { $0.category == category }
            .map { category == .cardio ? "\($0.name)x\($0.totalMinutes)m" : "\($0.name)x\($0.count)" }
            .joined(separator: ", ")
    }
}

struct HistoryWeekSnapshot: Identifiable, Sendable {
    var id: TimeInterval { weekStart.timeIntervalSinceReferenceDate }
    let weekStart: Date
    let days: [HistoryDaySnapshot]
    let totals: TrainingTotals
    var totalSets: Int { totals.strengthSets }
    var totalVolume: Double { totals.strengthVolume }
    var cardioSessions: Int { totals.cardioSessions }
    var cardioMinutes: Int { totals.cardioMinutes }
    var averageCardioHeartRate: Int? { totals.averageCardioHeartRate }
}

struct HistorySnapshot: Sendable {
    static let empty = HistorySnapshot(
        weeks: [],
        days: [],
        totals: TrainingTotals()
    )

    let weeks: [HistoryWeekSnapshot]
    let days: [HistoryDaySnapshot]
    let totals: TrainingTotals
    var trainingDaysCount: Int { days.count }
    var totalSets: Int { totals.strengthSets }
    var totalVolume: Double { totals.strengthVolume }
    var cardioSessions: Int { totals.cardioSessions }
    var cardioMinutes: Int { totals.cardioMinutes }
    var averageCardioHeartRate: Int? { totals.averageCardioHeartRate }

    static func build(from sets: [HistorySetSnapshot], startDate: Date) -> HistorySnapshot {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let filteredSets = sets.filter { $0.date >= startDate }
        let groupedDays = Dictionary(grouping: filteredSets) { set in
            calendar.startOfDay(for: set.date)
        }

        let days = groupedDays.map { day, sets in
            let groupedExercises = Dictionary(grouping: sets) { $0.exerciseID }
            let exerciseSummaries = groupedExercises.compactMap { exerciseID, exerciseSets -> HistoryDaySnapshot.ExerciseSummary? in
                guard let first = exerciseSets.first else { return nil }
                let latest = exerciseSets.map(\.date).max() ?? .distantPast
                return HistoryDaySnapshot.ExerciseSummary(
                    id: exerciseID,
                    name: first.exerciseName,
                    count: exerciseSets.count,
                    category: first.category,
                    totalMinutes: exerciseSets.reduce(0) { $0 + $1.durationMinutes },
                    latestDate: latest
                )
            }
            .sorted {
                if $0.latestDate != $1.latestDate { return $0.latestDate > $1.latestDate }
                return $0.name < $1.name
            }

            let totals = sets.reduce(into: TrainingTotals()) { result, set in
                result.record(category: set.category, volume: set.volume,
                              minutes: set.durationMinutes, averageHeartRate: set.averageHeartRate)
            }

            return HistoryDaySnapshot(
                date: day,
                totals: totals,
                exerciseSummaries: exerciseSummaries,
                dayNote: HistorySnapshot.dayNote(from: sets)
            )
        }
        .sorted { $0.date > $1.date }

        let groupedWeeks = Dictionary(grouping: days) { day in
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.date)
            return calendar.startOfDay(for: calendar.date(from: components) ?? day.date)
        }

        let weeks = groupedWeeks.map { weekStart, days in
            let orderedDays = days.sorted { $0.date > $1.date }
            return HistoryWeekSnapshot(
                weekStart: weekStart,
                days: orderedDays,
                totals: TrainingTotals.combined(orderedDays.map(\.totals))
            )
        }
        .sorted { $0.weekStart > $1.weekStart }

        return HistorySnapshot(
            weeks: weeks,
            days: days,
            totals: TrainingTotals.combined(days.map(\.totals))
        )
    }

    private static func dayNote(from sets: [HistorySetSnapshot]) -> String {
        sets
            .filter { !$0.dayNote.isEmpty }
            .sorted(by: trainingOrder(lhs:rhs:))
            .last?
            .dayNote ?? ""
    }

    private static func trainingOrder(lhs: HistorySetSnapshot, rhs: HistorySetSnapshot) -> Bool {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let lhsDay = calendar.startOfDay(for: lhs.date)
        let rhsDay = calendar.startOfDay(for: rhs.date)
        if lhsDay != rhsDay { return lhsDay < rhsDay }
        if lhs.setNumber != rhs.setNumber { return lhs.setNumber < rhs.setNumber }
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
