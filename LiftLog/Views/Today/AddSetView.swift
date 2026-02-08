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
    @State private var weight: Double = 20.0
    @State private var reps: Int = 10
    @State private var durationSeconds: Int = 30
    @State private var notes: String = ""
    @State private var showNotes: Bool = false
    @State private var searchText: String = ""
    @State private var justSaved: Bool = false
    @State private var savedSetNumber: Int = 0

    private var exerciseType: String {
        selectedExercise?.exerciseType ?? "weightReps"
    }

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var nextSetNumber: Int {
        guard let exercise = selectedExercise else { return 1 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySets = exercise.workoutSets.filter {
            calendar.startOfDay(for: $0.date) == today
        }
        return (todaySets.map { $0.setNumber }.max() ?? 0) + 1
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
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            saveSet(andContinue: true)
                        } label: {
                            Label("addSet.saveAndAddAnother".localized, systemImage: "plus.circle")
                        }

                        Button {
                            saveSet(andContinue: false)
                        } label: {
                            Label("addSet.saveAndClose".localized, systemImage: "checkmark.circle")
                        }
                    } label: {
                        Text("addSet.save".localized)
                            .fontWeight(.semibold)
                    }
                    .disabled(selectedExercise == nil)
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    private func setupInitialValues() {
        if let exercise = preselectedExercise {
            selectedExercise = exercise
            if let w = prefilledWeight {
                weight = w
            } else if let lastWeight = exercise.lastWeight {
                weight = lastWeight
            }
            if let r = prefilledReps {
                reps = r
            }
        }
    }

    private var exerciseSection: some View {
        Section("addSet.exercise".localized) {
            if let exercise = selectedExercise {
                HStack {
                    Text(exercise.displayName)
                        .font(.headline)

                    Button {
                        withAnimation {
                            showNotes.toggle()
                            if showNotes && notes.isEmpty && !exercise.displayNotes.isEmpty {
                                notes = exercise.displayNotes
                            }
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(showNotes ? .orange : .blue)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Only show change button if not preselected (quick add mode)
                    if preselectedExercise == nil {
                        Button("addSet.change".localized) {
                            selectedExercise = nil
                        }
                        .font(.subheadline)
                    }
                }

                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.localizedMuscleGroup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if showNotes {
                    TextEditor(text: $notes)
                        .font(.subheadline)
                        .frame(minHeight: 60)
                }
            } else {
                TextField("addSet.searchExercises".localized, text: $searchText)
                    .textFieldStyle(.plain)

                ForEach(filteredExercises) { exercise in
                    Button {
                        selectedExercise = exercise
                        searchText = ""
                        loadLastWeight()
                    } label: {
                        HStack {
                            Text(exercise.displayName)
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

                Text("common.seconds".localized)
                    .foregroundStyle(.secondary)

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
            } header: {
                Text("addSet.summary".localized)
            }
        }
    }

    private func loadLastWeight() {
        if let exercise = selectedExercise, let lastWeight = exercise.lastWeight {
            weight = lastWeight
        }
    }

    private func saveSet(andContinue: Bool) {
        guard let exercise = selectedExercise else { return }

        let setNumber = nextSetNumber

        let saveWeight: Double = exercise.isWeightReps ? weight : 0
        let saveReps: Int = exercise.isTimeOnly ? 0 : reps
        let saveDuration: Int = exercise.isTimeOnly ? durationSeconds : 0

        let workoutSet = WorkoutSet(
            exercise: exercise,
            date: Date(),
            weightKg: saveWeight,
            reps: saveReps,
            durationSeconds: saveDuration,
            setNumber: setNumber,
            notes: notes
        )

        modelContext.insert(workoutSet)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if andContinue {
            // Show success message and reset for next set
            savedSetNumber = setNumber
            justSaved = true
            notes = "" // Clear notes for next set

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
}

#Preview {
    AddSetView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
