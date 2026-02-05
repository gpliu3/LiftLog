import SwiftUI

struct SettingsView: View {
    @State private var languageManager = LanguageManager.shared
    @State private var settingsManager = SettingsManager.shared

    var body: some View {
        NavigationStack {
            List {
                languageSection
                workoutSection
                aboutSection
            }
            .navigationTitle("settings.title".localized)
        }
        .id(languageManager.currentLanguage)
    }

    private var languageSection: some View {
        Section("settings.languageSection".localized) {
            NavigationLink {
                LanguageSelectionView()
            } label: {
                HStack {
                    Text("settings.language".localized)
                    Spacer()
                    Text(languageManager.currentLanguage.displayName)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var workoutSection: some View {
        Section {
            NavigationLink {
                DefaultSetSelectionView()
            } label: {
                HStack {
                    Text("settings.defaultSet".localized)
                    Spacer()
                    Text(settingsManager.defaultSetPreference.displayNameKey.localized)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("settings.workoutSection".localized)
        } footer: {
            Text("settings.defaultSetFooter".localized)
        }
    }

    private var aboutSection: some View {
        Section("settings.about".localized) {
            HStack {
                Text("settings.appName".localized)
                Spacer()
                Text("settings.version".localized + " 1.0.0")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LanguageSelectionView: View {
    @State private var languageManager = LanguageManager.shared
    @State private var selectedLanguage: AppLanguage

    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }

    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    selectedLanguage = language
                    languageManager.currentLanguage = language
                } label: {
                    HStack {
                        Text(language.displayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        if selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.language".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DefaultSetSelectionView: View {
    @State private var settingsManager = SettingsManager.shared

    var body: some View {
        List {
            ForEach(DefaultSetPreference.allCases) { preference in
                Button {
                    settingsManager.defaultSetPreference = preference
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preference.displayNameKey.localized)
                                .foregroundStyle(.primary)
                            Text(preference.descriptionKey.localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if settingsManager.defaultSetPreference == preference {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.defaultSet".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
