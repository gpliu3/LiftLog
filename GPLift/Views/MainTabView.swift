import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @State private var languageManager = LanguageManager.shared

    private enum AppTab: Hashable {
        case today
        case history
        case exercises
        case progress
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tabContent(.today) {
                TodayView()
            }
                .tabItem {
                    Label("tab.today".localized, systemImage: "calendar")
                }
                .tag(AppTab.today)

            tabContent(.history) {
                HistoryView()
            }
                .tabItem {
                    Label("tab.history".localized, systemImage: "clock")
                }
                .tag(AppTab.history)

            tabContent(.exercises) {
                ExerciseListView()
            }
                .tabItem {
                    Label("tab.exercises".localized, systemImage: "dumbbell")
                }
                .tag(AppTab.exercises)

            tabContent(.progress) {
                ProgressChartView()
            }
                .tabItem {
                    Label("tab.progress".localized, systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.progress)

            tabContent(.settings) {
                SettingsView()
            }
                .tabItem {
                    Label("tab.settings".localized, systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.orange)
        .id(languageManager.currentLanguage) // Force refresh when language changes
    }

    @ViewBuilder
    private func tabContent<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        if selectedTab == tab {
            content()
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self], inMemory: true)
}
