import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSet.date, order: .reverse) private var allSets: [WorkoutSet]
    @Query private var dailyLogs: [DailyLog]
    @State private var languageManager = LanguageManager.shared
    @State private var settingsManager = SettingsManager.shared
    @State private var healthStore = HealthDataStore.shared

    @State private var selectedPeriod: TimePeriod = .week
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
                    set.exercise?.isKneeLoad == true ? "k" : "",
                    "\(set.averageHeartRate ?? 0)",
                    "\(set.maxHeartRate ?? 0)",
                    "\(set.setNumber)",
                    set.dayNote ?? ""
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        ].joined(separator: "|")
    }

    private var visibleHealth: [Date: DailyHealth] {
        guard healthStore.isEnabled else { return [:] }
        let firstDay = Calendar.current.startOfDay(for: startDate)
        return healthStore.metrics.filter { $0.key >= firstDay && !$0.value.isEmpty }
    }

    private var healthRefreshKey: String {
        "\(healthStore.isEnabled)-\(Calendar.current.startOfDay(for: startDate).timeIntervalSinceReferenceDate)-\(Calendar.current.startOfDay(for: now).timeIntervalSinceReferenceDate)"
    }

    private var showsHealthHint: Bool {
        healthStore.isAvailable && !healthStore.isEnabled && !healthStore.isHintDismissed
    }

    var body: some View {
        let health = visibleHealth
        let checkIns = DailyLog.checkInsByDay(dailyLogs)
        let timeline = HistoryTimeline.build(
            snapshot: snapshot,
            health: health,
            checkInDays: Set(checkIns.filter { !$0.value.isEmpty }.keys),
            startDate: startDate,
            today: now
        )

        return NavigationStack {
            VStack(spacing: 0) {
                periodPicker

                if timeline.isEmpty {
                    overview(health: health)
                        .padding()
                    emptyState
                } else {
                    historyList(timeline: timeline, health: health, checkIns: checkIns)
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
                    checkIns: DailyLog.checkInsByDay(dailyLogs),
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
                Task { await healthStore.refresh(from: startDate) }
            }
        }
        .task(id: healthRefreshKey) {
            await healthStore.refresh(from: startDate)
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
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.localized).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGroupedBackground))
    }

    /// In Week mode the overview already covers exactly the current week, so it takes the
    /// week's date range as its title and the list drops the duplicate week header.
    private var overviewTitle: String {
        selectedPeriod == .week ? historyWeekRangeText(weekStart: now.startOfWeek) : "history.overview".localized
    }

    private func overview(health: [Date: DailyHealth]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(historySummaryHeading(title: overviewTitle,
                                       trainingDays: snapshot.trainingDaysCount))
                .font(AppTextStyle.sectionTitle)
            Divider()
            // The Cardio goal is weekly, so Month/All totals show achieved minutes only.
            HistoryTotalsView(totals: snapshot.totals,
                              strengthSessions: snapshot.strengthSessions,
                              cardioGoalMinutes: selectedPeriod == .week ? settingsManager.weeklyCardioGoalMinutes : nil,
                              health: HealthAverages(days: Array(health.values)))
        }
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "history.noWorkouts".localized,
            systemImage: "calendar.badge.exclamationmark",
            description: Text("history.noWorkoutsDescription".localized)
        )
    }

    private func historyList(
        timeline: HistoryTimeline,
        health: [Date: DailyHealth],
        checkIns: [Date: DailyCheckIn]
    ) -> some View {
        List {
            Section {
                overview(health: health)
                    .padding(.vertical, 4)
            }
            if showsHealthHint {
                Section {
                    HealthConnectHintRow(store: healthStore)
                }
            }
            ForEach(timeline.weeks) { week in
                Section {
                    ForEach(week.rows) { row in
                        switch row {
                        case .logged(let day):
                            DayRowView(day: day, health: health[day.date], checkIn: checkIns[day.date])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDay = day.date
                                }
                        case .rest(let date):
                            RestDayRowView(date: date, health: health[date] ?? DailyHealth(), checkIn: checkIns[date])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDay = date
                                }
                        }
                    }
                } header: {
                    if selectedPeriod != .week {
                        WeekSummaryHeaderView(
                            week: week.summary,
                            cardioGoalMinutes: settingsManager.weeklyCardioGoalMinutes,
                            health: HealthAverages(days: week.rows.compactMap { health[$0.date] })
                        )
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 24)
    }
}

private struct HistoryExportView: View {
    @Environment(\.dismiss) private var dismiss

    let allSets: [WorkoutSet]
    var checkIns: [Date: DailyCheckIn] = [:]
    let defaultStartDate: Date
    let defaultEndDate: Date

    @State private var rangePreset: ExportRangePreset = .last30Days
    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var exportedCSV = ""
    @State private var exportedFileURL: URL?
    @State private var dailySummaryFileURL: URL?
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

    init(allSets: [WorkoutSet], checkIns: [Date: DailyCheckIn] = [:], defaultStartDate: Date, defaultEndDate: Date) {
        self.allSets = allSets
        self.checkIns = checkIns
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
        let totals = TrainingTotals(sets: filteredSets)
        return Section("history.export.preview".localized) {
            HStack {
                Label("history.export.sets".localized, systemImage: "number")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totals.strengthSets)")
                    .fontWeight(.semibold)
            }

            HStack {
                Label("history.cardioSessions".localized, systemImage: "heart.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totals.cardioSessions)")
                    .fontWeight(.semibold)
            }

            if totals.rehabilitationSets > 0 {
                HStack {
                    Label("exerciseCategory.rehabilitation".localized, systemImage: ExerciseCategory.rehabilitation.systemImage)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("history.sets".localized(with: totals.rehabilitationSets))
                        .fontWeight(.semibold)
                }
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

                if let dailyURL = dailySummaryFileURL {
                    ShareLink(item: dailyURL) {
                        Label("history.export.shareDaily".localized, systemImage: "calendar")
                    }
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
            Text("history.export.footer".localized + "\n" + "history.export.dailyFooter".localized)
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
        dailySummaryFileURL = nil
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

        // Health values are read for the export range only; without Health the file still
        // lists each day's training totals.
        let start = normalizedStart
        let end = normalizedEnd
        let setsByDay = Dictionary(grouping: filteredSets) { Calendar.current.startOfDay(for: $0.date) }
        let training = setsByDay.mapValues { TrainingTotals(sets: $0) }
        let rangeCheckIns = checkIns.filter { $0.key >= start && $0.key <= end }
        // A check-in note wins; days without one keep the older note saved with their sets.
        var notes = setsByDay.mapValues { sets in sets.first.map { WorkoutSet.dayNote(for: $0.date, in: sets) } ?? "" }
        for (day, checkIn) in rangeCheckIns { notes[day] = checkIn.trimmedNote }
        let kneeLoadDays = Set(setsByDay.filter { $0.value.contains { $0.exercise?.isKneeLoad == true } }.keys)
        let filename = exportFilename.replacingOccurrences(of: "gplift_", with: "gplift_daily_")
        Task {
            let health = await HealthDataStore.shared.refresh(from: start, to: end)
            guard start == normalizedStart, end == normalizedEnd else { return }
            let dailyCSV = DailySummaryCSVExporter.makeCSV(
                training: training,
                health: health,
                checkIns: rangeCheckIns,
                notes: notes,
                kneeLoadDays: kneeLoadDays
            )
            dailySummaryFileURL = try? CSVDocumentWriter.writeCSVFile(content: dailyCSV, filename: filename)
        }
    }
}

private struct WeekSummaryHeaderView: View {
    let week: HistoryWeekSnapshot
    let cardioGoalMinutes: Int
    var health = HealthAverages(days: [])

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(historySummaryHeading(title: historyWeekRangeText(weekStart: week.weekStart),
                                       trainingDays: week.trainingDaysCount))
                .font(AppTextStyle.subheadlineStrong)
            if week.days.isEmpty {
                // A week with rest days only: training totals would be a row of zeros.
                HealthAveragesRow(health: health)
                    .font(AppTextStyle.footnote)
            } else {
                HistoryTotalsView(totals: week.totals,
                                  strengthSessions: week.strengthSessions,
                                  cardioGoalMinutes: cardioGoalMinutes,
                                  health: health,
                                  font: AppTextStyle.footnote)
            }
        }
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        .textCase(nil)
        .padding(.vertical, 4)
    }
}

private func historyWeekRangeText(weekStart: Date) -> String {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
    return "history.weekRange".localized(
        with: DateFormatters.monthDayLabel(for: weekStart, locale: locale),
        DateFormatters.monthDayLabel(for: weekEnd, locale: locale)
    )
}

private func historySummaryHeading(title: String, trainingDays: Int) -> String {
    let suffix = trainingDays == 1 ? "one" : "other"
    return "history.summaryHeading.\(suffix)".localized(with: title, trainingDays)
}

/// Shared by the selected-period overview and weekly summaries; only their scope differs.
private struct HistoryTotalsView: View {
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 18
    let totals: TrainingTotals
    let strengthSessions: Int
    /// nil when the totals span more than one week, where a weekly target does not apply.
    let cardioGoalMinutes: Int?
    var health = HealthAverages(days: [])
    var font: Font = AppTextStyle.subheadline

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            summaryRow(.strength, text: "history.strengthSummary.\(strengthSessions == 1 ? "one" : "other")".localized(
                with: strengthSessions, totals.strengthSets, Int(totals.strengthVolume)
            ))
            summaryRow(.cardio, text: localizedCardioGoalSummary(
                sessions: totals.cardioSessions,
                minutes: totals.cardioMinutes,
                goalMinutes: cardioGoalMinutes.map { max(1, $0) },
                averageHeartRate: totals.averageCardioHeartRate
            ))
            if totals.rehabilitationSets > 0 {
                summaryRow(.rehabilitation, text: "training.rehabilitationSets".localized(with: totals.rehabilitationSets))
            }
            HealthAveragesRow(health: health)
        }
        .font(font)
        .foregroundStyle(.primary)
    }

    private func summaryRow(_ category: ExerciseCategory, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TrainingCategoryIcon(category: category)
                .foregroundStyle(category == .cardio ? Color.red : Color.orange)
                .frame(width: iconWidth)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func localizedCardioGoalSummary(
    sessions: Int,
    minutes: Int,
    goalMinutes: Int?,
    averageHeartRate: Int?
) -> String {
    let suffix = sessions == 1 ? "one" : "other"
    guard let goalMinutes else {
        if let averageHeartRate {
            return "history.cardioMinutesSummaryWithHeartRate.\(suffix)".localized(
                with: sessions,
                minutes,
                averageHeartRate
            )
        }
        return "history.cardioMinutesSummary.\(suffix)".localized(with: sessions, minutes)
    }
    if let averageHeartRate {
        return "history.cardioGoalSummaryWithHeartRate.\(suffix)".localized(
            with: sessions,
            minutes,
            goalMinutes,
            averageHeartRate
        )
    }
    return "history.cardioGoalSummary.\(suffix)".localized(
        with: sessions,
        minutes,
        goalMinutes
    )
}

/// "Avg 8,120 steps · 7h 05m sleep" for a week or the selected period; hidden without Health data.
private struct HealthAveragesRow: View {
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 18
    let health: HealthAverages

    private var text: String? {
        let steps = health.steps.map(HealthFormat.steps)
        let sleep = health.sleepMinutes.map(HealthFormat.sleep(minutes:))
        switch (steps, sleep) {
        case let (steps?, sleep?): return "health.averageSummary.both".localized(with: steps, sleep)
        case let (steps?, nil): return "health.averageSummary.steps".localized(with: steps)
        case let (nil, sleep?): return "health.averageSummary.sleep".localized(with: sleep)
        case (nil, nil): return nil
        }
    }

    var body: some View {
        if let text {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: health.steps != nil ? "figure.walk" : "bed.double.fill")
                    .foregroundStyle(health.steps != nil ? Color.green : Color.indigo)
                    .frame(width: iconWidth)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
        }
    }
}

/// One-time, dismissible invitation shown until Health is connected.
private struct HealthConnectHintRow: View {
    let store: HealthDataStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .font(.title3)
                .foregroundStyle(.pink)
            Text("health.hint.title".localized)
                .font(AppTextStyle.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("health.hint.connect".localized) {
                Task { await store.enable() }
            }
            .font(AppTextStyle.footnote.weight(.semibold))
            .buttonStyle(.borderless)
            Button {
                store.isHintDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(AppTextStyle.caption2Strong)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .tint(Color(.tertiaryLabel))
            .accessibilityLabel("common.cancel".localized)
        }
    }
}

/// A day without logged training that still has steps, sleep or a knee check-in.
/// Tapping it opens the day so the check-in can be added or corrected.
private struct RestDayRowView: View {
    let date: Date
    let health: DailyHealth
    var checkIn: DailyCheckIn?

    private var formattedDayLabel: String {
        let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return DateFormatters.historyDayLabel(for: date, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(formattedDayLabel)
                    .font(AppTextStyle.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("health.rest".localized)
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                Spacer(minLength: 4)
                HealthMetricsLine(health: health, showsStepsUnit: false)
            }
            if let checkIn {
                KneeCheckInSummaryLine(checkIn: checkIn)
                if !checkIn.trimmedNote.isEmpty {
                    DayNoteBubble(note: checkIn.trimmedNote)
                }
            }
        }
        .padding(.vertical, 1)
    }
}

private struct DayRowView: View {
    let day: HistoryDaySnapshot
    var health: DailyHealth?
    var checkIn: DailyCheckIn?

    /// A check-in note replaces the older note that was saved with the day's sets.
    private var note: String {
        checkIn.map(\.trimmedNote) ?? day.dayNote
    }

    /// Exercise summary with knee-load exercises picked out in their own colour.
    private func summaryText(_ summaries: [HistoryDaySnapshot.ExerciseSummary]) -> Text {
        summaries.enumerated().reduce(Text("")) { result, item in
            let separator = item.offset == 0 ? "" : ", "
            let piece = item.element.isKneeLoad
                ? Text(item.element.summaryText).foregroundStyle(Color.kneeLoad).fontWeight(.semibold)
                : Text(item.element.summaryText)
            return Text("\(result)\(separator)\(piece)")
        }
    }

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
                        .font(AppTextStyle.subheadlineStrong)

                    if isToday {
                        Text("history.today".localized)
                            .font(AppTextStyle.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }

                    if day.hasKneeLoad {
                        KneeLoadBadge()
                    }
                }

                ForEach(ExerciseCategory.allCases) { category in
                    let summaries = day.summaries(for: category)
                    if !summaries.isEmpty {
                        TrainingCategorySummary(category: category, content: summaryText(summaries))
                    }
                }

                if let checkIn {
                    KneeCheckInSummaryLine(checkIn: checkIn)
                }

                if let health, !health.isEmpty {
                    HealthMetricsLine(health: health)
                        .padding(.top, 1)
                }

                if !note.isEmpty {
                    DayNoteBubble(note: note)
                        .padding(.top, 1)
                }
            }

            Spacer()

            if day.setCount > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("history.sets".localized(with: day.setCount))
                        .font(AppTextStyle.subheadline)

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

extension Date: @retroactive Identifiable {
    public var id: TimeInterval {
        timeIntervalSince1970
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
