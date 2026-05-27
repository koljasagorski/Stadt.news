import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                MainView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: settings.hasCompletedOnboarding)
    }
}
