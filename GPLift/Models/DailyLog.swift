import Foundation
import SwiftData

/// One optional record per calendar day: knee score, symptom tags and the day's note.
/// Lives beside workout data, so it also exists on rest days.
@Model
final class DailyLog {
    var id: UUID
    /// Start of the calendar day this record belongs to.
    var day: Date
    var kneeScore: Int?
    /// Comma-separated `KneeTag` raw values; a plain string keeps the stored schema simple.
    var kneeTags: String
    var note: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        day: Date,
        kneeScore: Int? = nil,
        kneeTags: String = "",
        note: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.day = day
        self.kneeScore = kneeScore
        self.kneeTags = kneeTags
        self.note = note
        self.updatedAt = updatedAt
    }

    var checkIn: DailyCheckIn {
        DailyCheckIn(kneeScore: kneeScore, kneeTags: KneeTag.decode(kneeTags), note: note)
    }

    func apply(_ checkIn: DailyCheckIn) {
        kneeScore = checkIn.kneeScore.map { min(max($0, DailyCheckIn.scoreRange.lowerBound), DailyCheckIn.scoreRange.upperBound) }
        kneeTags = KneeTag.encode(checkIn.kneeTags)
        note = checkIn.note
        updatedAt = Date()
    }

    /// The record for `day`, if any. Should duplicates ever exist, the most recently edited wins.
    static func record(for day: Date, in context: ModelContext, calendar: Calendar = .current) -> DailyLog? {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.day >= dayStart && $0.day < dayEnd },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func save(_ checkIn: DailyCheckIn, for day: Date, in context: ModelContext, calendar: Calendar = .current) throws -> DailyLog {
        let log: DailyLog
        if let existing = record(for: day, in: context, calendar: calendar) {
            log = existing
        } else {
            log = DailyLog(day: calendar.startOfDay(for: day))
            context.insert(log)
        }
        log.apply(checkIn)
        try context.save()
        return log
    }

    /// Latest record per day, keyed by start of day.
    static func checkInsByDay(_ logs: [DailyLog], calendar: Calendar = .current) -> [Date: DailyCheckIn] {
        var newest: [Date: DailyLog] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.day)
            if let current = newest[day], current.updatedAt >= log.updatedAt { continue }
            newest[day] = log
        }
        return newest.mapValues(\.checkIn)
    }
}
