import SwiftUI
import SwiftData

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    // Pre-selected exercise (for quick add)
    var preselectedExercise: Exercise?
    var prefilledWeight: Double?
    var prefilledReps: Int?

    @State private var selectedExercise: Exercise?
    @State private var selectedDate: Date = Date()
    @State private var weight: Double = 20.0
    @State private var weightKgText: String = "20.0"
    @State private var weightLbText: String = "44"
    @State private var reps: Int = 10
    @State private var durationSeconds: Int = 30
    @State private var rirSelection: Int = -1
    @State private var setNotes: String = ""
    @State private var showExerciseNotes: Bool = false
    @State private var searchText: String = ""
    @State private var justSaved: Bool = false
    @State private var savedSetNumber: Int = 0
    @State private var cachedNextSetNumber: Int = 1
    @State private var isSynchronizingWeightFields = false
    @FocusState private var focusedWeightField: WeightField?

    private enum WeightField: Hashable {
        case kg
        case lb
    }

    private var exerciseType: String {
        selectedExercise?.exerciseType ?? "weightReps"
    }

    private struct ExerciseGroupSection: Identifiable {
        let muscleGroup: String
        let exercises: [Exercise]
        let sortDate: Date?

        var id: String { muscleGroup }

        var localizedTitle: String {
            Exercise.localizedMuscleGroupName(for: muscleGroup)
        }
    }

    private var visibleExercises: [Exercise] {
        exercises.filter(\.isActiveResolved)
    }

    private var filteredExercises: [Exercise] {
        let source: [Exercise]
        if searchText.isEmpty {
            source = visibleExercises
        } else {
            source = visibleExercises.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.localizedMuscleGroup.localizedCaseInsensitiveContains(searchText)
            }
        }

        return source
    }

    private var groupedExercises: [ExerciseGroupSection] {
        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            normalizedMuscleGroup(for: exercise)
        }

        return grouped.map { muscleGroup, exercises in
            ExerciseGroupSection(
                muscleGroup: muscleGroup,
                exercises: exercises.sorted(by: compareExercises(lhs:rhs:)),
                sortDate: exercises.compactMap(\.lastTrainedDate).max()
            )
        }
        .sorted(by: compareExerciseGroups(lhs:rhs:))
    }

    private func normalizedMuscleGroup(for exercise: Exercise) -> String {
        exercise.muscleGroup.isEmpty ? "Other" : exercise.muscleGroup
    }

    private func compareExercises(lhs: Exercise, rhs: Exercise) -> Bool {
        switch (lhs.lastTrainedDate, rhs.lastTrainedDate) {
        case let (l?, r?):
            if l != r { return l < r }
            return lhs.displayName < rhs.displayName
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.displayName < rhs.displayName
        }
    }

    private func compareExerciseGroups(lhs: ExerciseGroupSection, rhs: ExerciseGroupSection) -> Bool {
        switch (lhs.sortDate, rhs.sortDate) {
        case let (l?, r?):
            if l != r { return l < r }
            return lhs.localizedTitle < rhs.localizedTitle
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.localizedTitle < rhs.localizedTitle
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

    private func exerciseRow(for exercise: Exercise) -> some View {
        Button {
            selectedExercise = exercise
            showExerciseNotes = false
            searchText = ""
            applySuggestedDefaults(for: exercise)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(AppTextStyle.sectionTitle)
                    Text(lastTrainedLabel(for: exercise))
                        .font(AppTextStyle.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.localizedMuscleGroup)
                        .font(AppTextStyle.caption)
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

    @ViewBuilder
    private var exercisePickerSections: some View {
        Section {
            TextField("addSet.searchExercises".localized, text: $searchText)
                .textFieldStyle(.plain)
        } header: {
            Text("addSet.exercise".localized)
        } footer: {
            if !exerciseOrderingHint.isEmpty {
                Text(exerciseOrderingHint)
            }
        }

        ForEach(groupedExercises) { group in
            Section(group.localizedTitle) {
                ForEach(group.exercises) { exercise in
                    exerciseRow(for: exercise)
                }
            }
        }
    }

    private var nextSetNumber: Int {
        cachedNextSetNumber
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
                if selectedExercise != nil {
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
            }
            .navigationTitle("addSet.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .font(AppTextStyle.body)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("addSet.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectedExercise != nil {
                    HStack(spacing: 10) {
                        Button {
                            saveSet(andContinue: true)
                        } label: {
                            Label("addSet.saveAndAddAnother".localized, systemImage: "plus.circle")
                                .font(AppTextStyle.captionStrong)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            saveSet(andContinue: false)
                        } label: {
                            Label("addSet.saveAndClose".localized, systemImage: "checkmark.circle")
                                .font(AppTextStyle.captionStrong)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .background(.thinMaterial)
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .onChange(of: selectedDate) { _, _ in
                if let exercise = selectedExercise {
                    applySuggestedDefaults(for: exercise)
                }
            }
            .onChange(of: weightKgText) { _, newValue in
                handleWeightTextChange(from: .kg, newValue: newValue)
            }
            .onChange(of: weightLbText) { _, newValue in
                handleWeightTextChange(from: .lb, newValue: newValue)
            }
            .onChange(of: focusedWeightField) { oldValue, newValue in
                if oldValue != nil && oldValue != newValue {
                    syncWeightFields(fromKilograms: weight)
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
        syncWeightFields(fromKilograms: weight)
    }

    @ViewBuilder
    private var exerciseSection: some View {
        if let exercise = selectedExercise {
            Section {
                HStack {
                    Text(exercise.displayName)
                        .font(AppTextStyle.sectionTitle)

                    Button {
                        withAnimation {
                            showExerciseNotes.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(AppTextStyle.body)
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
                        .font(AppTextStyle.body)
                    }
                }

                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.localizedMuscleGroup)
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                }

                if showExerciseNotes, !exercise.displayNotes.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.orange)
                            .padding(.top, 2)

                        Text(exercise.displayNotes)
                            .font(AppTextStyle.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)
                }
            } header: {
                Text("addSet.exercise".localized)
            }
        } else {
            exercisePickerSections
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 10) {
                    weightFieldsRow
                    stepperControl
                }

                VStack(alignment: .leading, spacing: 10) {
                    weightFieldsRow
                    HStack {
                        Spacer()
                        stepperControl
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var weightFieldsRow: some View {
        HStack(spacing: 8) {
            weightInputField(label: WeightUnit.kg.localizedLabel, text: $weightKgText, field: .kg)
            weightInputField(label: WeightUnit.lb.localizedLabel, text: $weightLbText, field: .lb)
        }
    }

    private var repsSection: some View {
        Section("addSet.reps".localized) {
            HStack {
                Button {
                    reps = max(1, reps - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Spacer()

                TextField("Reps", value: $reps, format: .number)
                    .font(AppTextStyle.metric)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 84)

                Text("common.reps".localized)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    reps += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    private var durationSection: some View {
        Section("common.duration".localized) {
            HStack {
                Button {
                    durationSeconds = max(5, durationSeconds - 5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(WorkoutSet.formatDuration(durationSeconds))
                    .font(AppTextStyle.metric)
                    .frame(width: 84)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    durationSeconds += 5
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
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
        cachedNextSetNumber = nextSetNumber(from: currentDaySets)

        if let latestTodaySet = currentDaySets.sorted(by: WorkoutSet.trainingOrder(lhs:rhs:)).last {
            weight = latestTodaySet.weightKg
            reps = latestTodaySet.reps > 0 ? latestTodaySet.reps : reps
            durationSeconds = latestTodaySet.durationSeconds > 0 ? latestTodaySet.durationSeconds : durationSeconds
            rirSelection = latestTodaySet.rir ?? -1
            syncWeightFields(fromKilograms: weight)
            return
        }

        if let previousStartSet = previousDayStartingSet(for: exercise, before: selectedDate) {
            weight = previousStartSet.weightKg
            reps = previousStartSet.reps > 0 ? previousStartSet.reps : reps
            durationSeconds = previousStartSet.durationSeconds > 0 ? previousStartSet.durationSeconds : durationSeconds
            rirSelection = previousStartSet.rir ?? -1
            syncWeightFields(fromKilograms: weight)
            return
        }

        if let lastWeight = exercise.lastWeight {
            weight = lastWeight
        }
        rirSelection = -1
        syncWeightFields(fromKilograms: weight)
    }

    private var activeWeightField: WeightField {
        focusedWeightField ?? .kg
    }

    private var stepperControl: some View {
        HStack(spacing: 0) {
            Button {
                adjustWeight(by: -activeWeightUnit.step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 10)

            Button {
                adjustWeight(by: activeWeightUnit.step)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
        .frame(minWidth: 84, minHeight: 38)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private func weightInputField(label: String, text: Binding<String>, field: WeightField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTextStyle.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            TextField("0", text: text)
                .font(AppTextStyle.metric)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($focusedWeightField, equals: field)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(activeWeightField == field ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(activeWeightField == field ? Color.orange : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focusedWeightField = field
        }
    }

    private func adjustWeight(by delta: Double) {
        let currentKilograms: Double
        if activeWeightUnit == .lb {
            let pounds = Double(weightLbText.replacingOccurrences(of: ",", with: ".")) ?? WeightUnit.lb.formattedInputValue(fromKilograms: weight)
            currentKilograms = WeightUnit.lb.convertToKilograms(pounds)
        } else {
            currentKilograms = Double(weightKgText.replacingOccurrences(of: ",", with: ".")) ?? weight
        }

        let updatedKilograms: Double
        if activeWeightUnit == .lb {
            let updatedPounds = max(0, WeightUnit.lb.formattedInputValue(fromKilograms: currentKilograms) + delta)
            updatedKilograms = WeightUnit.lb.convertToKilograms(updatedPounds)
        } else {
            updatedKilograms = max(0, currentKilograms + delta)
        }

        weight = updatedKilograms
        syncWeightFields(fromKilograms: updatedKilograms)
    }

    private func handleWeightTextChange(from field: WeightField, newValue: String) {
        guard !isSynchronizingWeightFields, focusedWeightField == field else { return }

        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return }

        let unit = weightUnit(for: field)
        let kilograms = max(0, unit.convertToKilograms(value))
        weight = kilograms

        isSynchronizingWeightFields = true
        switch field {
        case .kg:
            weightLbText = WeightUnit.lb.formattedInputText(fromKilograms: kilograms)
        case .lb:
            weightKgText = WeightUnit.kg.formattedInputText(fromKilograms: kilograms)
        }
        isSynchronizingWeightFields = false
    }

    private func syncWeightFields(fromKilograms kilograms: Double) {
        isSynchronizingWeightFields = true
        weightKgText = WeightUnit.kg.formattedInputText(fromKilograms: kilograms)
        weightLbText = WeightUnit.lb.formattedInputText(fromKilograms: kilograms)
        isSynchronizingWeightFields = false
    }

    private var activeWeightUnit: WeightUnit {
        weightUnit(for: activeWeightField)
    }

    private func weightUnit(for field: WeightField) -> WeightUnit {
        field == .kg ? .kg : .lb
    }

    private func targetDaySets(for exercise: Exercise, on date: Date) -> [WorkoutSet] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return exercise.workoutSets.filter {
            $0.exercise?.id == exercise.id && calendar.startOfDay(for: $0.date) == targetDay
        }
    }

    private func nextSetNumber(from sets: [WorkoutSet]) -> Int {
        (sets.map(\.setNumber).max() ?? 0) + 1
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
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save logged set: \(error)")
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if andContinue {
            // Show success message and reset for next set
            savedSetNumber = setNumber
            cachedNextSetNumber = setNumber + 1
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
