import Foundation

enum OnboardingTourManager {
    static func shouldShowPostDefaultTour(settings: JunctionSettings, status: DefaultWebBrowserStatus) -> Bool {
        status.isJunctionDefaultForHTTPAndHTTPS
            && settings.toursCompleted["postDefault"] != true
            && settings.hasCompletedOnboarding
    }

    static func markPostDefaultTourComplete(store: SettingsStore = .shared) {
        store.settings.toursCompleted["postDefault"] = true
    }
}
