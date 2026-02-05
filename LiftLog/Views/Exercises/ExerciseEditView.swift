import SwiftUI
import SwiftData

struct ExerciseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?

    @State private var name: String = ""
    @State private var muscleGroup: String = ""
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false

    private var isEditing: Bool {
        exercise != nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exerciseEdit.name".localized) {
                    TextField("exerciseEdit.namePlaceholder".localized, text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("exerciseEdit.muscleGroup".localized) {
                    Picker("exerciseEdit.muscleGroup".localized, selection: $muscleGroup) {
                        Text("exerciseEdit.muscleGroupNone".localized).tag("")
                        ForEach(Exercise.localizedMuscleGroups, id: \.key) { group in
                            Text(group.display).tag(group.key)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("exerciseEdit.notes".localized) {
                    TextField("exerciseEdit.notesPlaceholder".localized, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Button("exerciseEdit.delete".localized, role: .destructive) {
                            showingDeleteAlert = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "exerciseEdit.editTitle".localized : "exerciseEdit.newTitle".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("exerciseEdit.cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("exerciseEdit.save".localized) {
                        saveExercise()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("exerciseEdit.deleteAlert".localized, isPresented: $showingDeleteAlert) {
                Button("exerciseEdit.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    deleteExercise()
                }
            } message: {
                Text("exerciseEdit.deleteMessage".localized)
            }
            .onAppear {
                if let exercise = exercise {
                    name = exercise.name
                    muscleGroup = exercise.muscleGroup
                    notes = exercise.notes
                }
            }
        }
    }

    private func saveExercise() {
        if let exercise = exercise {
            // Update existing
            exercise.name = name.trimmingCharacters(in: .whitespaces)
            exercise.muscleGroup = muscleGroup
            exercise.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Create new
            let newExercise = Exercise(
                name: name.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                muscleGroup: muscleGroup
            )
            modelContext.insert(newExercise)
        }

        dismiss()
    }

    private func deleteExercise() {
        if let exercise = exercise {
            modelContext.delete(exercise)
        }
        dismiss()
    }
}

#Preview("New") {
    ExerciseEditView(exercise: nil)
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}

#Preview("Edit") {
    let exercise = Exercise(name: "Bench Press", muscleGroup: "Chest")
    return ExerciseEditView(exercise: exercise)
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
