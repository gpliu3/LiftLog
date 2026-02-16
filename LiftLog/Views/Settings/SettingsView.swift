import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var languageManager = LanguageManager.shared
    @State private var settingsManager = SettingsManager.shared
    @State private var showingRestoreDefaultsAlert = false
    @State private var restoredExerciseCount = 0
    @State private var showRestoreResult = false

    var body: some View {
        NavigationStack {
            List {
                if showRestoreResult {
                    restoreResultSection
                }
                languageSection
                workoutSection
                exerciseLibrarySection
                aboutSection
            }
            .navigationTitle("settings.title".localized)
            .alert("settings.restoreDefaultsConfirmTitle".localized, isPresented: $showingRestoreDefaultsAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("settings.restoreDefaultsAction".localized) {
                    restoreDefaultExercises()
                }
            } message: {
                Text("settings.restoreDefaultsConfirmMessage".localized)
            }
        }
        .id(languageManager.currentLanguage)
    }

    private var restoreResultSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("settings.restoreDefaultsResult".localized(with: restoredExerciseCount))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.green.opacity(0.1))
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

    private var exerciseLibrarySection: some View {
        Section("settings.exerciseLibrary".localized) {
            Button {
                showingRestoreDefaultsAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.restoreDefaults".localized)
                            .foregroundStyle(.primary)
                        Text("settings.restoreDefaultsDescription".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
    }

    private func restoreDefaultExercises() {
        let existingNames = Set(exercises.map(\.name))
        var inserted = 0

        for exercise in Exercise.sampleExercises() where !existingNames.contains(exercise.name) {
            modelContext.insert(exercise)
            inserted += 1
        }

        if inserted > 0 {
            do {
                try modelContext.save()
            } catch {
                print("Failed to restore default exercises: \(error)")
            }
        }

        restoredExerciseCount = inserted
        withAnimation {
            showRestoreResult = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showRestoreResult = false
            }
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
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
