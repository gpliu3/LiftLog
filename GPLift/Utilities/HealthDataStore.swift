import Foundation
import HealthKit

/// Read-only bridge to Apple Health. Values are kept in memory for display and export only;
/// nothing is written to Health or to the app's own store.
@MainActor
@Observable
final class HealthDataStore {
    static let shared = HealthDataStore()

    private static let enabledKey = "healthDataEnabled"
    private static let hintDismissedKey = "healthDataHintDismissed"

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var isDemo = false

    let isAvailable: Bool
    private(set) var isEnabled: Bool
    private(set) var metrics: [Date: DailyHealth] = [:]

    var isHintDismissed: Bool {
        didSet { UserDefaults.standard.set(isHintDismissed, forKey: Self.hintDismissedKey) }
    }

    private init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        isHintDismissed = UserDefaults.standard.bool(forKey: Self.hintDismissedKey)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-HealthDemoData") {
            isDemo = true
            isEnabled = true
            metrics = Self.demoMetrics()
        }
        #endif
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis)]
    }

    /// Shows the system permission sheet the first time. iOS never reveals whether read access
    /// was granted, so a declined permission simply looks like "no data".
    func enable() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
        } catch {
            isEnabled = false
        }
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        metrics = [:]
    }

    /// Loads days from `start` through today into `metrics` and returns that range.
    @discardableResult
    func refresh(from start: Date, to end: Date = Date()) async -> [Date: DailyHealth] {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        guard isEnabled, isAvailable || isDemo, firstDay <= lastDay else { return [:] }
        if isDemo { return metrics.filter { $0.key >= firstDay && $0.key <= lastDay } }

        let today = calendar.startOfDay(for: Date())
        // Steps keep accumulating during the day, so only completed days are shown.
        async let steps = stepsByDay(from: firstDay, before: min(today, calendar.date(byAdding: .day, value: 1, to: lastDay) ?? today))
        async let sleep = sleepMinutesByDay(from: firstDay, through: lastDay)
        let (stepValues, sleepValues) = await (steps, sleep)

        var loaded: [Date: DailyHealth] = [:]
        for (day, value) in stepValues { loaded[day, default: DailyHealth()].steps = value }
        for (day, value) in sleepValues where day >= firstDay && day <= lastDay {
            loaded[day, default: DailyHealth()].sleepMinutes = value
        }

        guard isEnabled else { return [:] }
        metrics = metrics.filter { $0.key < firstDay || $0.key > lastDay }.merging(loaded) { _, new in new }
        return loaded
    }

    private func stepsByDay(from firstDay: Date, before endDay: Date) async -> [Date: Int] {
        guard firstDay < endDay else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: firstDay, end: endDay, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.stepCount),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: firstDay,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, _ in
                var result: [Date: Int] = [:]
                collection?.enumerateStatistics(from: firstDay, to: endDay) { statistics, _ in
                    guard statistics.startDate < endDay,
                          let sum = statistics.sumQuantity()?.doubleValue(for: .count()) else { return }
                    result[statistics.startDate] = Int(sum.rounded())
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private func sleepMinutesByDay(from firstDay: Date, through lastDay: Date) async -> [Date: Int] {
        let calendar = Calendar.current
        // The night that ends on `firstDay` starts the evening before.
        let queryStart = calendar.date(byAdding: .day, value: -1, to: firstDay) ?? firstDay
        let queryEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: [])
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))

        let intervals: [DateInterval] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let asleep = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) && $0.endDate > $0.startDate }
                    .map { DateInterval(start: $0.startDate, end: $0.endDate) }
                continuation.resume(returning: asleep)
            }
            store.execute(query)
        }
        return SleepAggregator.minutesByDay(asleep: intervals, calendar: calendar)
    }

    #if DEBUG
    /// Deterministic sample values for UI checks in the simulator (`-HealthDemoData`).
    private static func demoMetrics() -> [Date: DailyHealth] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [Date: DailyHealth] = [:]
        for offset in 0..<45 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let seed = calendar.component(.day, from: day)
            result[day] = DailyHealth(
                steps: offset == 0 ? nil : 4_200 + (seed * 613) % 9_000,
                sleepMinutes: seed % 9 == 0 ? nil : 345 + (seed * 37) % 150
            )
        }
        return result
    }
    #endif
}
