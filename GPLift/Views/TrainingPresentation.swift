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
    let content: Text

    init(category: ExerciseCategory, text: String) {
        self.init(category: category, content: Text(text))
    }

    init(category: ExerciseCategory, content: Text) {
        self.category = category
        self.content = content
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            TrainingCategoryIcon(category: category)
                .frame(width: 16)
            content
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

/// Small "RIR n" capsule shown next to a set's metrics.
struct RIRBadge: View {
    let rir: Int

    var body: some View {
        Text("RIR \(rir)")
            .font(AppTextStyle.caption2Strong)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }
}

/// Read-only "20.0 kg 44 lb × 10 reps" line, with pounds de-emphasised.
enum WeightRepsText {
    static func make(for set: WorkoutSet) -> Text {
        let kilograms = Text(WeightUnit.kg.displayText(fromKilograms: set.weightKg))
        let pounds = Text(WeightUnit.lb.displayText(fromKilograms: set.weightKg))
            .fontWeight(.regular)
            .foregroundStyle(.secondary)
        return Text("\(kilograms) \(pounds) × \(set.reps) \("common.reps".localized)")
    }
}

/// Steps and time asleep for one day, e.g. "8,432 steps · 7h 12m", read from Apple Health.
struct HealthMetricsLine: View {
    let health: DailyHealth
    var showsStepsUnit = true
    var font: Font = AppTextStyle.caption

    var body: some View {
        HStack(spacing: 10) {
            if let steps = health.steps {
                metric(
                    icon: "figure.walk",
                    tint: .green,
                    text: showsStepsUnit ? "health.steps".localized(with: HealthFormat.steps(steps)) : HealthFormat.steps(steps),
                    label: "health.steps".localized(with: HealthFormat.steps(steps))
                )
            }
            if let minutes = health.sleepMinutes {
                metric(
                    icon: "bed.double.fill",
                    tint: .indigo,
                    text: HealthFormat.sleep(minutes: minutes),
                    label: "health.sleepLabel".localized(with: HealthFormat.sleep(minutes: minutes))
                )
            }
        }
        .font(font)
        .foregroundStyle(.secondary)
    }

    private func metric(icon: String, tint: Color, text: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .imageScale(.small)
            Text(text)
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
