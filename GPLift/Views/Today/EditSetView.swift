import SwiftUI
import SwiftData

struct EditSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let workoutSet: WorkoutSet

    @State private var weight: Double
    @State private var reps: Int
    @State private var durationSeconds: Int
    @State private var cardioMinutes: Int
    @State private var averageHeartRateText: String
    @State private var maxHeartRateText: String
    @State private var rirSelection: Int
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
        _cardioMinutes = State(initialValue: max(1, workoutSet.cardioMinutes))
        _averageHeartRateText = State(initialValue: workoutSet.averageHeartRate.map(String.init) ?? "")
        _maxHeartRateText = State(initialValue: workoutSet.maxHeartRate.map(String.init) ?? "")
        _rirSelection = State(initialValue: workoutSet.rir ?? -1)
        _notes = State(initialValue: workoutSet.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                exerciseInfo
                if workoutSet.exercise?.isCardio == true {
                    cardioDurationSection
                    heartRateSection
                } else if exerciseType == "weightReps" {
                    weightSection
                }
                if exerciseType == "weightReps" || exerciseType == "repsOnly" {
                    repsSection
                }
                if exerciseType == "timeOnly" {
                    durationSection
                }
                if workoutSet.exercise?.isCardio != true {
                    rirSection
                }
                notesSection
                summarySection
            }
            .navigationTitle("editSet.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .font(AppTextStyle.body)
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
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var averageHeartRate: Int? {
        Int(averageHeartRateText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var maxHeartRate: Int? {
        Int(maxHeartRateText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSave: Bool {
        guard workoutSet.exercise?.isCardio == true else { return true }
        guard cardioMinutes > 0 else { return false }
        return WorkoutSet.hasValidCardioHeartRates(
            average: averageHeartRate,
            maximum: maxHeartRate
        )
    }

    private var exerciseInfo: some View {
        Section {
            if let exercise = workoutSet.exercise {
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

                    Text(exercise.isCardio
                         ? "common.session".localized(with: workoutSet.setNumber)
                         : "common.set".localized(with: workoutSet.setNumber))
                        .foregroundStyle(.secondary)
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
            }
        }
    }

    private var notesSection: some View {
        Section("addSet.notes".localized) {
            TextField("addSet.addNote".localized, text: $notes, axis: .vertical)
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
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Spacer()

                TextField("Weight", value: $weight, format: .number)
                    .font(AppTextStyle.metric)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 84)

                Text("kg")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    weight += 2.5
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

    private var cardioDurationSection: some View {
        Section("addSet.durationMinutes".localized) {
            Stepper(value: $cardioMinutes, in: 1...1440) {
                HStack {
                    TextField("0", value: $cardioMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .font(AppTextStyle.metric)
                    Spacer()
                    Text("common.minutesUnit".localized)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var heartRateSection: some View {
        Section {
            heartRateField("addSet.averageHeartRate".localized, text: $averageHeartRateText)
            heartRateField("addSet.maxHeartRate".localized, text: $maxHeartRateText)
            if !canSave {
                Text("addSet.invalidHeartRate".localized)
                    .font(AppTextStyle.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("today.cardio".localized)
        } footer: {
            Text("addSet.heartRateOptional".localized)
        }
    }

    private func heartRateField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
            Text("addSet.heartRateUnit".localized)
                .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        Section("addSet.summary".localized) {
            if workoutSet.exercise?.isCardio == true {
                LabeledContent("common.duration".localized, value: "common.minutesShort".localized(with: cardioMinutes))
                if let averageHeartRate {
                    LabeledContent("addSet.averageHeartRate".localized, value: "\(averageHeartRate) \("addSet.heartRateUnit".localized)")
                }
                if let maxHeartRate {
                    LabeledContent("addSet.maxHeartRate".localized, value: "\(maxHeartRate) \("addSet.heartRateUnit".localized)")
                }
            } else if exerciseType == "timeOnly" {
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
        guard canSave else { return }
        let isCardio = workoutSet.exercise?.isCardio == true
        workoutSet.weightKg = !isCardio && exerciseType == "weightReps" ? weight : 0
        workoutSet.reps = isCardio || exerciseType == "timeOnly" ? 0 : reps
        workoutSet.durationSeconds = isCardio ? cardioMinutes * 60 : (exerciseType == "timeOnly" ? durationSeconds : 0)
        workoutSet.rir = isCardio || rirSelection < 0 ? nil : rirSelection
        workoutSet.averageHeartRate = isCardio ? averageHeartRate : nil
        workoutSet.maxHeartRate = isCardio ? maxHeartRate : nil
        workoutSet.notes = notes

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save set edit: \(error)")
            return
        }

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
