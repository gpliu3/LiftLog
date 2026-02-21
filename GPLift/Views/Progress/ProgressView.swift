import SwiftUI
import SwiftData
import Charts

struct ProgressChartView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var languageManager = LanguageManager.shared

    @State private var selectedExercise: Exercise?
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var now = Date()

    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case allTime = "All"

        var months: Int? {
            switch self {
            case .oneMonth: return 1
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .oneYear: return 12
            case .allTime: return nil
            }
        }

        var localized: String {
            switch self {
            case .oneMonth: return "timeRange.1M".localized
            case .threeMonths: return "timeRange.3M".localized
            case .sixMonths: return "timeRange.6M".localized
            case .oneYear: return "timeRange.1Y".localized
            case .allTime: return "timeRange.all".localized
            }
        }
    }

    private var startDate: Date? {
        guard let months = selectedTimeRange.months else { return nil }
        return Calendar.current.date(byAdding: .month, value: -months, to: now)
    }

    private var filteredSets: [WorkoutSet] {
        guard let exercise = selectedExercise else { return [] }
        var sets = exercise.workoutSets

        if let start = startDate {
            sets = sets.filter { $0.date >= start }
        }

        return sets.sorted { $0.date < $1.date }
    }

    private var currentExerciseType: String {
        selectedExercise?.exerciseType ?? "weightReps"
    }

    private var sessionData: [(Date, Double, Double, Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSets) { set in
            calendar.startOfDay(for: set.date)
        }

        return grouped.map { (date, sets) in
            let volume = sets.reduce(0) { $0 + $1.volume }
            let maxWeight = sets.map { $0.weightKg }.max() ?? 0
            let best1RM = sets.map { $0.estimatedOneRepMax }.max() ?? 0
            return (date, volume, maxWeight, best1RM)
        }.sorted { $0.0 < $1.0 }
    }

    // Duration session data: (date, maxDuration)
    private var durationSessionData: [(Date, Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSets) { set in
            calendar.startOfDay(for: set.date)
        }
        return grouped.map { (date, sets) in
            let maxDuration = sets.map { $0.durationSeconds }.max() ?? 0
            return (date, maxDuration)
        }.sorted { $0.0 < $1.0 }
    }

    // Reps session data: (date, totalReps)
    private var repsSessionData: [(Date, Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSets) { set in
            calendar.startOfDay(for: set.date)
        }
        return grouped.map { (date, sets) in
            let totalReps = sets.reduce(0) { $0 + $1.reps }
            return (date, totalReps)
        }.sorted { $0.0 < $1.0 }
    }

    private var personalRecord: Double? {
        filteredSets.map { $0.weightKg }.max()
    }

    private var bestDuration: Int? {
        filteredSets.map { $0.durationSeconds }.max()
    }

    private var bestRepsInSession: Int? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSets) { calendar.startOfDay(for: $0.date) }
        return grouped.values.map { sets in
            sets.reduce(0) { $0 + $1.reps }
        }.max()
    }

    private var bestVolume: Double? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSets) { calendar.startOfDay(for: $0.date) }
        return grouped.values.map { sets in
            sets.reduce(0) { $0 + $1.volume }
        }.max()
    }

    private var totalLifetimeVolume: Double {
        selectedExercise?.workoutSets.reduce(0) { $0 + $1.volume } ?? 0
    }

    private var totalLifetimeReps: Int {
        selectedExercise?.workoutSets.reduce(0) { $0 + $1.reps } ?? 0
    }

    private var averageReps: Double {
        guard !filteredSets.isEmpty else { return 0 }
        return Double(filteredSets.map { $0.reps }.reduce(0, +)) / Double(filteredSets.count)
    }

    private var sessionsPerWeek: Double {
        guard !filteredSets.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(filteredSets.map { calendar.startOfDay(for: $0.date) })

        guard let earliest = uniqueDays.min(),
              let latest = uniqueDays.max() else { return 0 }

        let weeks = max(1, calendar.dateComponents([.weekOfYear], from: earliest, to: latest).weekOfYear ?? 1)
        return Double(uniqueDays.count) / Double(weeks)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "progress.noExercises".localized,
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("progress.noExercisesDescription".localized)
                    )
                } else {
                    exercisePicker
                    timeRangePicker

                    if selectedExercise == nil {
                        ContentUnavailableView(
                            "progress.selectExercise".localized,
                            systemImage: "hand.tap",
                            description: Text("progress.selectExerciseDescription".localized)
                        )
                    } else if filteredSets.isEmpty {
                        ContentUnavailableView(
                            "progress.noData".localized,
                            systemImage: "chart.bar.xaxis",
                            description: Text("progress.noDataDescription".localized)
                        )
                    } else {
                        progressContent
                    }
                }
            }
            .navigationTitle("progress.title".localized)
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
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

    private var exercisePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(exercises) { exercise in
                    Button {
                        selectedExercise = exercise
                    } label: {
                        Text(exercise.displayName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedExercise?.id == exercise.id
                                    ? Color.orange
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                selectedExercise?.id == exercise.id
                                    ? .white
                                    : .primary
                            )
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.localized).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var progressContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if currentExerciseType == "weightReps" {
                    volumeChart
                    maxWeightChart
                    oneRMChart
                    weightRepsStatsCards
                } else if currentExerciseType == "timeOnly" {
                    durationChart
                    timeOnlyStatsCards
                } else {
                    repsChart
                    repsOnlyStatsCards
                }
            }
            .padding()
        }
    }

    // MARK: - Weight × Reps Charts

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.volumePerSession".localized)
                .font(.headline)

            Chart(sessionData, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value("Volume", item.1)
                )
                .foregroundStyle(Color.orange)

                AreaMark(
                    x: .value("Date", item.0),
                    y: .value("Volume", item.1)
                )
                .foregroundStyle(Color.orange.opacity(0.1))

                PointMark(
                    x: .value("Date", item.0),
                    y: .value("Volume", item.1)
                )
                .foregroundStyle(Color.orange)
            }
            .frame(height: 200)
            .chartYAxisLabel("kg")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var maxWeightChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.maxWeightPerSession".localized)
                .font(.headline)

            Chart(sessionData, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value("Weight", item.2)
                )
                .foregroundStyle(Color.blue)

                PointMark(
                    x: .value("Date", item.0),
                    y: .value("Weight", item.2)
                )
                .foregroundStyle(Color.blue)
            }
            .frame(height: 200)
            .chartYAxisLabel("kg")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var oneRMChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.estimated1RM".localized)
                .font(.headline)

            Chart(sessionData, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value("1RM", item.3)
                )
                .foregroundStyle(Color.green)

                PointMark(
                    x: .value("Date", item.0),
                    y: .value("1RM", item.3)
                )
                .foregroundStyle(Color.green)
            }
            .frame(height: 200)
            .chartYAxisLabel("kg")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Time Only Chart

    private var durationChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.durationPerSession".localized)
                .font(.headline)

            Chart(durationSessionData, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value("Duration", item.1)
                )
                .foregroundStyle(Color.orange)

                AreaMark(
                    x: .value("Date", item.0),
                    y: .value("Duration", item.1)
                )
                .foregroundStyle(Color.orange.opacity(0.1))

                PointMark(
                    x: .value("Date", item.0),
                    y: .value("Duration", item.1)
                )
                .foregroundStyle(Color.orange)
            }
            .frame(height: 200)
            .chartYAxisLabel("common.seconds".localized)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Reps Only Chart

    private var repsChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.repsPerSession".localized)
                .font(.headline)

            Chart(repsSessionData, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value("Reps", item.1)
                )
                .foregroundStyle(Color.orange)

                AreaMark(
                    x: .value("Date", item.0),
                    y: .value("Reps", item.1)
                )
                .foregroundStyle(Color.orange.opacity(0.1))

                PointMark(
                    x: .value("Date", item.0),
                    y: .value("Reps", item.1)
                )
                .foregroundStyle(Color.orange)
            }
            .frame(height: 200)
            .chartYAxisLabel("common.reps".localized)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Stats Cards

    private var weightRepsStatsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            if let pr = personalRecord {
                StatCard(title: "progress.personalRecord".localized, value: "\(String(format: "%.1f", pr)) kg", icon: "trophy.fill", color: .yellow)
            }

            if let best = bestVolume {
                StatCard(title: "progress.bestVolume".localized, value: "\(Int(best)) kg", icon: "flame.fill", color: .orange)
            }

            StatCard(title: "progress.lifetimeVolume".localized, value: "\(Int(totalLifetimeVolume)) kg", icon: "sum", color: .blue)
            StatCard(title: "progress.avgReps".localized, value: String(format: "%.1f", averageReps), icon: "repeat", color: .purple)
            StatCard(title: "progress.sessionsPerWeek".localized, value: String(format: "%.1f", sessionsPerWeek), icon: "calendar", color: .green)
            StatCard(title: "progress.totalSets".localized, value: "\(filteredSets.count)", icon: "number", color: .indigo)
        }
    }

    private var timeOnlyStatsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            if let best = bestDuration, best > 0 {
                StatCard(title: "progress.bestDuration".localized, value: WorkoutSet.formatDuration(best), icon: "trophy.fill", color: .yellow)
            }

            StatCard(title: "progress.sessionsPerWeek".localized, value: String(format: "%.1f", sessionsPerWeek), icon: "calendar", color: .green)
            StatCard(title: "progress.totalSets".localized, value: "\(filteredSets.count)", icon: "number", color: .indigo)
        }
    }

    private var repsOnlyStatsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            if let best = bestRepsInSession {
                StatCard(title: "progress.bestReps".localized, value: "\(best)", icon: "trophy.fill", color: .yellow)
            }

            StatCard(title: "progress.totalReps".localized, value: "\(totalLifetimeReps)", icon: "sum", color: .blue)
            StatCard(title: "progress.avgReps".localized, value: String(format: "%.1f", averageReps), icon: "repeat", color: .purple)
            StatCard(title: "progress.sessionsPerWeek".localized, value: String(format: "%.1f", sessionsPerWeek), icon: "calendar", color: .green)
            StatCard(title: "progress.totalSets".localized, value: "\(filteredSets.count)", icon: "number", color: .indigo)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ProgressChartView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
