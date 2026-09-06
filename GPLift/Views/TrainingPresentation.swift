import SwiftUI

struct TrainingCategoryIcon: View {
    let category: ExerciseCategory

    var body: some View {
        Image(systemName: category.systemImage)
            .accessibilityLabel(category.localizedName)
    }
}

struct TrainingCategorySummary: View {
    let category: ExerciseCategory
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            TrainingCategoryIcon(category: category)
                .frame(width: 16)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AppTextStyle.caption)
        .foregroundStyle(.secondary)
    }
}

struct ExerciseClassificationView: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 6) {
            TrainingCategoryIcon(category: exercise.resolvedCategory)
            Text(exercise.resolvedCategory.localizedName)
            if !exercise.muscleGroup.isEmpty {
                Text("·")
                Text(exercise.localizedMuscleGroup)
            }
        }
        .font(AppTextStyle.caption)
        .foregroundStyle(.secondary)
    }
}

struct CardioSetMetrics: View {
    let workoutSet: WorkoutSet
    var durationFont: Font = AppTextStyle.bodyStrong

    var body: some View {
        HStack(spacing: 6) {
            Text(workoutSet.formattedCardioDuration)
                .font(durationFont)
                .foregroundStyle(.primary)
            if let average = workoutSet.averageHeartRate {
                Text("common.averageHeartRateShort".localized(with: average))
                    .font(AppTextStyle.caption2Strong)
                    .foregroundStyle(.secondary)
            }
            if let maximum = workoutSet.maxHeartRate {
                Text("common.maxHeartRateShort".localized(with: maximum))
                    .font(AppTextStyle.caption2Strong)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
