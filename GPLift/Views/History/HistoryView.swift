import SwiftUI
import SwiftData
import UIKit

private struct HistorySetSnapshot: Sendable {
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

private struct HistoryDaySnapshot: Identifiable, Sendable {
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
    let setCount: Int
    let totalVolume: Double
    let exerciseSummaries: [ExerciseSummary]
    let dayNote: String

    var strengthSummaryText: String {
        exerciseSummaries
            .filter { $0.category == .strength }
            .map { "\($0.name)x\($0.count)" }
            .joined(separator: ", ")
    }

    var cardioSummaryText: String {
        exerciseSummaries
            .filter { $0.category == .cardio }
            .map { "\($0.name)x\($0.totalMinutes)m" }
            .joined(separator: ", ")
    }

    let cardioSessions: Int
    let cardioMinutes: Int
    let cardioHeartRateWeightedTotal: Int
    let cardioHeartRateRecordedMinutes: Int
}

private struct HistoryWeekSnapshot: Identifiable, Sendable {
    var id: TimeInterval { weekStart.timeIntervalSinceReferenceDate }
    let weekStart: Date
    let days: [HistoryDaySnapshot]
    let totalSets: Int
    let totalVolume: Double
    let cardioSessions: Int
    let cardioMinutes: Int
    let averageCardioHeartRate: Int?
}

private struct HistorySnapshot: Sendable {
    static let empty = HistorySnapshot(weeks: [], days: [], trainingDaysCount: 0, totalSets: 0, totalVolume: 0, cardioSessions: 0, cardioMinutes: 0)

    let weeks: [HistoryWeekSnapshot]
    let days: [HistoryDaySnapshot]
    let trainingDaysCount: Int
    let totalSets: Int
    let totalVolume: Double
    let cardioSessions: Int
    let cardioMinutes: Int

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

            let cardioHeartRate = sets.reduce(into: (weightedTotal: 0, recordedMinutes: 0)) { result, set in
                guard set.category == .cardio,
                      set.durationMinutes > 0,
                      let averageHeartRate = set.averageHeartRate,
                      averageHeartRate > 0 else { return }
                result.weightedTotal += averageHeartRate * set.durationMinutes
                result.recordedMinutes += set.durationMinutes
            }

            return HistoryDaySnapshot(
                date: day,
                setCount: sets.filter { $0.category == .strength }.count,
                totalVolume: sets.filter { $0.category == .strength }.reduce(0) { $0 + $1.volume },
                exerciseSummaries: exerciseSummaries,
                dayNote: HistorySnapshot.dayNote(from: sets),
                cardioSessions: sets.filter { $0.category == .cardio }.count,
                cardioMinutes: sets.filter { $0.category == .cardio }.reduce(0) { $0 + $1.durationMinutes },
                cardioHeartRateWeightedTotal: cardioHeartRate.weightedTotal,
                cardioHeartRateRecordedMinutes: cardioHeartRate.recordedMinutes
            )
        }
        .sorted { $0.date > $1.date }

        let groupedWeeks = Dictionary(grouping: days) { day in
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.date)
            return calendar.startOfDay(for: calendar.date(from: components) ?? day.date)
        }

        let weeks = groupedWeeks.map { weekStart, days in
            let orderedDays = days.sorted { $0.date > $1.date }
            let heartRateWeightedTotal = orderedDays.reduce(0) { $0 + $1.cardioHeartRateWeightedTotal }
            let heartRateRecordedMinutes = orderedDays.reduce(0) { $0 + $1.cardioHeartRateRecordedMinutes }
            let averageCardioHeartRate = heartRateRecordedMinutes > 0
                ? Int((Double(heartRateWeightedTotal) / Double(heartRateRecordedMinutes)).rounded())
                : nil
            return HistoryWeekSnapshot(
                weekStart: weekStart,
                days: orderedDays,
                totalSets: orderedDays.reduce(0) { $0 + $1.setCount },
                totalVolume: orderedDays.reduce(0) { $0 + $1.totalVolume },
                cardioSessions: orderedDays.reduce(0) { $0 + $1.cardioSessions },
                cardioMinutes: orderedDays.reduce(0) { $0 + $1.cardioMinutes },
                averageCardioHeartRate: averageCardioHeartRate
            )
        }
        .sorted { $0.weekStart > $1.weekStart }

        return HistorySnapshot(
            weeks: weeks,
            days: days,
            trainingDaysCount: days.count,
            totalSets: filteredSets.filter { $0.category == .strength }.count,
            totalVolume: filteredSets.filter { $0.category == .strength }.reduce(0) { $0 + $1.volume },
            cardioSessions: filteredSets.filter { $0.category == .cardio }.count,
            cardioMinutes: filteredSets.filter { $0.category == .cardio }.reduce(0) { $0 + $1.durationMinutes }
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

struct HistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSet.date, order: .reverse) private var allSets: [WorkoutSet]
    @State private var languageManager = LanguageManager.shared
    @State private var settingsManager = SettingsManager.shared

    @State private var selectedPeriod: TimePeriod = .all
    @State private var selectedDay: Date?
    @State private var showingExportSheet = false
    @State private var now = Date()
    @State private var snapshot = HistorySnapshot.empty
    @State private var snapshotSignature = ""
    @State private var rebuildTask: Task<Void, Never>?

    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All"

        var localized: String {
            switch self {
            case .week: return "history.week".localized
            case .month: return "history.month".localized
            case .all: return "history.all".localized
            }
        }
    }

    private var startDate: Date {
        switch selectedPeriod {
        case .week:
            return now.startOfWeek
        case .month:
            let calendar = Calendar.current
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            return allSets.map(\.date).min() ?? now
        }
    }

    private var trainingDaysCount: Int {
        snapshot.trainingDaysCount
    }

    private var totalVolume: Double {
        snapshot.totalVolume
    }

    private var totalSets: Int {
        snapshot.totalSets
    }

    private var cardioSessions: Int { snapshot.cardioSessions }
    private var cardioMinutes: Int { snapshot.cardioMinutes }

    private var allSetsSignature: String {
        [
            selectedPeriod.rawValue,
            "\(now.startOfWeek.timeIntervalSinceReferenceDate)",
            "\(Calendar.current.startOfDay(for: now).timeIntervalSinceReferenceDate)",
            "\(allSets.count)",
            allSets.map { set in
                [
                    set.id.uuidString,
                    set.exercise?.id.uuidString ?? "",
                    "\(set.date.timeIntervalSinceReferenceDate)",
                    "\(set.weightKg)",
                    "\(set.reps)",
                    "\(set.durationSeconds)",
                    set.exercise?.resolvedCategory.rawValue ?? ExerciseCategory.strength.rawValue,
                    "\(set.averageHeartRate ?? 0)",
                    "\(set.maxHeartRate ?? 0)",
                    "\(set.setNumber)",
                    set.dayNote ?? ""
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker

                if snapshot.days.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("history.title".localized)
            .font(AppTextStyle.body)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("history.export".localized)
                }
            }
            .sheet(item: $selectedDay) { date in
                DayDetailView(date: date)
            }
            .sheet(isPresented: $showingExportSheet) {
                HistoryExportView(
                    allSets: allSets,
                    defaultStartDate: startDate,
                    defaultEndDate: now
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshNow()
        }
        .onAppear {
            scheduleSnapshotRebuild(force: true)
        }
        .onChange(of: allSetsSignature) { _, _ in
            scheduleSnapshotRebuild()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshNow()
            }
        }
        .id(languageManager.currentLanguage)
    }

    private func refreshNow() {
        now = Date()
    }

    private func scheduleSnapshotRebuild(force: Bool = false) {
        let signature = allSetsSignature
        guard force || signature != snapshotSignature else { return }
        snapshotSignature = signature
        rebuildTask?.cancel()

        let startDate = startDate
        let setSnapshots = allSets.compactMap(HistorySetSnapshot.init(workoutSet:))

        rebuildTask = Task {
            let built = await Task.detached(priority: .userInitiated) {
                HistorySnapshot.build(from: setSnapshots, startDate: startDate)
            }.value
            guard !Task.isCancelled else { return }
            snapshot = built
        }
    }

    private var periodPicker: some View {
        VStack(spacing: 4) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.localized).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack(spacing: 8) {
                HistorySummaryItemView(
                    value: "\(trainingDaysCount)",
                    label: "history.trainingDays".localized,
                    systemImage: "calendar"
                )

                HistorySummaryItemView(
                    value: "\(totalSets)",
                    label: "history.totalSets".localized,
                    systemImage: "number"
                )

                HistorySummaryItemView(
                    value: String(format: "%.0f", totalVolume),
                    label: "history.totalVolume".localized,
                    systemImage: "scalemass"
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 2)

            if cardioSessions > 0 {
                Label(
                    WorkoutSet.localizedCardioSummary(
                        sessions: cardioSessions,
                        minutes: cardioMinutes,
                        includesCategory: true
                    ),
                    systemImage: "heart.fill"
                )
                .font(AppTextStyle.captionStrong)
                .foregroundStyle(.teal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 4)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "history.noWorkouts".localized,
            systemImage: "calendar.badge.exclamationmark",
            description: Text("history.noWorkoutsDescription".localized)
        )
    }

    private var historyList: some View {
        List {
            ForEach(snapshot.weeks) { week in
                Section {
                    ForEach(week.days) { day in
                        DayRowView(day: day)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDay = day.date
                            }
                    }
                } header: {
                    WeekSummaryHeaderView(
                        week: week,
                        cardioGoalMinutes: settingsManager.weeklyCardioGoalMinutes
                    )
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 24)
    }
}

private struct HistoryExportView: View {
    @Environment(\.dismiss) private var dismiss

    let allSets: [WorkoutSet]
    let defaultStartDate: Date
    let defaultEndDate: Date

    @State private var rangePreset: ExportRangePreset = .last30Days
    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var exportedCSV = ""
    @State private var exportedFileURL: URL?
    @State private var copied = false
    @State private var exportError = false

    private enum ExportRangePreset: String, CaseIterable, Identifiable {
        case last7Days
        case last30Days
        case all
        case custom

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .last7Days: return "history.export.range.last7"
            case .last30Days: return "history.export.range.last30"
            case .all: return "history.export.range.all"
            case .custom: return "history.export.range.custom"
            }
        }
    }

    init(allSets: [WorkoutSet], defaultStartDate: Date, defaultEndDate: Date) {
        self.allSets = allSets
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        _fromDate = State(initialValue: defaultStartDate)
        _toDate = State(initialValue: defaultEndDate)
    }

    private var normalizedStart: Date {
        Calendar.current.startOfDay(for: fromDate)
    }

    private var normalizedEnd: Date {
        let dayStart = Calendar.current.startOfDay(for: toDate)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? dayStart
    }

    private var filteredSets: [WorkoutSet] {
        allSets.filter { set in
            set.date >= normalizedStart && set.date <= normalizedEnd && set.exercise != nil
        }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "gplift_\(formatter.string(from: normalizedStart))_to_\(formatter.string(from: normalizedEnd)).csv"
    }

    private var canExport: Bool {
        normalizedStart <= normalizedEnd && !filteredSets.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                presetSection
                if rangePreset == .custom {
                    customRangeSection
                }
                previewSection
                actionSection
            }
            .navigationTitle("history.export.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .onChange(of: rangePreset) { _, newValue in
                applyPreset(newValue)
            }
            .onChange(of: fromDate) { _, _ in
                prepareExport()
            }
            .onChange(of: toDate) { _, _ in
                prepareExport()
            }
            .onAppear {
                applyPreset(rangePreset)
                prepareExport()
            }
            .alert("history.export.errorTitle".localized, isPresented: $exportError) {
                Button("common.done".localized, role: .cancel) {}
            } message: {
                Text("history.export.errorMessage".localized)
            }
        }
    }

    private var presetSection: some View {
        Section("history.export.range".localized) {
            Picker("history.export.range".localized, selection: $rangePreset) {
                ForEach(ExportRangePreset.allCases) { preset in
                    Text(preset.titleKey.localized).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var customRangeSection: some View {
        Section("history.export.customRange".localized) {
            DatePicker("history.export.from".localized, selection: $fromDate, displayedComponents: .date)
            DatePicker("history.export.to".localized, selection: $toDate, displayedComponents: .date)
        }
    }

    private var previewSection: some View {
        Section("history.export.preview".localized) {
            HStack {
                Label("history.export.sets".localized, systemImage: "number")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(filteredSets.filter { $0.exercise?.isStrength == true }.count)")
                    .fontWeight(.semibold)
            }

            HStack {
                Label("history.cardioSessions".localized, systemImage: "heart.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(filteredSets.filter { $0.exercise?.isCardio == true }.count)")
                    .fontWeight(.semibold)
            }

            HStack {
                Label("history.export.exercises".localized, systemImage: "dumbbell")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Set(filteredSets.compactMap { $0.exercise?.id }).count)")
                    .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
            if let url = exportedFileURL {
                ShareLink(item: url) {
                    Label("history.export.share".localized, systemImage: "square.and.arrow.up")
                }

                Button {
                    UIPasteboard.general.string = exportedCSV
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Label("history.export.copy".localized, systemImage: "doc.on.doc")
                }

                if copied {
                    Text("history.export.copied".localized)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("history.export.actions".localized)
        } footer: {
            Text("history.export.footer".localized)
        }
    }

    private func applyPreset(_ preset: ExportRangePreset) {
        let calendar = Calendar.current
        let end = defaultEndDate

        switch preset {
        case .last7Days:
            fromDate = calendar.date(byAdding: .day, value: -6, to: end) ?? end
            toDate = end
        case .last30Days:
            fromDate = calendar.date(byAdding: .day, value: -29, to: end) ?? end
            toDate = end
        case .all:
            fromDate = allSets
                .filter { $0.exercise != nil }
                .map(\.date)
                .min() ?? defaultStartDate
            toDate = end
        case .custom:
            if fromDate > toDate {
                fromDate = defaultStartDate
                toDate = defaultEndDate
            }
        }
    }

    private func prepareExport() {
        guard canExport else {
            exportedCSV = ""
            exportedFileURL = nil
            return
        }

        let csv = WorkoutHistoryCSVExporter.makeCSV(from: filteredSets)
        do {
            exportedCSV = csv
            exportedFileURL = try CSVDocumentWriter.writeCSVFile(content: csv, filename: exportFilename)
        } catch {
            exportError = true
        }
    }
}

private struct WeekSummaryHeaderView: View {
    let week: HistoryWeekSnapshot
    let cardioGoalMinutes: Int

    private var weekEnd: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar.date(byAdding: .day, value: 6, to: week.weekStart) ?? week.weekStart
    }

    private var totalSets: Int {
        week.totalSets
    }

    private var totalVolume: Double {
        week.totalVolume
    }

    private var totalTrainingDays: Int {
        week.days.count
    }

    private var cardioSessions: Int { week.cardioSessions }
    private var cardioMinutes: Int { week.cardioMinutes }
    private var goalMinutes: Int { max(1, cardioGoalMinutes) }
    private var progress: Double {
        min(Double(cardioMinutes) / Double(goalMinutes), 1)
    }
    private var remainingMinutes: Int { max(goalMinutes - cardioMinutes, 0) }
    private var isGoalReached: Bool { cardioMinutes >= goalMinutes }

    private var cardioSessionCountText: String {
        let key = cardioSessions == 1
            ? "history.cardioSessionsCount.one"
            : "history.cardioSessionsCount.other"
        return key.localized(with: cardioSessions)
    }

    private var weekRangeText: String {
        let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return "history.weekRange".localized(
            with: DateFormatters.monthDayLabel(for: week.weekStart, locale: locale),
            DateFormatters.monthDayLabel(for: weekEnd, locale: locale)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekRangeText)
                .font(AppTextStyle.captionStrong)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                Text("history.weekTrainingDays".localized(with: totalTrainingDays))
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)

                Text("history.sets".localized(with: totalSets))
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)

                Text("history.weekVolume".localized(with: Int(totalVolume)))
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)
            }

            cardioProgressCard
        }
        .textCase(nil)
        .padding(.top, 6)
    }

    private var cardioProgressCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Label("history.cardioGoal".localized, systemImage: "heart.circle.fill")
                    .font(AppTextStyle.captionStrong)
                    .foregroundStyle(.teal)
                    .lineLimit(1)

                Text(cardioSessionCountText)
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text("history.cardioProgress".localized(with: cardioMinutes, goalMinutes))
                    .font(AppTextStyle.captionStrong)
                    .foregroundStyle(isGoalReached ? .green : .primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ProgressView(value: progress)
                .tint(isGoalReached ? .green : .teal)

            HStack(spacing: 8) {
                Text(isGoalReached
                     ? "history.cardioGoalReached".localized
                     : "history.cardioRemaining".localized(with: remainingMinutes))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let averageHeartRate = week.averageCardioHeartRate {
                    Text("history.cardioAverageHeartRate".localized(with: averageHeartRate))
                        .foregroundStyle(.pink)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .font(AppTextStyle.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct DayRowView: View {
    let day: HistoryDaySnapshot

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var formattedDayLabel: String {
        let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return DateFormatters.historyDayLabel(for: day.date, locale: locale)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formattedDayLabel)
                        .font(AppTextStyle.sectionTitle)

                    if isToday {
                        Text("history.today".localized)
                            .font(AppTextStyle.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }
                }

                if !day.strengthSummaryText.isEmpty {
                    Text(day.strengthSummaryText)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }

                if !day.cardioSummaryText.isEmpty {
                    Label(day.cardioSummaryText, systemImage: "heart.fill")
                        .font(AppTextStyle.captionStrong)
                        .foregroundStyle(.teal)
                        .lineLimit(nil)
                }

                if !day.dayNote.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.top, 2)

                        Text(day.dayNote)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.orange.opacity(0.95))
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 1)
                }
            }

            Spacer()

            if day.setCount > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("history.sets".localized(with: day.setCount))
                        .font(AppTextStyle.body)

                    Text("\(Int(day.totalVolume)) kg")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(AppTextStyle.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 0)
    }
}

private struct HistorySummaryItemView: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.orange)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval {
        timeIntervalSince1970
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
