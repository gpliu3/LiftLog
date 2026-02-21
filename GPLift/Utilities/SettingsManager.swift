import Foundation
import SwiftUI

enum DefaultSetPreference: String, CaseIterable, Identifiable {
    case firstSet = "first"
    case lastSet = "last"

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .firstSet:
            return "settings.defaultSet.first"
        case .lastSet:
            return "settings.defaultSet.last"
        }
    }

    var descriptionKey: String {
        switch self {
        case .firstSet:
            return "settings.defaultSet.firstDesc"
        case .lastSet:
            return "settings.defaultSet.lastDesc"
        }
    }
}

@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    private let defaultSetKey = "defaultSetPreference"
    private let todayMetricsDayKey = "todayMetricsDayKey"
    private let todayBodyWeightKey = "todayBodyWeightKg"
    private let todayWaistKey = "todayWaistCm"

    var defaultSetPreference: DefaultSetPreference {
        didSet {
            UserDefaults.standard.set(defaultSetPreference.rawValue, forKey: defaultSetKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: defaultSetKey),
           let preference = DefaultSetPreference(rawValue: saved) {
            self.defaultSetPreference = preference
        } else {
            self.defaultSetPreference = .lastSet
        }
    }

    func saveTodayBodyMetrics(bodyWeightKg: Double?, waistCm: Double?, for day: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(dayKey(for: day), forKey: todayMetricsDayKey)

        if let bodyWeightKg {
            defaults.set(bodyWeightKg, forKey: todayBodyWeightKey)
        } else {
            defaults.removeObject(forKey: todayBodyWeightKey)
        }

        if let waistCm {
            defaults.set(waistCm, forKey: todayWaistKey)
        } else {
            defaults.removeObject(forKey: todayWaistKey)
        }
    }

    func todayBodyMetrics(for day: Date = Date()) -> (bodyWeightKg: Double?, waistCm: Double?) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: todayMetricsDayKey) == dayKey(for: day) else {
            return (nil, nil)
        }

        let bodyWeight = defaults.object(forKey: todayBodyWeightKey) as? Double
        let waist = defaults.object(forKey: todayWaistKey) as? Double
        return (bodyWeight, waist)
    }

    private func dayKey(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }
}
