import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSet.date, order: .reverse) private var allSets: [WorkoutSet]
    @State private var languageManager = LanguageManager.shared

    @State private var selectedPeriod: TimePeriod = .week
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
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
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

    private var trainingDaysCount: Int {
        groupedByDay.count
    }

    private var totalVolume: Double {
        filteredSets.reduce(0) { $0 + $1.volume }
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

    private var periodPicker: some View {
        VStack(spacing: 8) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.localized).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack(spacing: 20) {
                VStack {
                    Text("\(trainingDaysCount)")
                        .font(AppTextStyle.metric)
                    Text("history.trainingDays".localized)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(String(format: "%.0f", totalVolume))
                        .font(AppTextStyle.metric)
                    Text("history.totalVolume".localized)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
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
            ForEach(groupedByDay, id: \.0) { date, sets in
                DayRowView(date: date, sets: sets)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDay = date
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
        case thisMonth
        case custom

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .last7Days: return "history.export.range.last7"
            case .last30Days: return "history.export.range.last30"
            case .thisMonth: return "history.export.range.thisMonth"
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
        return "liftlog_\(formatter.string(from: normalizedStart))_to_\(formatter.string(from: normalizedEnd)).csv"
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
            .onAppear {
                applyPreset(rangePreset)
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
            Button {
                prepareExport()
            } label: {
                Label("history.export.generate".localized, systemImage: "doc.text")
            }
            .disabled(!canExport)

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
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: end)
            fromDate = calendar.date(from: components) ?? end
            toDate = end
        case .custom:
            if fromDate > toDate {
                fromDate = defaultStartDate
                toDate = defaultEndDate
            }
        }
    }

    private func prepareExport() {
        guard canExport else { return }

        let csv = CSVExporter.makeCSV(from: filteredSets)
        do {
            let url = try CSVExporter.writeCSVFile(content: csv, filename: exportFilename)
            exportedCSV = csv
            exportedFileURL = url
        } catch {
            exportError = true
        }
    }
}

private enum CSVExporter {
    private static let header = [
        "date",
        "time",
        "exercise_name",
        "muscle_group",
        "exercise_type",
        "set_number",
        "weight_kg",
        "reps",
        "duration_seconds",
        "rir",
        "notes",
        "volume_kg"
    ].joined(separator: ",")

    static func makeCSV(from sets: [WorkoutSet]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        var lines: [String] = [header]

        for set in sets.sorted(by: { $0.date < $1.date }) {
            let exercise = set.exercise
            let row: [String] = [
                dateFormatter.string(from: set.date),
                timeFormatter.string(from: set.date),
                csvEscape(exercise?.displayName ?? ""),
                csvEscape(exercise?.localizedMuscleGroup ?? ""),
                csvEscape(exercise?.exerciseType ?? ""),
                "\(set.setNumber)",
                String(format: "%.2f", set.weightKg),
                "\(set.reps)",
                "\(set.durationSeconds)",
                set.rir.map(String.init) ?? "",
                csvEscape(set.notes),
                String(format: "%.2f", set.volume)
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    static func writeCSVFile(content: String, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // UTF-8 BOM improves Excel compatibility for Chinese text.
        var data = Data([0xEF, 0xBB, 0xBF])
        if let csvData = content.data(using: .utf8) {
            data.append(csvData)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(date, style: .date)
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

extension Date: @retroactive Identifiable {
    public var id: TimeInterval {
        timeIntervalSince1970
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
