import Foundation
import SwiftData

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

@main
struct TrainingRegressionTests {
    @MainActor static func main() throws {
        let legacyURL = URL(fileURLWithPath: CommandLine.arguments[1])
        try verifyUpgrade(at: legacyURL)
        try verifyTrainingFlows(at: legacyURL.deletingLastPathComponent().appendingPathComponent("new.store"))
        try verifyHistoryDayCounts()
        try verifyOrdering()
        try verifyDuration()
        print("PASS: all training regression checks")
    }

    @MainActor private static func verifyUpgrade(at url: URL) throws {
        let container = try StoreFixture.container(at: url)
        let context = container.mainContext
        let expected = try Data(contentsOf: url.appendingPathExtension("json"))
        let original = try StoreFixture.fingerprint(context)
        try expect(original == expected, "Upgrade changed persisted values or relationships")
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let sets = try context.fetch(FetchDescriptor<WorkoutSet>())
        try expect(sets.count == 611, "Lost historical sets")
        try expect(exercises.first { $0.name == "Squat" }?.isStrength == true, "Nil category must resolve to Strength")
        try expect(exercises.first { $0.name == "Squat" }?.isActiveResolved == true, "Nil activity must remain active")
        try expect(exercises.first { $0.name == "Squat" }?.muscleGroup == "Legs", "Renamed stored muscle group")
        try expect(exercises.first { $0.category == "unknown-legacy-category" }?.isStrength == true, "Unknown category compatibility")
        try expect(exercises.first { $0.name == "用户停用动作" }?.isActiveResolved == false, "Reactivated exercise")
        let totals = TrainingTotals(sets: sets)
        let history = HistorySnapshot.build(from: sets.compactMap(HistorySetSnapshot.init), startDate: .distantPast)
        try expect(history.totalSets == totals.strengthSets && history.totalVolume == totals.strengthVolume, "Today/History totals diverged")
        try expect(history.cardioMinutes == totals.cardioMinutes, "Cardio duration changed")
        try context.save()
        let reopened = try StoreFixture.container(at: url)
        let fingerprint = try StoreFixture.fingerprint(reopened.mainContext)
        try expect(fingerprint == expected, "Save/reopen changed historical data")
        print("PASS: released store upgrade and reopen preserve all 611 records and exercise preferences")
    }

    @MainActor private static func verifyTrainingFlows(at url: URL) throws {
        let container = try StoreFixture.container(at: url)
        let context = container.mainContext
        let strength = Exercise(name: "Strength", muscleGroup: "Legs")
        let cardio = Exercise(name: "Cardio", exerciseType: "cardio", category: .cardio)
        let rehab = Exercise(name: "复健负重", notes: "肩部疼痛", muscleGroup: "Shoulders", category: .rehabilitation)
        let timed = Exercise(name: "复健计时", exerciseType: "timeOnly", category: .rehabilitation)
        let reps = Exercise(name: "复健次数", exerciseType: "repsOnly", category: .rehabilitation)
        for exercise in [strength, cardio, rehab, timed, reps] { context.insert(exercise) }
        try expect(rehab.isWeightReps && timed.isTimeOnly && reps.isRepsOnly, "Rehab lost its recording mode")
        try expect(!rehab.isStrength && !rehab.isCardio, "Rehab misclassified")

        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12))!
        let sunday = calendar.date(byAdding: .day, value: -1, to: monday)!
        let records = [
            WorkoutSet(exercise: strength, date: monday, weightKg: 125, reps: 8),
            WorkoutSet(exercise: rehab, date: monday, weightKg: 2.5, reps: 12, rir: 2, notes: "No pain", dayNote: "复健后无痛"),
            WorkoutSet(exercise: timed, date: monday, durationSeconds: 45),
            WorkoutSet(exercise: reps, date: monday, reps: 15),
            WorkoutSet(exercise: cardio, date: monday, durationSeconds: 20 * 60, averageHeartRate: 120),
            WorkoutSet(exercise: cardio, date: monday, durationSeconds: 40 * 60, setNumber: 2, averageHeartRate: 150),
            WorkoutSet(exercise: cardio, date: monday, durationSeconds: 30 * 60, setNumber: 3),
            WorkoutSet(exercise: timed, date: sunday, durationSeconds: 30, dayNote: "仅复健日")
        ]
        for set in records { context.insert(set) }
        try context.save()

        let totals = TrainingTotals(sets: records)
        try expect(totals.strengthSets == 1 && totals.strengthVolume == 1000, "Rehab leaked into strength totals")
        try expect(totals.rehabilitationSets == 4, "Rehab total incorrect")
        try expect(totals.cardioSessions == 3 && totals.cardioMinutes == 90, "Cardio totals incorrect")
        try expect(totals.averageCardioHeartRate == 140, "Missing HR must not dilute weighted average")
        try expect(records[1].volume == 30, "Individual rehab volume should remain available")

        let history = HistorySnapshot.build(from: records.compactMap(HistorySetSnapshot.init), startDate: .distantPast)
        try expect(history.trainingDaysCount == 1 && history.days.count == 2 && history.weeks.count == 2, "Training-day count or rehab-only visibility incorrect")
        try expect(history.totalSets == 1 && history.totalVolume == 1000, "History strength totals contaminated")
        try expect(history.totals.rehabilitationSets == 4, "History rehab totals incorrect")
        try expect(history.averageCardioHeartRate == 140, "History average mismatch")
        try expect(history.days[0].summaryText(for: .rehabilitation).contains("复健负重x1"), "History missing rehab records")
        try expect(history.days[0].summaryText(for: .cardio).contains("Cardiox90m"), "History cardio format changed")
        try expect(history.days[1].dayNote == "仅复健日", "Rehab-only note missing")
        let currentWeek = HistorySnapshot.build(from: records.compactMap(HistorySetSnapshot.init), startDate: monday)
        try expect(currentWeek.totals.rehabilitationSets == 3, "Range includes past rehab sets")

        records[1].weightKg = 5
        records[1].reps = 10
        records[1].rir = nil
        records[2].durationSeconds = 60
        records[3].reps = 20
        records[4].durationSeconds = CardioDuration.adjusted(20, increasing: true) * 60
        try context.save()
        let expected = try StoreFixture.fingerprint(context)
        let reopened = try StoreFixture.container(at: url)
        let actual = try StoreFixture.fingerprint(reopened.mainContext)
        try expect(actual == expected, "Rehab or cardio edits did not persist")

        let csv = WorkoutHistoryCSVExporter.makeCSV(from: records)
        try expect(csv.contains("\"rehabilitation\"") && csv.contains("复健负重"), "CSV missing rehab category or name")
        let export = try CSVDocumentWriter.writeCSVFile(content: csv, filename: "gplift-regression-\(UUID()).csv")
        defer { try? FileManager.default.removeItem(at: export) }
        let exported = try Data(contentsOf: export)
        try expect(exported.prefix(3) == Data([0xef, 0xbb, 0xbf]), "CSV UTF-8 BOM missing")
        try expect(String(data: exported.dropFirst(3), encoding: .utf8)?.contains("复健负重") == true, "CSV Chinese encoding damaged")
        print("PASS: three recording modes, mixed/rehab-only days, weekly/range totals, heart rate, editing/reopen and CSV")
    }

    @MainActor private static func verifyHistoryDayCounts() throws {
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 12))!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let strength = Exercise(name: "Strength")
        let cardio = Exercise(name: "Cardio", exerciseType: "cardio", category: .cardio)
        let rehab = Exercise(name: "Rehab", category: .rehabilitation)
        let records = [
            WorkoutSet(exercise: strength, date: monday, weightKg: 20, reps: 10),
            WorkoutSet(exercise: strength, date: monday, weightKg: 25, reps: 10, setNumber: 2),
            WorkoutSet(exercise: cardio, date: monday, durationSeconds: 30 * 60),
            WorkoutSet(exercise: cardio, date: tuesday, durationSeconds: 20 * 60),
            WorkoutSet(exercise: rehab, date: sunday, weightKg: 5, reps: 10),
            WorkoutSet(exercise: strength, date: nextMonday, weightKg: 30, reps: 10)
        ].compactMap(HistorySetSnapshot.init)
        let history = HistorySnapshot.build(from: records, startDate: .distantPast)
        try expect(history.trainingDaysCount == 3 && history.days.count == 4, "Mixed days must count once; rehab-only days must remain visible")
        try expect(history.strengthSessions == 2 && history.totalSets == 3, "Strength sessions must count days, not sets")
        try expect(history.weeks.count == 2, "Monday must start a new week")
        let week = history.weeks[1]
        try expect(week.trainingDaysCount == 2 && week.strengthSessions == 1, "Weekly day/session counts incorrect")
        try expect(week.totalSets == 2 && week.totalVolume == 450 && week.cardioMinutes == 50, "Weekly categories or volume changed")
        let filtered = HistorySnapshot.build(from: records, startDate: nextMonday)
        try expect(filtered.trainingDaysCount == 1 && filtered.strengthSessions == 1, "Selected-period counts include excluded days")
        try expect(HistorySnapshot.empty.trainingDaysCount == 0 && HistorySnapshot.empty.strengthSessions == 0, "Empty history counts incorrect")
        print("PASS: mixed/strength/cardio/rehab-only days, distinct Strength sessions, Monday boundary and selected-period counts")
    }

    private static func verifyOrdering() throws {
        let never = Exercise(name: "A Never", category: .rehabilitation)
        let recent = Exercise(name: "B Recent", category: .rehabilitation)
        let old = Exercise(name: "C Old", category: .rehabilitation)
        let dates: [UUID: Date] = [old.id: Date(timeIntervalSince1970: 100), recent.id: Date(timeIntervalSince1970: 200)]
        let input = [never, recent, old]
        let due = input.sorted { ExerciseOrdering.due.precedes($0, $1, lastTrainedDates: dates) }
        let standard = input.sorted { ExerciseOrdering.standard.precedes($0, $1, lastTrainedDates: dates) }
        try expect(due.map(\.id) == [old.id, recent.id, never.id], "Due order incorrect")
        try expect(standard.map(\.id) == [never.id, recent.id, old.id], "Default name order incorrect")
        try expect(ExerciseOrdering.standard.groupPrecedes("Chest", "Back", lhsDate: dates[recent.id], rhsDate: dates[old.id]), "Default group order must ignore dates")
        try expect(ExerciseOrdering.due.groupPrecedes("Back", "Chest", lhsDate: dates[old.id], rhsDate: dates[recent.id]), "Due group order must use dates")
        try expect(!ExerciseOrdering.due.groupPrecedes("Chest", "Back", lhsDate: nil, rhsDate: dates[recent.id]), "Never-trained group must stay at bottom")
        try expect(ExerciseCategory.allCases.map(\.sortOrder) == [0, 1, 2], "Category ordering unstable")
        print("PASS: category, fixed muscle group/name, overdue and never-trained ordering")
    }

    private static func verifyDuration() throws {
        var minutes = 30
        for _ in 0..<3 { minutes = CardioDuration.adjusted(minutes, increasing: true) }
        try expect(minutes == 45, "Repeated increment must add five minutes")
        for _ in 0..<3 { minutes = CardioDuration.adjusted(minutes, increasing: false) }
        try expect(minutes == 30, "Repeated decrement must subtract five minutes")
        try expect(CardioDuration.adjusted(28, increasing: true) == 33, "Typed values must not round to five-minute multiples")
        try expect(CardioDuration.adjusted(3, increasing: false) == 1, "Duration must remain positive")
        try expect(CardioDuration.adjusted(1439, increasing: true) == 1440, "Duration upper bound")
        print("PASS: five-minute adjustment, repeated presses, arbitrary whole minutes and boundaries")
    }
}
