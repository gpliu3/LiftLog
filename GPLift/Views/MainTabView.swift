import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var languageManager = LanguageManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("tab.today".localized, systemImage: "calendar")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("tab.history".localized, systemImage: "clock")
                }
                .tag(1)

            ExerciseListView()
                .tabItem {
                    Label("tab.exercises".localized, systemImage: "dumbbell")
                }
                .tag(2)

            ProgressChartView()
                .tabItem {
                    Label("tab.progress".localized, systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("tab.settings".localized, systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.orange)
        .id(languageManager.currentLanguage) // Force refresh when language changes
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
