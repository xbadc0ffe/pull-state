import SwiftUI
import SwiftData

/// Top-level scene content. Decides between onboarding and the main tab UI
/// based on `AppSettings.hasCompletedOnboarding`, and applies the user's
/// chosen `preferredColorScheme`. Triggers `SeedData.installIfNeeded` on
/// appear so the singleton settings row exists.
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
