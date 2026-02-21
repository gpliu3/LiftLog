import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return String(localized: "settings.followSystem")
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }

    var locale: Locale? {
        switch self {
        case .system:
            return nil
        case .english:
            return Locale(identifier: "en")
        case .chinese:
            return Locale(identifier: "zh-Hans")
        }
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private let languageKey = "selectedLanguage"

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }

    private(set) var bundle: Bundle = .main

    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        updateBundle()
    }

    private func updateBundle() {
        let languageCode: String

        switch currentLanguage {
        case .system:
            // Use system preferred language
            if let preferredLanguage = Locale.preferredLanguages.first {
                if preferredLanguage.hasPrefix("zh") {
                    languageCode = "zh-Hans"
                } else {
                    languageCode = "en"
                }
            } else {
                languageCode = "en"
            }
        case .english:
            languageCode = "en"
        case .chinese:
            languageCode = "zh-Hans"
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = .main
        }
    }

    func localizedString(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

// String extension for easy localization
extension String {
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }

    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}
