import Foundation

/// Environment configuration.
///
/// Supabase URL + anon key are PUBLIC — anyone calling the public API can see them
/// in network traffic, and Row Level Security on every table is what actually protects
/// user data. Embedding them here is intentional and matches industry practice
/// (Firebase / Supabase / Amplify all embed public client config in app binaries).
///
/// Real secrets (SERVICE_ROLE_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY) live ONLY in
/// Supabase secrets / edge function env — never in this binary.
///
/// Optional analytics keys are read from Info.plist (xcconfig populated). Empty = no-op.
enum Configuration {
    // MARK: - Supabase (public client config)

    static let supabaseURL: URL = URL(string: "https://ftjdfcvlsqrjlvebbsqi.supabase.co")!

    static let supabaseAnonKey: String =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ0amRmY3Zsc3Fyamx2ZWJic3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczNTg5NjEsImV4cCI6MjA5MjkzNDk2MX0.xG2rWj4ee_rxiIM0RdJShMcW2dkaI0l-OMBcpfTzwNc"

    // MARK: - Optional vendor keys (xcconfig → Info.plist)

    static let revenueCatAPIKey: String = infoString("REVENUECAT_API_KEY") ?? ""
    static let posthogAPIKey: String = infoString("POSTHOG_API_KEY") ?? ""
    static let posthogHost: String = "https://us.i.posthog.com"
    static let sentryDSN: String = infoString("SENTRY_DSN") ?? ""

    // MARK: - Build info

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "to.tikla.efso"
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static func infoString(_ key: String) -> String? {
        let s = Bundle.main.object(forInfoDictionaryKey: key) as? String
        return (s?.isEmpty == true) ? nil : s
    }
}
