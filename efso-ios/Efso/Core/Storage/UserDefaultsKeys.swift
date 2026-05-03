import Foundation

/// Type-safe UserDefaults keys.
enum UDKey: String {
    case onboardingCompleted = "efso.onboarding.completed"
    case lastActiveDate = "efso.lastActiveDate"
    case currentArchetype = "efso.archetype.primary"
    /// AI kullanım onayı (KVKK + Apple Review 4.8). Onay yoksa hiç LLM
    /// çağrısı yapılmaz; ProfileView üzerinden geri çekilebilir.
    case aiConsentGiven = "efso.ai.consentGiven"
    /// Home topbar archetype butonu için tek-seferlik spotlight overlay
    /// gösterildi mi? Dismiss edildiğinde true olur, bir daha açılmaz.
    case archetypeSpotlightSeen = "efso.spotlight.archetype.seen"
    /// Home mode listesi ilk-kullanım hint'i gösterildi mi?
    case modeHintSeen = "efso.hint.mode.seen"
}

extension UserDefaults {
    func bool(_ key: UDKey) -> Bool { bool(forKey: key.rawValue) }
    func string(_ key: UDKey) -> String? { string(forKey: key.rawValue) }
    func date(_ key: UDKey) -> Date? { object(forKey: key.rawValue) as? Date }
    func set(_ value: Any?, _ key: UDKey) { set(value, forKey: key.rawValue) }
}
