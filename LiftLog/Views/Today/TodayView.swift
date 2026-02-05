import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSets: [WorkoutSet]
    @Query private var exercises: [Exercise]
    @State private var languageManager = LanguageManager.shared
    @State private var settingsManager = SettingsManager.shared

    @State private var showingAddSet = false
    @State private var editingSet: WorkoutSet?

    private var todaySets: [WorkoutSet] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allSets.filter { calendar.startOfDay(for: $0.date) == today }
    }

    private var groupedSets: [(Exercise, [WorkoutSet])] {
        let grouped = Dictionary(grouping: todaySets) { $0.exercise }
        return grouped.compactMap { (exercise, sets) in
            guard let exercise = exercise else { return nil }
            return (exercise, sets.sorted { $0.setNumber < $1.setNumber })
        }.sorted { $0.0.name < $1.0.name }
    }

    private var totalVolume: Double {
        todaySets.reduce(0) { $0 + $1.volume }
    }

    private var uniqueExercises: Int {
        Set(todaySets.compactMap { $0.exercise?.id }).count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if todaySets.isEmpty {
                    emptyState
                } else {
                    workoutList
                }

                addSetButton
            }
            .navigationTitle(todayDateString)
            .sheet(isPresented: $showingAddSet) {
                AddSetView()
            }
            .sheet(item: $editingSet) { set in
                EditSetView(workoutSet: set)
            }
        }
        .id(languageManager.currentLanguage)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "today.noWorkout".localized,
            systemImage: "figure.strengthtraining.traditional",
            description: Text("today.noWorkoutDescription".localized)
        )
    }

    private var workoutList: some View {
        List {
            statsCard

            ForEach(groupedSets, id: \.0.id) { exercise, sets in
                Section {
                    ForEach(sets) { set in
                        SetRowView(set: set, onDuplicate: {
                            quickAddSet(for: exercise, basedOn: set)
                        }, onEdit: {
                            editingSet = set
                        })
                    }
                    .onDelete { indexSet in
                        deleteSet(at: indexSet, from: sets)
                    }

                    // Quick add row at bottom of each exercise
                    quickAddRow(for: exercise, sets: sets)
                } header: {
                    ExerciseHeaderView(exercise: exercise, sets: sets) {
                        // Add another set for this exercise
                        quickAddSet(for: exercise, basedOn: sets.last)
                    }
                }
            }
        }
    }

    private func quickAddRow(for exercise: Exercise, sets: [WorkoutSet]) -> some View {
        let lastSet = sets.last
        let displayWeight = lastSet?.weightKg ?? 0
        let displayReps = lastSet?.reps ?? 0

        return Button {
            quickAddSet(for: exercise, basedOn: lastSet)
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.orange)
                Text("today.addAnotherSet".localized)
                    .foregroundStyle(.orange)
                Spacer()
                if lastSet != nil {
                    Text("\(String(format: "%.1f", displayWeight)) kg × \(displayReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(Color.orange.opacity(0.05))
    }

    /// Directly add a new set without showing modal
    private func quickAddSet(for exercise: Exercise, basedOn referenceSet: WorkoutSet?) {
        // Get today's sets for this exercise to determine next set number
        let todayExerciseSets = todaySets.filter { $0.exercise?.id == exercise.id }
        let nextSetNumber = todayExerciseSets.count + 1

        // Determine weight and reps from reference set or previous day
        var weight: Double = 20.0
        var reps: Int = 10

        if let ref = referenceSet {
            // Use the reference set (usually the last set)
            weight = ref.weightKg
            reps = ref.reps
        } else {
            // No sets today - look for previous day's data
            if let previousSet = getPreviousDaySet(for: exercise) {
                weight = previousSet.weightKg
                reps = previousSet.reps
            } else if let lastWeight = exercise.lastWeight {
                weight = lastWeight
            }
        }

        let workoutSet = WorkoutSet(
            exercise: exercise,
            date: Date(),
            weightKg: weight,
            reps: reps,
            setNumber: nextSetNumber
        )

        modelContext.insert(workoutSet)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Get the appropriate set from the previous day based on user preference
    private func getPreviousDaySet(for exercise: Exercise) -> WorkoutSet? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the most recent day before today with sets for this exercise
        let previousSets = exercise.workoutSets
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted { $0.date > $1.date }

        guard let mostRecentDate = previousSets.first?.date else { return nil }

        let mostRecentDay = calendar.startOfDay(for: mostRecentDate)
        let setsOnThatDay = previousSets
            .filter { calendar.startOfDay(for: $0.date) == mostRecentDay }
            .sorted { $0.setNumber < $1.setNumber }

        guard !setsOnThatDay.isEmpty else { return nil }

        // Return first or last based on preference
        switch settingsManager.defaultSetPreference {
        case .firstSet:
            return setsOnThatDay.first
        case .lastSet:
            return setsOnThatDay.last
        }
    }

    private var statsCard: some View {
        Section {
            HStack(spacing: 20) {
                StatItemView(
                    value: "\(todaySets.count)",
                    label: "today.sets".localized,
                    icon: "number"
                )

                Divider()

                StatItemView(
                    value: String(format: "%.0f", totalVolume),
                    label: "today.volume".localized,
                    icon: "scalemass"
                )

                Divider()

                StatItemView(
                    value: "\(uniqueExercises)",
                    label: "today.exercises".localized,
                    icon: "dumbbell"
                )
            }
            .padding(.vertical, 8)
        }
    }

    private var addSetButton: some View {
        Button {
            showingAddSet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .padding()
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return formatter.string(from: Date())
    }

    private func deleteSet(at offsets: IndexSet, from sets: [WorkoutSet]) {
        for index in offsets {
            modelContext.delete(sets[index])
        }
    }
}

struct SetRowView: View {
    let set: WorkoutSet
    var onDuplicate: (() -> Void)?
    var onEdit: (() -> Void)?

    var body: some View {
        HStack {
            Text("common.set".localized(with: set.setNumber))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            Text("\(String(format: "%.1f", set.weightKg)) kg")
                .fontWeight(.medium)

            Text("×")
                .foregroundStyle(.secondary)

            Text("\(set.reps) \("common.reps".localized)")
                .fontWeight(.medium)

            Spacer()

            Text("\(Int(set.volume)) kg")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onEdit?()
        }
        .swipeActions(edge: .leading) {
            Button {
                onDuplicate?()
            } label: {
                Label("today.duplicate".localized, systemImage: "doc.on.doc")
            }
            .tint(.orange)
        }
    }
}

struct ExerciseHeaderView: View {
    let exercise: Exercise
    let sets: [WorkoutSet]
    var onAddSet: (() -> Void)?

    private var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                Text("\(sets.count) \("today.sets".localized) • \(Int(totalVolume)) kg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onAddSet = onAddSet {
                Button {
                    onAddSet()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StatItemView: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.orange)

            Text(value)
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Make Exercise conform to Identifiable for sheet presentation
extension Exercise: Identifiable {}

// Make WorkoutSet conform to Identifiable for sheet presentation
extension WorkoutSet: Identifiable {}

#Preview {
    TodayView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
