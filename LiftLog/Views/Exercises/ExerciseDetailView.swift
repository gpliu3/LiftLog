import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @State private var showingEditSheet = false

    private var recentSets: [WorkoutSet] {
        exercise.workoutSets
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .map { $0 }
    }

    private var personalRecord: Double? {
        exercise.workoutSets.map { $0.weightKg }.max()
    }

    private var totalVolume: Double {
        exercise.workoutSets.reduce(0) { $0 + $1.volume }
    }

    var body: some View {
        NavigationStack {
            List {
                detailsSection
                statsSection

                if !recentSets.isEmpty {
                    recentActivitySection
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("exerciseDetail.done".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("exerciseDetail.edit".localized) {
                        showingEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                ExerciseEditView(exercise: exercise)
            }
        }
    }

    private var detailsSection: some View {
        Section {
            if !exercise.muscleGroup.isEmpty {
                LabeledContent("exerciseDetail.muscleGroup".localized, value: exercise.localizedMuscleGroup)
            }

            if !exercise.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("exerciseDetail.notes".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(exercise.notes)
                }
            }

            LabeledContent("exerciseDetail.created".localized) {
                Text(exercise.createdAt, style: .date)
            }
        }
    }

    private var statsSection: some View {
        Section("exerciseDetail.statistics".localized) {
            LabeledContent("exerciseDetail.timesPerformed".localized, value: "exerciseDetail.sessionsUnit".localized(with: exercise.timesPerformed))

            if let pr = personalRecord {
                LabeledContent("exerciseDetail.personalRecord".localized) {
                    Text("\(String(format: "%.1f", pr)) kg")
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                }
            }

            LabeledContent("exerciseDetail.totalVolume".localized) {
                Text("\(String(format: "%.0f", totalVolume)) kg")
            }

            LabeledContent("exerciseDetail.totalSets".localized, value: "\(exercise.workoutSets.count)")
        }
    }

    private var recentActivitySection: some View {
        Section("exerciseDetail.recentActivity".localized) {
            ForEach(recentSets) { set in
                HStack {
                    Text(set.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("common.set".localized(with: set.setNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(String(format: "%.1f", set.weightKg)) kg × \(set.reps)")
                        .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    let exercise = Exercise(name: "Bench Press", notes: "Keep shoulders back", muscleGroup: "Chest")
    return ExerciseDetailView(exercise: exercise)
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
