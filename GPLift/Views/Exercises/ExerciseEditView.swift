import SwiftUI
import SwiftData

struct ExerciseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?

    @State private var category: ExerciseCategory
    @State private var name: String = ""
    @State private var exerciseType: String = "weightReps"
    @State private var muscleGroup: String = ""
    @State private var notes: String = ""
    @State private var isActive = true
    @State private var showingDeleteAlert = false

    init(exercise: Exercise?, initialCategory: ExerciseCategory = .strength) {
        self.exercise = exercise
        _category = State(initialValue: exercise?.resolvedCategory ?? initialCategory)
    }

    private var isEditing: Bool {
        exercise != nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exercises.category".localized) {
                    Picker("exercises.category".localized, selection: $category) {
                        ForEach(ExerciseCategory.allCases) { category in
                            Text(category.localizedName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(exercise?.workoutSets.isEmpty == false)

                    if exercise?.workoutSets.isEmpty == false {
                        Text("exerciseEdit.categoryLocked".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("exerciseEdit.name".localized) {
                    TextField("exerciseEdit.namePlaceholder".localized, text: $name)
                        .textInputAutocapitalization(.words)
                }

                if category == .strength {
                    Section("exerciseEdit.exerciseType".localized) {
                        Picker("exerciseEdit.exerciseType".localized, selection: $exerciseType) {
                            ForEach(Exercise.localizedExerciseTypes, id: \.key) { type in
                                Text(type.display).tag(type.key)
                            }
                        }
                        .pickerStyle(.segmented)
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
                        let defaultNotes = exercise?.displayNotes ?? ""
                        let placeholder = !defaultNotes.isEmpty && notes.isEmpty
                            ? defaultNotes
                            : "exerciseEdit.notesPlaceholder".localized
                        TextField(placeholder, text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                        if !defaultNotes.isEmpty && notes.isEmpty {
                            Text("exerciseEdit.defaultNotesHint".localized)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("exerciseEdit.visibility".localized) {
                    Toggle("exerciseEdit.active".localized, isOn: $isActive)

                    Text(isActive ? "exerciseEdit.activeHint".localized : "exerciseEdit.inactiveHint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    category = exercise.resolvedCategory
                    exerciseType = exercise.exerciseType
                    muscleGroup = exercise.muscleGroup
                    notes = exercise.notes
                    isActive = exercise.isActiveResolved
                }
            }
        }
    }

    private func saveExercise() {
        if let exercise = exercise {
            // Update existing
            exercise.name = name.trimmingCharacters(in: .whitespaces)
            if exercise.workoutSets.isEmpty {
                exercise.category = category.rawValue
            }
            if category == .cardio {
                exercise.exerciseType = "cardio"
                exercise.muscleGroup = ""
                exercise.notes = ""
            } else {
                exercise.exerciseType = exerciseType == "cardio" ? "weightReps" : exerciseType
                exercise.muscleGroup = muscleGroup
                exercise.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            exercise.isActive = isActive
        } else {
            // Create new
            let newExercise = Exercise(
                name: name.trimmingCharacters(in: .whitespaces),
                notes: category == .strength ? notes.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                muscleGroup: category == .strength ? muscleGroup : "",
                exerciseType: category == .strength ? exerciseType : "cardio",
                category: category,
                isActive: isActive
            )
            modelContext.insert(newExercise)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save exercise: \(error)")
        }

        dismiss()
    }

    private func deleteExercise() {
        if let exercise = exercise {
            modelContext.delete(exercise)
        }
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to delete exercise: \(error)")
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
