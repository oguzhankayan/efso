import Foundation
import PostHog

/// Tek noktadan event log + identify. PostHog (feature flags + funnel).
///
/// API key boşsa SDK init edilmez — boş init PostHog tarafında batch
/// retry'ları başlatıyor ve simulator'da launch hang'ine sebep olabiliyor.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    private var posthogReady = false

    func bootstrap() {
        let phKey = Configuration.posthogAPIKey
        if !phKey.isEmpty {
            let phConfig = PostHogConfig(apiKey: phKey, host: Configuration.posthogHost)
            phConfig.captureScreenViews = false
            PostHogSDK.shared.setup(phConfig)
            posthogReady = true
        }
    }

    func identify(userID: UUID, archetype: String? = nil) {
        guard posthogReady else { return }
        var props: [String: Any] = ["app_version": Configuration.appVersion]
        if let archetype { props["archetype"] = archetype }
        PostHogSDK.shared.identify(userID.uuidString, userProperties: props)
    }

    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        guard posthogReady else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    func reset() {
        guard posthogReady else { return }
        PostHogSDK.shared.reset()
    }
}
