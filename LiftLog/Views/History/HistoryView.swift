import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSet.date, order: .reverse) private var allSets: [WorkoutSet]
    @State private var languageManager = LanguageManager.shared

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedDay: Date?

    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"

        var localized: String {
            switch self {
            case .week: return "history.week".localized
            case .month: return "history.month".localized
            }
        }
    }

    private var startDate: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }

    private var filteredSets: [WorkoutSet] {
        allSets.filter { $0.date >= startDate }
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
            .sheet(item: $selectedDay) { date in
                DayDetailView(date: date)
            }
        }
        .id(languageManager.currentLanguage)
    }

    private var periodPicker: some View {
        VStack(spacing: 16) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.localized).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack(spacing: 32) {
                VStack {
                    Text("\(trainingDaysCount)")
                        .font(.title.bold())
                    Text("history.trainingDays".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(String(format: "%.0f", totalVolume))
                        .font(.title.bold())
                    Text("history.totalVolume".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.top)
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
    }
}

struct DayRowView: View {
    let date: Date
    let sets: [WorkoutSet]

    private var exerciseNames: [String] {
        let names = Set(sets.compactMap { $0.exercise?.name })
        return Array(names).sorted()
    }

    private var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(date, style: .date)
                        .font(.headline)

                    if isToday {
                        Text("history.today".localized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }
                }

                Text(exerciseNames.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("history.sets".localized(with: sets.count))
                    .font(.subheadline)

                Text("\(Int(totalVolume)) kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
