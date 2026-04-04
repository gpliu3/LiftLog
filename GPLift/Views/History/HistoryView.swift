import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSet.date, order: .reverse) private var allSets: [WorkoutSet]
    @State private var languageManager = LanguageManager.shared

    @State private var selectedPeriod: TimePeriod = .all
    @State private var selectedDay: Date?
    @State private var showingExportSheet = false
    @State private var now = Date()

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

    private var filteredSets: [WorkoutSet] {
        allSets.filter { $0.date >= startDate && $0.exercise != nil }
    }

    private var groupedByDay: [(Date, [WorkoutSet])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSets) { set in
            calendar.startOfDay(for: set.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var groupedByWeek: [(weekStart: Date, days: [(Date, [WorkoutSet])])] {
        let grouped = Dictionary(grouping: groupedByDay) { day, _ in
            weekStart(for: day)
        }

        return grouped
            .map { weekStart, days in
                (
                    weekStart: weekStart,
                    days: days.sorted { $0.0 > $1.0 }
                )
            }
            .sorted { $0.weekStart > $1.weekStart }
    }

    private var trainingDaysCount: Int {
        groupedByDay.count
    }

    private var totalVolume: Double {
        filteredSets.reduce(0) { $0 + $1.volume }
    }

    private var totalSets: Int {
        filteredSets.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker

                if groupedByDay.isEmpty {
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

    private func mondayCalendar() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func weekStart(for date: Date) -> Date {
        let calendar = mondayCalendar()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.startOfDay(for: calendar.date(from: components) ?? date)
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
                    label: "history.trainingDays".localized
                )

                Divider()

                HistorySummaryItemView(
                    value: "\(totalSets)",
                    label: "history.totalSets".localized
                )

                Divider()

                HistorySummaryItemView(
                    value: String(format: "%.0f", totalVolume),
                    label: "history.totalVolume".localized
                )
            }
            .frame(height: 48)
            .padding(.horizontal, 14)
            .padding(.bottom, 0)
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
            ForEach(groupedByWeek, id: \.weekStart) { week in
                Section {
                    ForEach(week.days, id: \.0) { date, sets in
                        DayRowView(date: date, sets: sets)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDay = date
                            }
                    }
                } header: {
                    WeekSummaryHeaderView(weekStart: week.weekStart, groupedDays: week.days)
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
                Text("\(filteredSets.count)")
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
    let weekStart: Date
    let groupedDays: [(Date, [WorkoutSet])]

    private var allSets: [WorkoutSet] {
        groupedDays.flatMap(\.1)
    }

    private var weekEnd: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }

    private var totalSets: Int {
        allSets.count
    }

    private var totalVolume: Double {
        allSets.reduce(0) { $0 + $1.volume }
    }

    private var totalTrainingDays: Int {
        groupedDays.count
    }

    private var weekRangeText: String {
        let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return "history.weekRange".localized(
            with: DateFormatters.monthDayLabel(for: weekStart, locale: locale),
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
        }
        .textCase(nil)
        .padding(.top, 6)
    }
}

struct DayRowView: View {
    let date: Date
    let sets: [WorkoutSet]

    private var exerciseNames: [String] {
        let grouped = Dictionary(grouping: sets) { $0.exercise?.id }
        let ordered = grouped.compactMap { (_, groupedSets) -> (String, Date)? in
            guard let name = groupedSets.first?.exercise?.displayName else { return nil }
            let latest = groupedSets.map(\.date).max() ?? .distantPast
            return (name, latest)
        }
        return ordered.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var formattedDayLabel: String {
        let locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return DateFormatters.historyDayLabel(for: date, locale: locale)
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

                Text(exerciseNames.joined(separator: ", "))
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("history.sets".localized(with: sets.count))
                    .font(AppTextStyle.body)

                Text("\(Int(totalVolume)) kg")
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
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

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .center)
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
