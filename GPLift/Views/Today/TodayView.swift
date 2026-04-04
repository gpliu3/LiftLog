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

                    if inlineEditingSetID == nil {
                        addSetButton
                    }
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
                        if inlineEditingSetID == set.id {
                            InlineSetEditorRow(
                                workoutSet: set,
                                isPersonalBest: set.isPersonalBest(in: allSets),
                                onStartEditingWeight: {
                                    scrollToSet(set.id, with: proxy)
                                },
                                onDone: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        inlineEditingSetID = nil
                                    }
                                }
                            )
                            .id(set.id)
                        } else {
                            SetRowView(workoutSet: set, isPersonalBest: set.isPersonalBest(in: allSets), onTap: {
                                dismissKeyboard()
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    inlineEditingSetID = set.id
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
                        hasNotes: true,
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
    let isPersonalBest: Bool
    var onStartEditingWeight: (() -> Void)?
    var onDone: (() -> Void)?

    @State private var weightKgText: String
    @State private var weightLbText: String
    @State private var repsText: String
    @State private var durationSeconds: Int
    @State private var rirSelection: Int
    @State private var adjustmentTarget: AdjustmentTarget
    @State private var initialWeight: Double
    @State private var initialReps: Int
    @State private var initialDurationSeconds: Int
    @State private var initialRirSelection: Int
    @State private var hasPendingChanges = false
    @FocusState private var focusedField: Field?
    @State private var isSynchronizingWeightFields = false

    private enum Field: Hashable {
        case weightKg
        case weightLb
        case reps
    }

    private enum AdjustmentTarget {
        case weightKg
        case weightLb
        case reps
        case duration
    }

    private var exerciseType: String {
        workoutSet.exercise?.exerciseType ?? "weightReps"
    }

    init(
        workoutSet: WorkoutSet,
        isPersonalBest: Bool,
        onStartEditingWeight: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) {
        self.workoutSet = workoutSet
        self.isPersonalBest = isPersonalBest
        self.onStartEditingWeight = onStartEditingWeight
        self.onDone = onDone
        let startWeight = workoutSet.weightKg
        let startReps = max(1, workoutSet.reps)
        let startDuration = max(5, workoutSet.durationSeconds)
        let startRir = workoutSet.rir ?? -1
        _weightKgText = State(initialValue: WeightUnit.kg.formattedInputText(fromKilograms: startWeight))
        _weightLbText = State(initialValue: WeightUnit.lb.formattedInputText(fromKilograms: startWeight))
        _repsText = State(initialValue: "\(startReps)")
        _durationSeconds = State(initialValue: startDuration)
        _rirSelection = State(initialValue: startRir)
        _initialWeight = State(initialValue: startWeight)
        _initialReps = State(initialValue: startReps)
        _initialDurationSeconds = State(initialValue: startDuration)
        _initialRirSelection = State(initialValue: startRir)
        let defaultTarget: AdjustmentTarget
        switch workoutSet.exercise?.exerciseType ?? "weightReps" {
        case "repsOnly":
            defaultTarget = .reps
        case "timeOnly":
            defaultTarget = .duration
        default:
            defaultTarget = .weightKg
        }
        _adjustmentTarget = State(initialValue: defaultTarget)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("common.set".localized(with: workoutSet.setNumber))
                    .foregroundStyle(.secondary)
                    .font(AppTextStyle.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 50, alignment: .leading)

                Spacer()

                if isPersonalBest {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.orange)
                        .font(AppTextStyle.caption)
                }
            }

            if exerciseType == "weightReps" {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 8) {
                        weightField(label: WeightUnit.kg.localizedLabel, text: $weightKgText, field: .weightKg, target: .weightKg)
                        weightField(label: WeightUnit.lb.localizedLabel, text: $weightLbText, field: .weightLb, target: .weightLb)
                        repsEditorField()
                        Spacer(minLength: 0)
                        stepperButtons {
                            applyIncrement(-1)
                        } incrementAction: {
                            applyIncrement(1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .bottom, spacing: 8) {
                            weightField(label: WeightUnit.kg.localizedLabel, text: $weightKgText, field: .weightKg, target: .weightKg)
                            weightField(label: WeightUnit.lb.localizedLabel, text: $weightLbText, field: .weightLb, target: .weightLb)
                        }

                        HStack(alignment: .bottom, spacing: 8) {
                            repsEditorField()
                            Spacer(minLength: 0)
                            stepperButtons {
                                applyIncrement(-1)
                            } incrementAction: {
                                applyIncrement(1)
                            }
                        }
                    }
                }
            } else if exerciseType == "repsOnly" {
                HStack(spacing: 8) {
                    repsEditorField()
                    Spacer(minLength: 0)
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
                    Spacer(minLength: 0)
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
                    cancelEditing()
                }
                .font(AppTextStyle.caption)
                .buttonStyle(.borderless)

                Spacer()

                Button("common.confirm".localized) {
                    confirmEditing()
                }
                .font(AppTextStyle.captionStrong)
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
            }
        }
        .padding(6)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
        .onChange(of: weightKgText) { _, newValue in
            guard !isSynchronizingWeightFields, focusedField == .weightKg else { return }
            syncWeightFields(from: .kg, using: newValue)
        }
        .onChange(of: weightLbText) { _, newValue in
            guard !isSynchronizingWeightFields, focusedField == .weightLb else { return }
            syncWeightFields(from: .lb, using: newValue)
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
                normalizeWeightFieldsIfNeeded()
                saveChangesIfNeeded()
            }
            if newValue == .weightKg {
                adjustmentTarget = .weightKg
            } else if newValue == .weightLb {
                adjustmentTarget = .weightLb
            } else if newValue == .reps {
                adjustmentTarget = .reps
            }
        }
        .onDisappear {
            saveChangesIfNeeded()
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
        let normalized = weightKgText.replacingOccurrences(of: ",", with: ".")
        let value = Double(normalized) ?? workoutSet.weightKg
        return max(0, value)
    }

    private func parsedReps() -> Int {
        let digitsOnly = repsText.filter(\.isNumber)
        let value = Int(digitsOnly) ?? max(1, workoutSet.reps)
        return max(1, value)
    }

    private func applyIncrement(_ delta: Int) {
        if exerciseType == "weightReps" {
            let activeTarget: AdjustmentTarget
            if focusedField == .weightKg {
                activeTarget = .weightKg
            } else if focusedField == .weightLb {
                activeTarget = .weightLb
            } else if focusedField == .reps {
                activeTarget = .reps
            } else {
                activeTarget = adjustmentTarget
            }

            switch activeTarget {
            case .weightKg:
                let newWeight = max(0, parsedWeight() + (Double(delta) * WeightUnit.kg.step))
                syncWeightFields(from: .kg, using: WeightUnit.kg.formattedInputText(fromKilograms: newWeight))
            case .weightLb:
                let currentPounds = WeightUnit.lb.formattedInputValue(fromKilograms: parsedWeight())
                let newWeight = max(0, currentPounds + (Double(delta) * WeightUnit.lb.step))
                syncWeightFields(from: .lb, using: String(format: "%.0f", newWeight))
            case .reps:
                repsText = "\(max(1, parsedReps() + delta))"
                hasPendingChanges = true
            case .duration:
                break
            }
            adjustmentTarget = activeTarget
            return
        }

        if exerciseType == "repsOnly" {
            repsText = "\(max(1, parsedReps() + delta))"
            hasPendingChanges = true
            return
        }

        durationSeconds = max(5, durationSeconds + (delta * 5))
        hasPendingChanges = true
    }

    private func cancelEditing() {
        weightKgText = WeightUnit.kg.formattedInputText(fromKilograms: initialWeight)
        weightLbText = WeightUnit.lb.formattedInputText(fromKilograms: initialWeight)
        repsText = "\(initialReps)"
        durationSeconds = initialDurationSeconds
        rirSelection = initialRirSelection
        hasPendingChanges = false
        focusedField = nil
        onDone?()
    }

    private func confirmEditing() {
        focusedField = nil
        normalizeWeightFieldsIfNeeded()
        saveChangesIfNeeded()
        onDone?()
    }

    private func selectTarget(_ target: AdjustmentTarget) {
        adjustmentTarget = target
        switch target {
        case .weightKg:
            focusedField = .weightKg
            onStartEditingWeight?()
        case .weightLb:
            focusedField = .weightLb
            onStartEditingWeight?()
        case .reps:
            focusedField = .reps
        case .duration:
            focusedField = nil
        }
    }

    private func syncWeightFields(from sourceUnit: WeightUnit, using text: String) {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            hasPendingChanges = true
            return
        }

        let kilograms = max(0, sourceUnit.convertToKilograms(value))
        isSynchronizingWeightFields = true
        switch sourceUnit {
        case .kg:
            weightLbText = WeightUnit.lb.formattedInputText(fromKilograms: kilograms)
        case .lb:
            weightKgText = WeightUnit.kg.formattedInputText(fromKilograms: kilograms)
        }
        isSynchronizingWeightFields = false
        hasPendingChanges = true
    }

    private func normalizeWeightFieldsIfNeeded() {
        guard exerciseType == "weightReps" else { return }
        let kilograms = parsedWeight()
        isSynchronizingWeightFields = true
        weightKgText = WeightUnit.kg.formattedInputText(fromKilograms: kilograms)
        weightLbText = WeightUnit.lb.formattedInputText(fromKilograms: kilograms)
        isSynchronizingWeightFields = false
    }

    private func weightField(
        label: String,
        text: Binding<String>,
        field: Field,
        target: AdjustmentTarget
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTextStyle.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .textFieldStyle(.plain)
                .font(AppTextStyle.bodyStrong)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture { selectTarget(target) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(adjustmentTarget == target ? Color.orange.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(adjustmentTarget == target ? Color.orange : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectTarget(target) }
    }

    private func repsEditorField() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("common.reps".localized)
                .font(AppTextStyle.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 4) {
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .reps)
                    .textFieldStyle(.plain)
                    .font(AppTextStyle.bodyStrong)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { selectTarget(.reps) }
                Text("common.reps".localized)
                    .font(AppTextStyle.bodyStrong)
                    .foregroundStyle(adjustmentTarget == .reps ? .orange : .primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectTarget(.reps) }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(minWidth: 92, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(adjustmentTarget == .reps ? Color.orange.opacity(0.15) : Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func stepperButtons(decrementAction: @escaping () -> Void, incrementAction: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: decrementAction) {
                Image(systemName: "minus")
                    .font(AppTextStyle.bodyStrong)
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 20)

            Button(action: incrementAction) {
                Image(systemName: "plus")
                    .font(AppTextStyle.bodyStrong)
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.borderless)
        }
        .frame(minWidth: 84, minHeight: 38)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

struct ExerciseHeaderView: View {
    let exercise: Exercise
    let sets: [WorkoutSet]
    var hasNotes: Bool = false
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

                    if hasNotes, let onInfoTap = onInfoTap {
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
