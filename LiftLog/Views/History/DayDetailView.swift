import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allSets: [WorkoutSet]

    let date: Date

    private var daySets: [WorkoutSet] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return allSets.filter { calendar.startOfDay(for: $0.date) == dayStart }
    }

    private var groupedByExercise: [(Exercise, [WorkoutSet])] {
        let grouped = Dictionary(grouping: daySets) { $0.exercise }
        return grouped.compactMap { (exercise, sets) in
            guard let exercise = exercise else { return nil }
            return (exercise, sets.sorted { $0.setNumber < $1.setNumber })
        }.sorted { $0.0.displayName < $1.0.displayName }
    }

    private var totalVolume: Double {
        daySets.reduce(0) { $0 + $1.volume }
    }

    private var uniqueExercises: Int {
        Set(daySets.compactMap { $0.exercise?.id }).count
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                ForEach(groupedByExercise, id: \.0.id) { exercise, sets in
                    Section {
                        ForEach(sets) { set in
                            DaySetRowView(workoutSet: set)
                        }
                        .onDelete { indexSet in
                            deleteSets(at: indexSet, from: sets)
                        }

                        exerciseSummaryRow(for: sets)
                    } header: {
                        HStack {
                            Text(exercise.displayName)
                            if !exercise.muscleGroup.isEmpty {
                                Spacer()
                                Text(exercise.localizedMuscleGroup)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("dayDetail.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                VStack {
                    Text("\(daySets.count)")
                        .font(.title2.bold())
                    Text("dayDetail.sets".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack {
                    Text("\(uniqueExercises)")
                        .font(.title2.bold())
                    Text("dayDetail.exercises".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack {
                    Text(String(format: "%.0f", totalVolume))
                        .font(.title2.bold())
                    Text("dayDetail.volume".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
    }

    private func exerciseSummaryRow(for sets: [WorkoutSet]) -> some View {
        let exerciseType = sets.first?.exercise?.exerciseType ?? "weightReps"
        return HStack {
            Text("dayDetail.subtotal".localized)
                .foregroundStyle(.secondary)
            Spacer()
            if exerciseType == "timeOnly" {
                let totalSeconds = sets.reduce(0) { $0 + $1.durationSeconds }
                Text("dayDetail.setsDuration".localized(with: sets.count, WorkoutSet.formatDuration(totalSeconds)))
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if exerciseType == "repsOnly" {
                let totalReps = sets.reduce(0) { $0 + $1.reps }
                Text("dayDetail.setsReps".localized(with: sets.count, totalReps))
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else {
                let volume = sets.reduce(0) { $0 + $1.volume }
                Text("dayDetail.setsVolume".localized(with: sets.count, Int(volume)))
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = LanguageManager.shared.currentLanguage.locale ?? Locale.current
        return formatter.string(from: date)
    }

    private func deleteSets(at offsets: IndexSet, from sets: [WorkoutSet]) {
        for index in offsets {
            modelContext.delete(sets[index])
        }
    }
}

struct DaySetRowView: View {
    let workoutSet: WorkoutSet

    private var exerciseType: String {
        workoutSet.exercise?.exerciseType ?? "weightReps"
    }

    var body: some View {
        HStack {
            Text("common.set".localized(with: workoutSet.setNumber))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            if exerciseType == "timeOnly" {
                Text(workoutSet.formattedDuration)
                    .fontWeight(.medium)
            } else if exerciseType == "repsOnly" {
                Text("\(workoutSet.reps) \("common.reps".localized)")
                    .fontWeight(.medium)
            } else {
                Text("\(String(format: "%.1f", workoutSet.weightKg)) kg")
                    .fontWeight(.medium)

                Text("×")
                    .foregroundStyle(.secondary)

                Text("\(workoutSet.reps) \("common.reps".localized)")
                    .fontWeight(.medium)

                Spacer()

                Text("\(Int(workoutSet.volume)) kg")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    DayDetailView(date: Date())
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
