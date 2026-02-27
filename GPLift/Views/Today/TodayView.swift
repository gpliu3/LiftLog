import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSets: [WorkoutSet]
    @Query private var exercises: [Exercise]
    @State private var languageManager = LanguageManager.shared

    @State private var showingAddSet = false
    @State private var editingSet: WorkoutSet?
    @State private var editingExercise: Exercise?
    @State private var expandedNotes: Set<UUID> = []
    @State private var expandedPreviousDay: Set<UUID> = []
    @State private var inlineEditingSetID: UUID?
    @State private var todayAnchor = Calendar.current.startOfDay(for: Date())
    @State private var todayDayNote = ""

    private var todaySets: [WorkoutSet] {
        let calendar = Calendar.current
        return allSets.filter {
            calendar.startOfDay(for: $0.date) == todayAnchor && $0.exercise != nil
        }
    }

    private var groupedSets: [(Exercise, [WorkoutSet])] {
        let grouped = Dictionary(grouping: todaySets) { $0.exercise }
        return grouped.compactMap { (exercise, sets) in
            guard let exercise = exercise else { return nil }
            return (exercise, sets.sorted { $0.setNumber < $1.setNumber })
        }.sorted { lhs, rhs in
            let lhsLatest = lhs.1.map(\.date).max() ?? .distantPast
            let rhsLatest = rhs.1.map(\.date).max() ?? .distantPast
            if lhsLatest != rhsLatest { return lhsLatest > rhsLatest }
            return lhs.0.displayName < rhs.0.displayName
        }
    }

    private var sortedTodaySets: [WorkoutSet] {
        todaySets.sorted(by: WorkoutSet.trainingOrder(lhs:rhs:))
    }

    private var totalVolume: Double {
        todaySets.reduce(0) { $0 + $1.volume }
    }

    private var uniqueExercises: Int {
        Set(todaySets.compactMap { $0.exercise?.id }).count
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    if todaySets.isEmpty {
                        emptyState
                    } else {
                        workoutList(proxy: proxy)
                    }

                    addSetButton
                }
            }
            .navigationTitle(todayDateString)
            .font(AppTextStyle.body)
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshTodayAnchor()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshTodayAnchor()
            }
        }
        .onAppear {
            syncTodayDayNoteFromData()
        }
        .onChange(of: todaySets.count) { _, _ in
            syncTodayDayNoteFromData()
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

    private func workoutList(proxy: ScrollViewProxy) -> some View {
        List {
            statsCard

            ForEach(groupedSets, id: \.0.id) { exercise, sets in
                Section {
                    if expandedNotes.contains(exercise.id) {
                        NotesEditorRow(exercise: exercise)
                            .listRowBackground(Color.blue.opacity(0.05))
                    }

                    if expandedPreviousDay.contains(exercise.id) {
                        PreviousDaySetsRow(
                            exercise: exercise,
                            sets: previousDaySets(for: exercise)
                        )
                        .listRowBackground(Color.teal.opacity(0.07))
                    }

                    ForEach(sets) { set in
                        VStack(spacing: 2) {
                            SetRowView(workoutSet: set, isPersonalBest: set.isPersonalBest(in: allSets), onTap: {
                                dismissKeyboard()
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    inlineEditingSetID = (inlineEditingSetID == set.id) ? nil : set.id
                                }
                                if inlineEditingSetID == set.id {
                                    scrollToSet(set.id, with: proxy)
                                }
                            }, onDuplicate: {
                                quickAddSet(for: exercise, basedOn: set)
                            }, onEdit: {
                                editingSet = set
                            })
                            .id(set.id)

                            if inlineEditingSetID == set.id {
                                InlineSetEditorRow(workoutSet: set, onStartEditingWeight: {
                                    scrollToSet(set.id, with: proxy)
                                }, onDone: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        inlineEditingSetID = nil
                                    }
                                })
                            }
                        }
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
                        hasPreviousDaySets: !previousDaySets(for: exercise).isEmpty,
                        onInfoTap: {
                            closeInlineEditor()
                            withAnimation {
                                if expandedNotes.contains(exercise.id) {
                                    expandedNotes.remove(exercise.id)
                                } else {
                                    expandedNotes.insert(exercise.id)
                                }
                            }
                        },
                        onPreviousDayTap: {
                            closeInlineEditor()
                            withAnimation {
                                if expandedPreviousDay.contains(exercise.id) {
                                    expandedPreviousDay.remove(exercise.id)
                                } else {
                                    expandedPreviousDay.insert(exercise.id)
                                }
                            }
                        }
                    )
                }
            }

            dayNoteCard
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 24)
    }

    private func scrollToSet(_ id: UUID, with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private func quickAddRow(for exercise: Exercise, sets: [WorkoutSet]) -> some View {
        let lastSet = sets.last

        return Button {
            closeInlineEditor()
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
                            .font(AppTextStyle.caption)
                            .foregroundStyle(.secondary)
                    } else if exercise.isRepsOnly {
                        Text("\(lastSet.reps) \("common.reps".localized)")
                            .font(AppTextStyle.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(String(format: "%.1f", lastSet.weightKg)) kg × \(lastSet.reps)")
                            .font(AppTextStyle.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listRowBackground(Color.orange.opacity(0.05))
    }

    /// Directly add a new set without showing modal.
    private func quickAddSet(for exercise: Exercise, basedOn referenceSet: WorkoutSet?) {
        let calendar = Calendar.current
        let todayExerciseSets = allSets.filter {
            $0.exercise?.id == exercise.id &&
            calendar.startOfDay(for: $0.date) == todayAnchor
        }
        let nextSetNumber = (todayExerciseSets.map { $0.setNumber }.max() ?? 0) + 1

        // Determine values from reference set or previous day
        var weight: Double = exercise.isWeightReps ? 20.0 : 0
        var reps: Int = exercise.isTimeOnly ? 0 : 10
        var duration: Int = exercise.isTimeOnly ? 30 : 0
        var rir: Int? = nil

        if let ref = referenceSet {
            weight = ref.weightKg
            reps = ref.reps
            duration = ref.durationSeconds
            rir = ref.rir
        } else {
            if let previousStartingSet = getPreviousDayStartingSet(for: exercise) {
                weight = previousStartingSet.weightKg
                reps = previousStartingSet.reps
                duration = previousStartingSet.durationSeconds
                rir = previousStartingSet.rir
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
            setNumber: nextSetNumber,
            rir: rir
        )

        modelContext.insert(workoutSet)
        persistContext()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Get the first set from the most recent previous training day.
    private func getPreviousDayStartingSet(for exercise: Exercise) -> WorkoutSet? {
        let calendar = Calendar.current
        let today = todayAnchor

        let previousSets = exercise.workoutSets
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted { $0.date > $1.date }

        guard let mostRecentDate = previousSets.first?.date else { return nil }

        let mostRecentDay = calendar.startOfDay(for: mostRecentDate)
        let setsOnThatDay = previousSets
            .filter { calendar.startOfDay(for: $0.date) == mostRecentDay }
            .sorted { $0.setNumber < $1.setNumber }

        guard !setsOnThatDay.isEmpty else { return nil }
        return setsOnThatDay.first
    }

    private func previousDaySets(for exercise: Exercise) -> [WorkoutSet] {
        let calendar = Calendar.current
        let today = todayAnchor
        let previousSets = exercise.workoutSets
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted(by: WorkoutSet.trainingOrder(lhs:rhs:))

        guard let latestDayDate = previousSets.map({ calendar.startOfDay(for: $0.date) }).max() else {
            return []
        }

        return previousSets
            .filter { calendar.startOfDay(for: $0.date) == latestDayDate }
            .sorted(by: WorkoutSet.trainingOrder(lhs:rhs:))
    }

    private var statsCard: some View {
        Section {
            HStack(spacing: 12) {
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
            .padding(.vertical, 2)
        }
    }

    private var dayNoteCard: some View {
        Section("dayNote.title".localized) {
            TextEditor(text: $todayDayNote)
                .font(AppTextStyle.body)
                .frame(minHeight: 88)
                .onChange(of: todayDayNote) { _, newValue in
                    WorkoutSet.setDayNote(newValue, for: todayAnchor, in: sortedTodaySets)
                    persistContext()
                }
                .overlay(alignment: .topLeading) {
                    if todayDayNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("dayNote.placeholder".localized)
                            .font(AppTextStyle.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var addSetButton: some View {
        Button {
            closeInlineEditor()
            showingAddSet = true
        } label: {
            Image(systemName: "plus")
                .font(AppTextStyle.sectionTitle)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .padding(12)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return formatter.string(from: todayAnchor)
    }

    private func refreshTodayAnchor() {
        todayAnchor = Calendar.current.startOfDay(for: Date())
        syncTodayDayNoteFromData()
    }

    private func syncTodayDayNoteFromData() {
        todayDayNote = WorkoutSet.dayNote(for: todayAnchor, in: sortedTodaySets)
    }

    private func deleteSet(at offsets: IndexSet, from sets: [WorkoutSet]) {
        for index in offsets {
            if inlineEditingSetID == sets[index].id {
                inlineEditingSetID = nil
            }
            modelContext.delete(sets[index])
        }
        persistContext()
    }

    private func persistContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save model context: \(error)")
        }
    }

    private func closeInlineEditor() {
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.18)) {
            inlineEditingSetID = nil
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct SetRowView: View {
    let workoutSet: WorkoutSet
    let isPersonalBest: Bool
    var onTap: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onEdit: (() -> Void)?

    private var exerciseType: String {
        workoutSet.exercise?.exerciseType ?? "weightReps"
    }

    private var weightRepsMetric: String {
        "\(String(format: "%.1f", workoutSet.weightKg)) kg × \(workoutSet.reps) \("common.reps".localized)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("common.set".localized(with: workoutSet.setNumber))
                .foregroundStyle(.secondary)
                .font(AppTextStyle.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 50, alignment: .leading)

            if exerciseType == "timeOnly" {
                HStack(spacing: 6) {
                    Text(workoutSet.formattedDuration)
                        .font(AppTextStyle.bodyStrong)
                        .lineLimit(1)

                    if let rir = workoutSet.rir {
                        Text("RIR \(rir)")
                            .font(AppTextStyle.caption2Strong)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            } else if exerciseType == "repsOnly" {
                HStack(spacing: 6) {
                    Text("\(workoutSet.reps) \("common.reps".localized)")
                        .font(AppTextStyle.bodyStrong)
                        .lineLimit(1)

                    if let rir = workoutSet.rir {
                        Text("RIR \(rir)")
                            .font(AppTextStyle.caption2Strong)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Text(weightRepsMetric)
                            .font(AppTextStyle.bodyStrong)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                            .layoutPriority(1)

                        if let rir = workoutSet.rir {
                            Text("RIR \(rir)")
                                .font(AppTextStyle.caption2Strong)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text(weightRepsMetric)
                            .font(AppTextStyle.bodyStrong)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .allowsTightening(true)
                            .layoutPriority(1)

                        if let rir = workoutSet.rir {
                            Text("RIR \(rir)")
                                .font(AppTextStyle.caption2Strong)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 6)

            if isPersonalBest {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                    .font(AppTextStyle.caption)
            }
        }
        .padding(.vertical, -1)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
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

struct InlineSetEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    let workoutSet: WorkoutSet
    var onStartEditingWeight: (() -> Void)?
    var onDone: (() -> Void)?

    @State private var weightText: String
    @State private var repsText: String
    @State private var durationSeconds: Int
    @State private var rirSelection: Int
    @State private var adjustmentTarget: AdjustmentTarget
    @State private var hasPendingChanges = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case weight
        case reps
    }

    private enum AdjustmentTarget {
        case weight
        case reps
        case duration
    }

    private var exerciseType: String {
        workoutSet.exercise?.exerciseType ?? "weightReps"
    }

    init(workoutSet: WorkoutSet, onStartEditingWeight: (() -> Void)? = nil, onDone: (() -> Void)? = nil) {
        self.workoutSet = workoutSet
        self.onStartEditingWeight = onStartEditingWeight
        self.onDone = onDone
        _weightText = State(initialValue: String(format: "%.1f", workoutSet.weightKg))
        _repsText = State(initialValue: "\(max(1, workoutSet.reps))")
        _durationSeconds = State(initialValue: max(5, workoutSet.durationSeconds))
        _rirSelection = State(initialValue: workoutSet.rir ?? -1)
        let defaultTarget: AdjustmentTarget
        switch workoutSet.exercise?.exerciseType ?? "weightReps" {
        case "repsOnly":
            defaultTarget = .reps
        case "timeOnly":
            defaultTarget = .duration
        default:
            defaultTarget = .weight
        }
        _adjustmentTarget = State(initialValue: defaultTarget)
    }

    var body: some View {
        VStack(spacing: 6) {
            if exerciseType == "weightReps" {
                HStack(spacing: 8) {
                    Text("kg")
                        .font(AppTextStyle.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .onTapGesture { selectTarget(.weight) }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(adjustmentTarget == .weight ? Color.orange : Color.clear, lineWidth: 1)
                        )

                    HStack(spacing: 4) {
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .reps)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 66)
                            .onTapGesture { selectTarget(.reps) }
                        Text("common.reps".localized)
                            .font(AppTextStyle.bodyStrong)
                            .foregroundStyle(adjustmentTarget == .reps ? .orange : .primary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(adjustmentTarget == .reps ? Color.orange.opacity(0.15) : Color.clear)
                    )

                    Spacer()

                    stepperButtons {
                        applyIncrement(-1)
                    } incrementAction: {
                        applyIncrement(1)
                    }
                }
            } else if exerciseType == "repsOnly" {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .reps)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 74)
                            .onTapGesture { selectTarget(.reps) }
                        Text("common.reps".localized)
                            .font(AppTextStyle.bodyStrong)
                            .foregroundStyle(adjustmentTarget == .reps ? .orange : .primary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(adjustmentTarget == .reps ? Color.orange.opacity(0.15) : Color.clear)
                    )

                    Spacer()

                    stepperButtons {
                        applyIncrement(-1)
                    } incrementAction: {
                        applyIncrement(1)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text(WorkoutSet.formatDuration(durationSeconds))
                        .font(AppTextStyle.bodyStrong)

                    Spacer()

                    stepperButtons {
                        applyIncrement(-1)
                    } incrementAction: {
                        applyIncrement(1)
                    }
                }
            }

            Picker("addSet.rir".localized, selection: $rirSelection) {
                Text("common.noneShort".localized).tag(-1)
                Text("0").tag(0)
                Text("1").tag(1)
                Text("2").tag(2)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("common.cancel".localized) {
                    onDone?()
                }
                .font(AppTextStyle.caption)
            }
        }
        .padding(6)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
        .onChange(of: weightText) { _, _ in
            hasPendingChanges = true
        }
        .onChange(of: repsText) { _, _ in
            hasPendingChanges = true
        }
        .onChange(of: durationSeconds) { _, _ in
            hasPendingChanges = true
        }
        .onChange(of: rirSelection) { _, _ in
            hasPendingChanges = true
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil && newValue != oldValue {
                saveChangesIfNeeded()
            }
        }
        .onTapGesture {
            dismissKeyboardAndPersist()
        }
        .onDisappear {
            saveChangesIfNeeded()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.save".localized) {
                    dismissKeyboardAndPersist()
                    onDone?()
                }
                .font(AppTextStyle.captionStrong)
            }
        }
    }

    private func saveChangesIfNeeded() {
        guard hasPendingChanges else { return }
        if exerciseType == "weightReps" {
            workoutSet.weightKg = parsedWeight()
            workoutSet.reps = parsedReps()
            workoutSet.durationSeconds = 0
        } else if exerciseType == "repsOnly" {
            workoutSet.weightKg = 0
            workoutSet.reps = parsedReps()
            workoutSet.durationSeconds = 0
        } else {
            workoutSet.weightKg = 0
            workoutSet.reps = 0
            workoutSet.durationSeconds = max(5, durationSeconds)
        }
        workoutSet.rir = rirSelection < 0 ? nil : rirSelection
        hasPendingChanges = false
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save inline set edit: \(error)")
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func parsedWeight() -> Double {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        let value = Double(normalized) ?? 0
        return max(0, value)
    }

    private func parsedReps() -> Int {
        let digitsOnly = repsText.filter(\.isNumber)
        let value = Int(digitsOnly) ?? 0
        return max(1, value)
    }

    private func formattedWeight(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func applyIncrement(_ delta: Int) {
        if exerciseType == "weightReps" {
            if adjustmentTarget == .weight {
                let newWeight = max(0, parsedWeight() + (Double(delta) * 2.5))
                weightText = formattedWeight(newWeight)
            } else if adjustmentTarget == .reps {
                let newReps = max(1, parsedReps() + delta)
                repsText = "\(newReps)"
            }
            hasPendingChanges = true
            return
        }

        if exerciseType == "repsOnly" {
            let newReps = max(1, parsedReps() + delta)
            repsText = "\(newReps)"
            hasPendingChanges = true
            return
        }

        durationSeconds = max(5, durationSeconds + (delta * 5))
        hasPendingChanges = true
    }

    private func dismissKeyboardAndPersist() {
        if focusedField != nil {
            focusedField = nil
        } else {
            saveChangesIfNeeded()
        }
    }

    private func selectTarget(_ target: AdjustmentTarget) {
        adjustmentTarget = target
        switch target {
        case .weight:
            focusedField = .weight
            onStartEditingWeight?()
        case .reps:
            focusedField = .reps
        case .duration:
            focusedField = nil
        }
    }

    @ViewBuilder
    private func stepperButtons(decrementAction: @escaping () -> Void, incrementAction: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: decrementAction) {
                Image(systemName: "minus")
                    .font(AppTextStyle.bodyStrong)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            Button(action: incrementAction) {
                Image(systemName: "plus")
                    .font(AppTextStyle.bodyStrong)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

struct ExerciseHeaderView: View {
    let exercise: Exercise
    let sets: [WorkoutSet]
    var hasPreviousDaySets: Bool = false
    var onInfoTap: (() -> Void)?
    var onPreviousDayTap: (() -> Void)?

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
                        .font(.headline.bold())
                        .foregroundStyle(Color.primary)

                    if let onInfoTap = onInfoTap {
                        Button {
                            onInfoTap()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(AppTextStyle.body)
                                .foregroundStyle(.blue)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if hasPreviousDaySets, let onPreviousDayTap = onPreviousDayTap {
                        Button {
                            onPreviousDayTap()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(AppTextStyle.body)
                                .foregroundStyle(.teal)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(subtitle)
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct PreviousDaySetsRow: View {
    let exercise: Exercise
    let sets: [WorkoutSet]

    private var previousDayDate: Date? {
        sets.map(\.date).max()
    }

    private var orderedSets: [WorkoutSet] {
        sets.sorted(by: WorkoutSet.trainingOrder(lhs:rhs:))
    }

    private func weightRepsMetric(for set: WorkoutSet) -> String {
        "\(String(format: "%.1f", set.weightKg)) kg × \(set.reps) \("common.reps".localized)"
    }

    private var subtitle: String {
        guard let date = previousDayDate else {
            return "today.previousDay.none".localized
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return "today.previousDay.date".localized(with: formatter.string(from: date))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("today.previousDay.title".localized)
                    .font(AppTextStyle.captionStrong)
                    .foregroundStyle(.teal)
                Spacer(minLength: 8)
                Text(subtitle)
                    .font(AppTextStyle.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if orderedSets.isEmpty {
                Text("today.previousDay.none".localized)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedSets) { set in
                    HStack(spacing: 8) {
                        Text("common.set".localized(with: set.setNumber))
                            .font(AppTextStyle.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(width: 50, alignment: .leading)

                        if exercise.isTimeOnly {
                            HStack(spacing: 6) {
                                Text(set.formattedDuration)
                                    .font(AppTextStyle.captionStrong)
                                    .lineLimit(1)

                                if let rir = set.rir {
                                    Text("RIR \(rir)")
                                        .font(AppTextStyle.caption2Strong)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        } else if exercise.isRepsOnly {
                            HStack(spacing: 6) {
                                Text("\(set.reps) \("common.reps".localized)")
                                    .font(AppTextStyle.captionStrong)
                                    .lineLimit(1)

                                if let rir = set.rir {
                                    Text("RIR \(rir)")
                                        .font(AppTextStyle.caption2Strong)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 6) {
                                    Text(weightRepsMetric(for: set))
                                        .font(AppTextStyle.captionStrong)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.74)
                                        .allowsTightening(true)
                                        .layoutPriority(1)

                                    if let rir = set.rir {
                                        Text("RIR \(rir)")
                                            .font(AppTextStyle.caption2Strong)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }

                                HStack(spacing: 6) {
                                    Text(weightRepsMetric(for: set))
                                        .font(AppTextStyle.captionStrong)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .allowsTightening(true)
                                        .layoutPriority(1)

                                    if let rir = set.rir {
                                        Text("RIR \(rir)")
                                            .font(AppTextStyle.caption2Strong)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct StatItemView: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .font(AppTextStyle.caption)

            Text(value)
                .font(AppTextStyle.bodyStrong)

            Text(label)
                .font(AppTextStyle.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NotesEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise
    @State private var editableNotes: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $editableNotes)
                .font(AppTextStyle.body)
                .frame(minHeight: 42)
                .focused($isFocused)
                .onChange(of: editableNotes) {
                    exercise.notes = editableNotes
                    do {
                        try modelContext.save()
                    } catch {
                        assertionFailure("Failed to save exercise notes: \(error)")
                    }
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
