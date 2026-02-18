import SwiftUI
import SwiftData

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allSets: [WorkoutSet]

    // Pre-selected exercise (for quick add)
    var preselectedExercise: Exercise?
    var prefilledWeight: Double?
    var prefilledReps: Int?

    @State private var selectedExercise: Exercise?
    @State private var selectedDate: Date = Date()
    @State private var weight: Double = 20.0
    @State private var reps: Int = 10
    @State private var durationSeconds: Int = 30
    @State private var rirSelection: Int = -1
    @State private var setNotes: String = ""
    @State private var showExerciseNotes: Bool = false
    @State private var searchText: String = ""
    @State private var justSaved: Bool = false
    @State private var savedSetNumber: Int = 0

    private var exerciseType: String {
        selectedExercise?.exerciseType ?? "weightReps"
    }

    private var filteredExercises: [Exercise] {
        let source: [Exercise]
        if searchText.isEmpty {
            source = exercises
        } else {
            source = exercises.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return source.sorted { lhs, rhs in
            switch (lhs.lastTrainedDate, rhs.lastTrainedDate) {
            case let (l?, r?):
                if l != r { return l < r } // long due first, short due last
                return lhs.displayName < rhs.displayName
            case (_?, nil):
                return true // ever trained before never trained
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.displayName < rhs.displayName
            }
        }
    }

    private func lastTrainedLabel(for exercise: Exercise) -> String {
        guard let lastTrained = exercise.lastTrainedDate else {
            return "addSet.neverTrained".localized
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(lastTrained) {
            return "addSet.lastTrainedTodayWithDays".localized
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return "addSet.lastTrainedWithRelative".localized(
            with: formatter.string(from: lastTrained),
            daysAgoText(for: lastTrained)
        )
    }

    private func daysAgoText(for date: Date) -> String {
        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: date)
        let toDay = calendar.startOfDay(for: Date())
        let days = max(0, calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0)

        if days == 1 {
            return "addSet.daysAgo.one".localized
        }
        return "addSet.daysAgo.other".localized(with: days)
    }

    private var neverTrainedCount: Int {
        filteredExercises.filter { $0.lastTrainedDate == nil }.count
    }

    private var trainedCount: Int {
        filteredExercises.count - neverTrainedCount
    }

    private var exerciseOrderingHint: String {
        if filteredExercises.isEmpty { return "" }
        return "addSet.orderingHint".localized(with: trainedCount, neverTrainedCount)
    }

    @ViewBuilder
    private var exerciseSearchSectionFooter: some View {
        if exerciseOrderingHint.isEmpty {
            EmptyView()
        } else {
            Text(exerciseOrderingHint)
        }
    }

    private var searchableExerciseSection: some View {
        Group {
            TextField("addSet.searchExercises".localized, text: $searchText)
                .textFieldStyle(.plain)

            ForEach(filteredExercises) { exercise in
                Button {
                    selectedExercise = exercise
                    showExerciseNotes = false
                    searchText = ""
                    applySuggestedDefaults(for: exercise)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.displayName)
                            Text(lastTrainedLabel(for: exercise))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !exercise.muscleGroup.isEmpty {
                            Text(exercise.localizedMuscleGroup)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var nextSetNumber: Int {
        guard let exercise = selectedExercise else { return 1 }
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: selectedDate)
        let targetDaySets = allSets.filter {
            $0.exercise?.id == exercise.id &&
            calendar.startOfDay(for: $0.date) == targetDay
        }
        return (targetDaySets.map { $0.setNumber }.max() ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            Form {
                // Success banner after saving
                if justSaved {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("addSet.savedSet".localized(with: savedSetNumber))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.green.opacity(0.1))
                }

                exerciseSection
                if exerciseType == "weightReps" {
                    weightSection
                }
                if exerciseType == "weightReps" || exerciseType == "repsOnly" {
                    repsSection
                }
                if exerciseType == "timeOnly" {
                    durationSection
                }
                rirSection
                dateSection
                notesSection
                summarySection
            }
            .navigationTitle("addSet.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("addSet.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button {
                        saveSet(andContinue: true)
                    } label: {
                        Label("addSet.saveAndAddAnother".localized, systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedExercise == nil)

                    Button {
                        saveSet(andContinue: false)
                    } label: {
                        Label("addSet.saveAndClose".localized, systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedExercise == nil)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.thinMaterial)
            }
            .onAppear {
                setupInitialValues()
            }
            .onChange(of: selectedDate) { _, _ in
                if let exercise = selectedExercise {
                    applySuggestedDefaults(for: exercise)
                }
            }
        }
    }

    private var dateSection: some View {
        Section("addSet.date".localized) {
            DatePicker(
                "addSet.date".localized,
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
        }
    }

    private func setupInitialValues() {
        if let exercise = preselectedExercise {
            selectedExercise = exercise
            applySuggestedDefaults(for: exercise)
            if let w = prefilledWeight {
                weight = w
            }
            if let r = prefilledReps {
                reps = r
            }
        }
    }

    private var exerciseSection: some View {
        Section {
            if let exercise = selectedExercise {
                HStack {
                    Text(exercise.displayName)
                        .font(.headline)

                    Button {
                        withAnimation {
                            showExerciseNotes.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(showExerciseNotes ? .orange : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(exercise.displayNotes.isEmpty)
                    .opacity(exercise.displayNotes.isEmpty ? 0.4 : 1)

                    Spacer()

                    // Only show change button if not preselected (quick add mode)
                    if preselectedExercise == nil {
                        Button("addSet.change".localized) {
                            selectedExercise = nil
                            showExerciseNotes = false
                        }
                        .font(.subheadline)
                    }
                }

                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.localizedMuscleGroup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if showExerciseNotes, !exercise.displayNotes.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.orange)
                            .padding(.top, 2)

                        Text(exercise.displayNotes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)
                }
            } else {
                searchableExerciseSection
            }
        } header: {
            Text("addSet.exercise".localized)
        } footer: {
            if selectedExercise == nil {
                exerciseSearchSectionFooter
            }
        }
    }

    private var notesSection: some View {
        Section("addSet.notes".localized) {
            TextField("addSet.addNote".localized, text: $setNotes, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var rirSection: some View {
        Section("addSet.rir".localized) {
            Picker("addSet.rir".localized, selection: $rirSelection) {
                Text("common.noneShort".localized).tag(-1)
                Text("0").tag(0)
                Text("1").tag(1)
                Text("2").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private var weightSection: some View {
        Section("addSet.weight".localized) {
            HStack {
                Button {
                    weight = max(0, weight - 2.5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Spacer()

                TextField("Weight", value: $weight, format: .number)
                    .font(.title.bold())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)

                Text("kg")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    weight += 2.5
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }

    private var repsSection: some View {
        Section("addSet.reps".localized) {
            HStack {
                Button {
                    reps = max(1, reps - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Spacer()

                TextField("Reps", value: $reps, format: .number)
                    .font(.title.bold())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)

                Text("common.reps".localized)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    reps += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }

    private var durationSection: some View {
        Section("common.duration".localized) {
            HStack {
                Button {
                    durationSeconds = max(5, durationSeconds - 5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(WorkoutSet.formatDuration(durationSeconds))
                    .font(.title.bold())
                    .frame(width: 100)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    durationSeconds += 5
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if selectedExercise != nil {
            Section {
                HStack {
                    Text("addSet.setNumber".localized(with: nextSetNumber))
                    Spacer()
                    if exerciseType == "timeOnly" {
                        Text(WorkoutSet.formatDuration(durationSeconds))
                            .foregroundStyle(.secondary)
                    } else if exerciseType == "repsOnly" {
                        Text("\(reps) \("common.reps".localized)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("addSet.volumeLabel".localized(with: Int(weight * Double(reps))))
                            .foregroundStyle(.secondary)
                    }
                }

                if exerciseType == "weightReps" {
                    HStack {
                        Text("addSet.est1RM".localized)
                        Spacer()
                        Text("\(String(format: "%.1f", weight * (1 + Double(reps) / 30))) kg")
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                    }
                }

                if rirSelection >= 0 {
                    HStack {
                        Text("addSet.rir".localized)
                        Spacer()
                        Text("RIR \(rirSelection)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("addSet.summary".localized)
            }
        }
    }

    private func applySuggestedDefaults(for exercise: Exercise) {
        let currentDaySets = targetDaySets(for: exercise, on: selectedDate)

        if let latestTodaySet = currentDaySets.sorted(by: WorkoutSet.trainingOrder(lhs:rhs:)).last {
            weight = latestTodaySet.weightKg
            reps = latestTodaySet.reps > 0 ? latestTodaySet.reps : reps
            durationSeconds = latestTodaySet.durationSeconds > 0 ? latestTodaySet.durationSeconds : durationSeconds
            rirSelection = latestTodaySet.rir ?? -1
            return
        }

        if let previousStartSet = previousDayStartingSet(for: exercise, before: selectedDate) {
            weight = previousStartSet.weightKg
            reps = previousStartSet.reps > 0 ? previousStartSet.reps : reps
            durationSeconds = previousStartSet.durationSeconds > 0 ? previousStartSet.durationSeconds : durationSeconds
            rirSelection = previousStartSet.rir ?? -1
            return
        }

        if let lastWeight = exercise.lastWeight {
            weight = lastWeight
        }
        rirSelection = -1
    }

    private func targetDaySets(for exercise: Exercise, on date: Date) -> [WorkoutSet] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return allSets.filter {
            $0.exercise?.id == exercise.id && calendar.startOfDay(for: $0.date) == targetDay
        }
    }

    private func previousDayStartingSet(for exercise: Exercise, before date: Date) -> WorkoutSet? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let previousSets = exercise.workoutSets
            .filter { calendar.startOfDay(for: $0.date) < targetDay }
            .sorted { $0.date > $1.date }

        guard let recentPrevious = previousSets.first else { return nil }
        let previousDay = calendar.startOfDay(for: recentPrevious.date)
        return previousSets
            .filter { calendar.startOfDay(for: $0.date) == previousDay }
            .sorted(by: WorkoutSet.trainingOrder(lhs:rhs:))
            .first
    }

    private func saveSet(andContinue: Bool) {
        guard let exercise = selectedExercise else { return }

        let setNumber = nextSetNumber

        let saveWeight: Double = exercise.isWeightReps ? weight : 0
        let saveReps: Int = exercise.isTimeOnly ? 0 : reps
        let saveDuration: Int = exercise.isTimeOnly ? durationSeconds : 0
        let saveDate = combinedDateWithCurrentTime(selectedDate)

        let workoutSet = WorkoutSet(
            exercise: exercise,
            date: saveDate,
            weightKg: saveWeight,
            reps: saveReps,
            durationSeconds: saveDuration,
            setNumber: setNumber,
            rir: rirSelection < 0 ? nil : rirSelection,
            notes: setNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(workoutSet)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if andContinue {
            // Show success message and reset for next set
            savedSetNumber = setNumber
            justSaved = true
            setNotes = "" // Clear notes for next set

            // Hide success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    justSaved = false
                }
            }
        } else {
            dismiss()
        }
    }

    private func combinedDateWithCurrentTime(_ day: Date) -> Date {
        let calendar = Calendar.current
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
        dayComponents.hour = timeComponents.hour
        dayComponents.minute = timeComponents.minute
        dayComponents.second = timeComponents.second
        return calendar.date(from: dayComponents) ?? day
    }
}

#Preview {
    AddSetView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
