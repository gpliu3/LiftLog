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
    @State private var notes: String = ""
    @State private var searchText: String = ""
    @State private var justSaved: Bool = false
    @State private var savedSetNumber: Int = 0

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var nextSetNumber: Int {
        guard let exercise = selectedExercise else { return 1 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySets = exercise.workoutSets.filter {
            calendar.startOfDay(for: $0.date) == today
        }
        return todaySets.count + 1
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
                weightSection
                repsSection
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
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                            .font(.headline)
                        if !exercise.muscleGroup.isEmpty {
                            Text(exercise.localizedMuscleGroup)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    // Only show change button if not preselected (quick add mode)
                    if preselectedExercise == nil {
                        Button("addSet.change".localized) {
                            selectedExercise = nil
                        }
                        .font(.subheadline)
                    }
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
                            Text(exercise.name)
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

    private var notesSection: some View {
        Section("addSet.notes".localized) {
            TextField("addSet.addNote".localized, text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if selectedExercise != nil {
            Section {
                HStack {
                    Text("addSet.setNumber".localized(with: nextSetNumber))
                    Spacer()
                    Text("addSet.volumeLabel".localized(with: Int(weight * Double(reps))))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("addSet.est1RM".localized)
                    Spacer()
                    Text("\(String(format: "%.1f", weight * (1 + Double(reps) / 30))) kg")
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)
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

        let workoutSet = WorkoutSet(
            exercise: exercise,
            date: Date(),
            weightKg: weight,
            reps: reps,
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
