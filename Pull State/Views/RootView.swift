import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [AppSettings]

    private var settings: AppSettings? { settingsQuery.first }

    var body: some View {
        Group {
            if let settings {
                if settings.hasCompletedOnboarding {
                    MainTabView(settings: settings)
                } else {
                    OnboardingFlow(settings: settings)
                }
            } else {
                Color.clear
            }
        }
        .preferredColorScheme(colorScheme)
        .task {
            SeedData.installIfNeeded(context: context)
        }
    }

    private var colorScheme: ColorScheme? {
        switch settings?.appearance {
        case .light: return .light
        case .dark:  return .dark
        default:     return nil
        }
    }
}
