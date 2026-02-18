import SwiftUI
import SwiftData

struct EditSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let workoutSet: WorkoutSet

    @State private var weight: Double
    @State private var reps: Int
    @State private var durationSeconds: Int
    @State private var notes: String
    @State private var showExerciseNotes: Bool = false

    private var exerciseType: String {
        workoutSet.exercise?.exerciseType ?? "weightReps"
    }

    init(workoutSet: WorkoutSet) {
        self.workoutSet = workoutSet
        _weight = State(initialValue: workoutSet.weightKg)
        _reps = State(initialValue: workoutSet.reps)
        _durationSeconds = State(initialValue: workoutSet.durationSeconds)
        _notes = State(initialValue: workoutSet.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                exerciseInfo
                if exerciseType == "weightReps" {
                    weightSection
                }
                if exerciseType == "weightReps" || exerciseType == "repsOnly" {
                    repsSection
                }
                if exerciseType == "timeOnly" {
                    durationSection
                }
                notesSection
                summarySection
            }
            .navigationTitle("editSet.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var exerciseInfo: some View {
        Section {
            if let exercise = workoutSet.exercise {
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

                    Text("common.set".localized(with: workoutSet.setNumber))
                        .foregroundStyle(.secondary)
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
            }
        }
    }

    private var notesSection: some View {
        Section("addSet.notes".localized) {
            TextField("addSet.addNote".localized, text: $notes, axis: .vertical)
                .lineLimit(2...5)
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

    private var summarySection: some View {
        Section("addSet.summary".localized) {
            if exerciseType == "timeOnly" {
                HStack {
                    Text("common.duration".localized)
                    Spacer()
                    Text(WorkoutSet.formatDuration(durationSeconds))
                        .foregroundStyle(.secondary)
                }
            } else if exerciseType == "repsOnly" {
                HStack {
                    Text("\(reps) \("common.reps".localized)")
                    Spacer()
                }
            } else {
                HStack {
                    Text("addSet.volumeLabel".localized(with: Int(weight * Double(reps))))
                    Spacer()
                }

                HStack {
                    Text("addSet.est1RM".localized)
                    Spacer()
                    Text("\(String(format: "%.1f", weight * (1 + Double(reps) / 30))) kg")
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)
                }
            }
        }
    }

    private func saveChanges() {
        workoutSet.weightKg = exerciseType == "weightReps" ? weight : 0
        workoutSet.reps = exerciseType == "timeOnly" ? 0 : reps
        workoutSet.durationSeconds = exerciseType == "timeOnly" ? durationSeconds : 0
        workoutSet.notes = notes

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Exercise.self, WorkoutSet.self, configurations: config)

    let exercise = Exercise(name: "Bench Press", muscleGroup: "chest")
    let set = WorkoutSet(exercise: exercise, weightKg: 60, reps: 10, setNumber: 1)

    return EditSetView(workoutSet: set)
        .modelContainer(container)
}
