import Foundation

/// Health figures for one calendar day, read from Apple Health and never persisted by the app.
struct DailyHealth: Equatable, Sendable {
    var steps: Int?
    /// Time asleep for the night that ended on this day.
    var sleepMinutes: Int?

    var isEmpty: Bool { steps == nil && sleepMinutes == nil }
}

enum KneeTag: String, CaseIterable, Identifiable, Sendable {
    case stiff
    case swollen
    case heavy
    case sharpFront
    case unstable
    case flexionPain

    var id: String { rawValue }
    var localizedName: String { "knee.tag.\(rawValue)".localized }

    static func decode(_ stored: String) -> [KneeTag] {
        let selected = Set(stored.split(separator: ",").compactMap { KneeTag(rawValue: String($0)) })
        return allCases.filter(selected.contains)
    }

    static func encode(_ tags: [KneeTag]) -> String {
        let selected = Set(tags)
        return allCases.filter(selected.contains).map(\.rawValue).joined(separator: ",")
    }
}

/// A day's knee score, symptom tags and note, detached from storage.
struct DailyCheckIn: Equatable, Sendable {
    static let scoreRange = 1...10

    var kneeScore: Int?
    var kneeTags: [KneeTag] = []
    var note: String = ""

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isEmpty: Bool { kneeScore == nil && kneeTags.isEmpty && trimmedNote.isEmpty }

    enum Level: Sendable { case good, fair, poor }

    /// 9–10 reads as fine, 7–8 as "not so good", anything lower as a bad day.
    static func level(for score: Int) -> Level {
        if score >= 9 { return .good }
        return score >= 7 ? .fair : .poor
    }
}

enum HealthFormat {
    static func steps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    static func sleep(minutes: Int) -> String {
        "health.sleepDuration".localized(with: minutes / 60, minutes % 60)
    }
}

/// Averages over the days that actually have a value, so missing days do not drag them down.
struct HealthAverages: Equatable, Sendable {
    let steps: Int?
    let sleepMinutes: Int?

    var isEmpty: Bool { steps == nil && sleepMinutes == nil }

    init(days: [DailyHealth]) {
        steps = Self.average(days.compactMap(\.steps))
        sleepMinutes = Self.average(days.compactMap(\.sleepMinutes))
    }

    private static func average(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

enum SleepAggregator {
    /// A night belongs to the day it ends on: sleep starting from 18:00 counts toward the
    /// next calendar day, so a 22:30–06:30 night and a 01:00–08:00 night land on the same day.
    static let dayRolloverHour = 18

    static func sleepDay(for start: Date, calendar: Calendar = .current) -> Date {
        let shifted = start.addingTimeInterval(TimeInterval((24 - dayRolloverHour) * 3600))
        return calendar.startOfDay(for: shifted)
    }

    /// Total minutes asleep per day. Overlapping intervals (for example a watch and a phone
    /// both recording the same night) are merged so they are not counted twice.
    static func minutesByDay(asleep intervals: [DateInterval], calendar: Calendar = .current) -> [Date: Int] {
        let grouped = Dictionary(grouping: intervals) { sleepDay(for: $0.start, calendar: calendar) }
        return grouped.compactMapValues { dayIntervals in
            var total: TimeInterval = 0
            var current: DateInterval?
            for interval in dayIntervals.sorted(by: { $0.start < $1.start }) {
                if let merged = current, interval.start <= merged.end {
                    current = DateInterval(start: merged.start, end: max(merged.end, interval.end))
                } else {
                    total += current?.duration ?? 0
                    current = interval
                }
            }
            total += current?.duration ?? 0
            let minutes = Int((total / 60).rounded())
            return minutes > 0 ? minutes : nil
        }
    }
}

/// History list model: logged days from `HistorySnapshot` plus rest days that have Health data.
struct HistoryTimeline: Sendable {
    enum Row: Identifiable, Sendable {
        case logged(HistoryDaySnapshot)
        case rest(Date)

        var date: Date {
            switch self {
            case .logged(let day): return day.date
            case .rest(let date): return date
            }
        }

        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    }

    struct Week: Identifiable, Sendable {
        var id: TimeInterval { summary.weekStart.timeIntervalSinceReferenceDate }
        /// Training totals for the week; empty when the week has rest rows only.
        let summary: HistoryWeekSnapshot
        let rows: [Row]
        var hasLoggedDays: Bool { !summary.days.isEmpty }
    }

    static let empty = HistoryTimeline(weeks: [])

    let weeks: [Week]
    var isEmpty: Bool { weeks.isEmpty }

    /// Rest rows are added only inside the selected period, for days that have Health data
    /// (completed days only) or a knee check-in, so History is unchanged without either.
    static func build(
        snapshot: HistorySnapshot,
        health: [Date: DailyHealth],
        checkInDays: Set<Date> = [],
        startDate: Date,
        today: Date
    ) -> HistoryTimeline {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let loggedDates = Set(snapshot.days.map(\.date))
        let firstDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: today)
        let healthDays = health.filter { !$0.value.isEmpty && $0.key < endDay }.keys
        let restDays = Set(healthDays).union(checkInDays.filter { $0 <= endDay })
        let restRows: [Row] = restDays.compactMap { date in
            guard date >= firstDay, !loggedDates.contains(date) else { return nil }
            return .rest(date)
        }

        func weekStart(for date: Date) -> Date {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.startOfDay(for: calendar.date(from: components) ?? date)
        }

        var rowsByWeek = Dictionary(grouping: restRows) { weekStart(for: $0.date) }
        var summaries: [Date: HistoryWeekSnapshot] = [:]
        for week in snapshot.weeks {
            summaries[week.weekStart] = week
            rowsByWeek[week.weekStart, default: []].append(contentsOf: week.days.map(Row.logged))
        }

        let weeks = rowsByWeek.map { start, rows in
            Week(
                summary: summaries[start] ?? HistoryWeekSnapshot(weekStart: start, days: [], totals: TrainingTotals()),
                rows: rows.sorted { $0.date > $1.date }
            )
        }
        .sorted { $0.summary.weekStart > $1.summary.weekStart }

        return HistoryTimeline(weeks: weeks)
    }
}

/// One row per day: Health figures next to that day's training totals. Includes rest days.
enum DailySummaryCSVExporter {
    private static let header = [
        "date",
        "steps",
        "sleep_minutes",
        "knee_score",
        "knee_tags",
        "knee_load",
        "note",
        "strength_sets",
        "strength_volume_kg",
        "cardio_sessions",
        "cardio_minutes",
        "rehabilitation_sets"
    ].joined(separator: ",")

    /// `kneeLoadDays` are days with at least one exercise flagged as knee load.
    /// `notes` carries the resolved day note (check-in note, or the older per-set day note).
    static func makeCSV(
        training: [Date: TrainingTotals],
        health: [Date: DailyHealth],
        checkIns: [Date: DailyCheckIn] = [:],
        notes: [Date: String] = [:],
        kneeLoadDays: Set<Date> = []
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let days = Set(training.keys)
            .union(health.filter { !$0.value.isEmpty }.keys)
            .union(checkIns.filter { !$0.value.isEmpty }.keys)
            .union(notes.filter { !$0.value.isEmpty }.keys)
            .sorted()
        var lines = [header]
        for day in days {
            let totals = training[day] ?? TrainingTotals()
            let metrics = health[day]
            let checkIn = checkIns[day]
            let note = notes[day] ?? checkIn?.trimmedNote ?? ""
            let row: [String] = [
                dateFormatter.string(from: day),
                metrics?.steps.map(String.init) ?? "",
                metrics?.sleepMinutes.map(String.init) ?? "",
                checkIn?.kneeScore.map(String.init) ?? "",
                CSVDocumentWriter.csvEscape((checkIn?.kneeTags ?? []).map(\.rawValue).joined(separator: ";")),
                kneeLoadDays.contains(day) ? "1" : "0",
                CSVDocumentWriter.csvEscape(note),
                "\(totals.strengthSets)",
                String(format: "%.2f", totals.strengthVolume),
                "\(totals.cardioSessions)",
                "\(totals.cardioMinutes)",
                "\(totals.rehabilitationSets)"
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
