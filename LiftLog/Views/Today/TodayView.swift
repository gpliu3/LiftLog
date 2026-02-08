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
    @State private var editingExercise: Exercise?
    @State private var expandedNotes: Set<UUID> = []

    private var todaySets: [WorkoutSet] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allSets.filter {
            calendar.startOfDay(for: $0.date) == today && $0.exercise != nil
        }
    }

    private var groupedSets: [(Exercise, [WorkoutSet])] {
        let grouped = Dictionary(grouping: todaySets) { $0.exercise }
        return grouped.compactMap { (exercise, sets) in
            guard let exercise = exercise else { return nil }
            return (exercise, sets.sorted { $0.setNumber < $1.setNumber })
        }.sorted { $0.0.displayName < $1.0.displayName }
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
            .sheet(item: $editingExercise) { exercise in
                ExerciseEditView(exercise: exercise)
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
                    if expandedNotes.contains(exercise.id) {
                        NotesEditorRow(exercise: exercise)
                            .listRowBackground(Color.blue.opacity(0.05))
                    }

                    ForEach(sets) { set in
                        SetRowView(workoutSet: set, onDuplicate: {
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
                    ExerciseHeaderView(
                        exercise: exercise,
                        sets: sets,
                        hasNotes: !exercise.displayNotes.isEmpty,
                        onAddSet: {
                            quickAddSet(for: exercise, basedOn: sets.last)
                        },
                        onInfoTap: {
                            withAnimation {
                                if expandedNotes.contains(exercise.id) {
                                    expandedNotes.remove(exercise.id)
                                } else {
                                    expandedNotes.insert(exercise.id)
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    private func quickAddRow(for exercise: Exercise, sets: [WorkoutSet]) -> some View {
        let lastSet = sets.last

        return Button {
            quickAddSet(for: exercise, basedOn: lastSet)
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.orange)
                Text("today.addAnotherSet".localized)
                    .foregroundStyle(.orange)
                Spacer()
                if let lastSet = lastSet {
                    if exercise.isTimeOnly {
                        Text(lastSet.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if exercise.isRepsOnly {
                        Text("\(lastSet.reps) \("common.reps".localized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(String(format: "%.1f", lastSet.weightKg)) kg × \(lastSet.reps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listRowBackground(Color.orange.opacity(0.05))
    }

    /// Directly add a new set without showing modal
    private func quickAddSet(for exercise: Exercise, basedOn referenceSet: WorkoutSet?) {
        // Use exercise.workoutSets relationship (updated in-memory) instead of @Query
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayExerciseSets = exercise.workoutSets.filter {
            calendar.startOfDay(for: $0.date) == today
        }
        let nextSetNumber = (todayExerciseSets.map { $0.setNumber }.max() ?? 0) + 1

        // Determine values from reference set or previous day
        var weight: Double = exercise.isWeightReps ? 20.0 : 0
        var reps: Int = exercise.isTimeOnly ? 0 : 10
        var duration: Int = exercise.isTimeOnly ? 30 : 0

        if let ref = referenceSet {
            weight = ref.weightKg
            reps = ref.reps
            duration = ref.durationSeconds
        } else {
            if let previousSet = getPreviousDaySet(for: exercise) {
                weight = previousSet.weightKg
                reps = previousSet.reps
                duration = previousSet.durationSeconds
            } else if exercise.isWeightReps, let lastWeight = exercise.lastWeight {
                weight = lastWeight
            }
        }

        let workoutSet = WorkoutSet(
            exercise: exercise,
            date: Date(),
            weightKg: weight,
            reps: reps,
            durationSeconds: duration,
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
    let workoutSet: WorkoutSet
    var onDuplicate: (() -> Void)?
    var onEdit: (() -> Void)?

    private var exerciseType: String {
        workoutSet.exercise?.exerciseType ?? "weightReps"
    }

    var body: some View {
        HStack {
            Text("common.set".localized(with: workoutSet.setNumber))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            if exerciseType == "timeOnly" {
                Text(workoutSet.formattedDuration)
                    .fontWeight(.medium)
            } else if exerciseType == "repsOnly" {
                Text("\(workoutSet.reps) \("common.reps".localized)")
                    .fontWeight(.medium)
            } else {
                Text("\(String(format: "%.1f", workoutSet.weightKg)) kg")
                    .fontWeight(.medium)

                Text("×")
                    .foregroundStyle(.secondary)

                Text("\(workoutSet.reps) \("common.reps".localized)")
                    .fontWeight(.medium)

                Spacer()

                Text("\(Int(workoutSet.volume)) kg")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
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
    var hasNotes: Bool = false
    var onAddSet: (() -> Void)?
    var onInfoTap: (() -> Void)?

    private var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    private var subtitle: String {
        if exercise.isTimeOnly {
            let totalSeconds = sets.reduce(0) { $0 + $1.durationSeconds }
            return "\(sets.count) \("today.sets".localized) • \(WorkoutSet.formatDuration(totalSeconds))"
        } else if exercise.isRepsOnly {
            let totalReps = sets.reduce(0) { $0 + $1.reps }
            return "\(sets.count) \("today.sets".localized) • \(totalReps) \("common.reps".localized)"
        } else {
            return "\(sets.count) \("today.sets".localized) • \(Int(totalVolume)) kg"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(exercise.displayName)

                    if hasNotes, let onInfoTap = onInfoTap {
                        Button {
                            onInfoTap()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.body)
                                .foregroundStyle(.blue)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(subtitle)
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

struct NotesEditorRow: View {
    @Bindable var exercise: Exercise
    @State private var editableNotes: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $editableNotes)
                .font(.subheadline)
                .frame(minHeight: 50)
                .focused($isFocused)
                .onChange(of: editableNotes) {
                    exercise.notes = editableNotes
                }
        }
        .onAppear {
            // Load: use custom notes if set, otherwise default notes
            editableNotes = exercise.notes.isEmpty ? exercise.displayNotes : exercise.notes
        }
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
