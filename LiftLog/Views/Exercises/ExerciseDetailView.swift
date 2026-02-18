import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @State private var showingEditSheet = false

    private var recentSets: [WorkoutSet] {
        orderedRecentSets
            .prefix(20)
            .map { $0 }
    }

    private var orderedRecentSets: [WorkoutSet] {
        let calendar = Calendar.current
        return exercise.workoutSets.sorted { lhs, rhs in
            let lhsDay = calendar.startOfDay(for: lhs.date)
            let rhsDay = calendar.startOfDay(for: rhs.date)

            if lhsDay != rhsDay {
                return lhsDay > rhsDay
            }

            if lhs.setNumber != rhs.setNumber {
                return lhs.setNumber < rhs.setNumber
            }

            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private var personalRecord: Double? {
        exercise.workoutSets.map { $0.weightKg }.max()
    }

    private var durationPR: Int? {
        exercise.workoutSets.map { $0.durationSeconds }.max()
    }

    private var totalVolume: Double {
        exercise.workoutSets.reduce(0) { $0 + $1.volume }
    }

    private var totalReps: Int {
        exercise.workoutSets.reduce(0) { $0 + $1.reps }
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
            .environment(\.defaultMinListRowHeight, 28)
            .navigationTitle(exercise.displayName)
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

            if !exercise.isWeightReps {
                LabeledContent("exerciseEdit.exerciseType".localized, value: exercise.localizedExerciseType)
            }

            if !exercise.displayNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("exerciseDetail.notes".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(exercise.displayNotes)
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

            if exercise.isWeightReps {
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
            } else if exercise.isTimeOnly {
                if let pr = durationPR, pr > 0 {
                    LabeledContent("progress.bestDuration".localized) {
                        Text(WorkoutSet.formatDuration(pr))
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                }
            } else if exercise.isRepsOnly {
                LabeledContent("progress.totalReps".localized, value: "\(totalReps)")
            }

            LabeledContent("exerciseDetail.totalSets".localized, value: "\(exercise.workoutSets.count)")
        }
    }

    private var recentActivitySection: some View {
        Section("exerciseDetail.recentActivity".localized) {
            ForEach(recentSets) { set in
                HStack(spacing: 8) {
                    Text(set.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("common.set".localized(with: set.setNumber))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if exercise.isTimeOnly {
                        Text(set.formattedDuration)
                            .fontWeight(.medium)
                    } else if exercise.isRepsOnly {
                        Text("\(set.reps) \("common.reps".localized)")
                            .fontWeight(.medium)
                    } else {
                        Text("\(String(format: "%.1f", set.weightKg)) kg × \(set.reps)")
                            .fontWeight(.medium)
                    }

                    if let rir = set.rir {
                        Text("RIR \(rir)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    if set.isPersonalBest(in: exercise.workoutSets) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
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
