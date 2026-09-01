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
    private let weeklyCardioGoalKey = "weeklyCardioGoalMinutes"
    private static let defaultWeeklyCardioGoalMinutes = 60

    var defaultSetPreference: DefaultSetPreference {
        didSet {
            UserDefaults.standard.set(defaultSetPreference.rawValue, forKey: defaultSetKey)
        }
    }

    private(set) var weeklyCardioGoalMinutes: Int {
        didSet {
            UserDefaults.standard.set(weeklyCardioGoalMinutes, forKey: weeklyCardioGoalKey)
        }
    }

    func updateWeeklyCardioGoal(minutes: Int) {
        weeklyCardioGoalMinutes = max(5, minutes)
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: defaultSetKey),
           let preference = DefaultSetPreference(rawValue: saved) {
            self.defaultSetPreference = preference
        } else {
            self.defaultSetPreference = .lastSet
        }

        let savedCardioGoal = UserDefaults.standard.integer(forKey: weeklyCardioGoalKey)
        self.weeklyCardioGoalMinutes = savedCardioGoal > 0
            ? savedCardioGoal
            : Self.defaultWeeklyCardioGoalMinutes
    }
}
