import SwiftUI
import SwiftData
import UIKit

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
                    overview
                        .padding()
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

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(historySummaryHeading(title: "history.overview".localized,
                                       trainingDays: snapshot.trainingDaysCount))
                .font(AppTextStyle.sectionTitle)
            Divider()
            HistoryTotalsView(totals: snapshot.totals,
                              strengthSessions: snapshot.strengthSessions,
                              cardioGoalMinutes: settingsManager.weeklyCardioGoalMinutes)
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

    private var historyList: some View {
        List {
            Section {
                overview
                    .padding(.vertical, 4)
            }
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

    private var weekRangeText: String {
        let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return "history.weekRange".localized(
            with: DateFormatters.monthDayLabel(for: week.weekStart, locale: locale),
            DateFormatters.monthDayLabel(for: weekEnd, locale: locale)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(historySummaryHeading(title: weekRangeText, trainingDays: week.trainingDaysCount))
                .font(AppTextStyle.sectionTitle)
            HistoryTotalsView(totals: week.totals,
                              strengthSessions: week.strengthSessions,
                              cardioGoalMinutes: cardioGoalMinutes)
        }
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        .textCase(nil)
        .padding(.vertical, 6)
    }
}

private func historySummaryHeading(title: String, trainingDays: Int) -> String {
    let suffix = trainingDays == 1 ? "one" : "other"
    return "history.summaryHeading.\(suffix)".localized(with: title, trainingDays)
}

/// Shared by the selected-period overview and weekly summaries; only their scope differs.
private struct HistoryTotalsView: View {
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 22
    let totals: TrainingTotals
    let strengthSessions: Int
    let cardioGoalMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryRow(.strength, text: "history.strengthSummary.\(strengthSessions == 1 ? "one" : "other")".localized(
                with: strengthSessions, totals.strengthSets, Int(totals.strengthVolume)
            ))
            summaryRow(.cardio, text: localizedCardioGoalSummary(
                sessions: totals.cardioSessions,
                minutes: totals.cardioMinutes,
                goalMinutes: max(1, cardioGoalMinutes),
                averageHeartRate: totals.averageCardioHeartRate
            ))
            if totals.rehabilitationSets > 0 {
                summaryRow(.rehabilitation, text: "training.rehabilitationSets".localized(with: totals.rehabilitationSets))
            }
        }
        .font(AppTextStyle.bodyStrong)
        .foregroundStyle(.primary)
    }

    private func summaryRow(_ category: ExerciseCategory, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
    goalMinutes: Int,
    averageHeartRate: Int?
) -> String {
    let suffix = sessions == 1 ? "one" : "other"
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

                ForEach(ExerciseCategory.allCases) { category in
                    let summary = day.summaryText(for: category)
                    if !summary.isEmpty {
                        TrainingCategorySummary(category: category, text: summary)
                    }
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

extension Date: @retroactive Identifiable {
    public var id: TimeInterval {
        timeIntervalSince1970
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
