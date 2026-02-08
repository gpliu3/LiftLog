import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var languageManager = LanguageManager.shared

    @State private var searchText = ""
    @State private var showingAddExercise = false
    @State private var selectedExercise: Exercise?

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(searchText) ||
            $0.localizedMuscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            exercise.muscleGroup.isEmpty ? "Other" : exercise.muscleGroup
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    emptyState
                } else {
                    exerciseList
                }
            }
            .navigationTitle("exercises.title".localized)
            .searchable(text: $searchText, prompt: "exercises.search".localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ExerciseEditView(exercise: nil)
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
        .id(languageManager.currentLanguage)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "exercises.noExercises".localized,
            systemImage: "dumbbell",
            description: Text("exercises.noExercisesDescription".localized)
        )
    }

    private var exerciseList: some View {
        List {
            ForEach(groupedExercises, id: \.0) { muscleGroup, exercises in
                Section(Exercise.localizedMuscleGroupName(for: muscleGroup)) {
                    ForEach(exercises) { exercise in
                        ExerciseRowView(exercise: exercise)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedExercise = exercise
                            }
                    }
                    .onDelete { indexSet in
                        deleteExercises(at: indexSet, from: exercises)
                    }
                }
            }
        }
    }

    private func deleteExercises(at offsets: IndexSet, from exercises: [Exercise]) {
        for index in offsets {
            modelContext.delete(exercises[index])
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.displayName)
                    .font(.headline)

                if !exercise.displayNotes.isEmpty {
                    Text(exercise.displayNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if exercise.timesPerformed > 0 {
                    Text("exercises.sessions".localized(with: exercise.timesPerformed))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.localizedMuscleGroup)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExerciseListView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
