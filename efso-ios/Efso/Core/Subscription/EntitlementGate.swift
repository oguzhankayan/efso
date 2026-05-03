import Foundation

/// Free vs premium feature gating.
///
/// Free tier (2026-05-01 itibariyle):
/// - 5 üretim / gün (cumulative — istediği modda, istediği tonda)
/// - 10 reply refinement / gün
/// - Tüm 4 mod açık (cevap, açılış, tonla, davet)
/// - Tüm 5 ton açık (default 3-ton kombosu + tek-ton seçimi)
///
/// Tek pitch, tek throttle: **5/gün cap.** Mode lock ve tone lock kaldırıldı
/// (sırayla 2026-05-01). Sebep: her iki kilit de "premium teaser"a benziyordu
/// ama kullanıcı feature'ın değerini denemeden çevrilmediği için conversion
/// düşüktü. 3/gün cap zaten yeterli throttle; premium pitch artık tek
/// cümlelik ve dürüst: "sınırsız üret".
///
/// Premium: hepsi sınırsız.
enum EntitlementGate {
    static let freeDailyLimit: Int = 5
    static let freeRefineLimit: Int = 10

    /// Bugün için kalan free generation kotası.
    /// Premium ise +∞ (Int.max).
    static func remainingDaily(isPremium: Bool, todayCount: Int) -> Int {
        if isPremium { return Int.max }
        return max(0, freeDailyLimit - todayCount)
    }

    /// Yeni generation başlatılabilir mi?
    static func canGenerate(isPremium: Bool, todayCount: Int) -> Bool {
        isPremium || todayCount < freeDailyLimit
    }

    /// Tüm tonlar her tier'a açık. Throttle 3/gün cap üzerinden.
    /// Geriye uyumluluk için imza korundu; her zaman true döner.
    static func canUseTone(_ tone: Tone?, isPremium: Bool) -> Bool {
        _ = tone; _ = isPremium
        return true
    }

    /// Tüm modlar her tier'a açık. Throttle 3/gün cap üzerinden.
    /// Geriye uyumluluk için imza korundu; her zaman true döner.
    static func canUseMode(_ mode: Mode, isPremium: Bool) -> Bool {
        _ = mode; _ = isPremium
        return true
    }

    /// Paywall trigger sebebi — UI'a hangi message gösterileceğini söyler.
    enum LockReason: Equatable, Identifiable {
        case dailyLimit
        case toneLocked(Tone)
        case modeLocked(Mode)
        /// Profile / settings ekranından kullanıcı bilinçli upgrade
        /// tıklaması. Bağlam-spesifik bir kilit yok; soft pitch.
        case userInitiated

        var id: String {
            switch self {
            case .dailyLimit: "daily-limit"
            case .toneLocked(let t): "tone-\(t.rawValue)"
            case .modeLocked(let m): "mode-\(m.rawValue)"
            case .userInitiated: "user-initiated"
            }
        }

        var headline: String {
            switch self {
            case .dailyLimit: "günlük 5 cevabın doldu."
            case .toneLocked(let t): "\(t.label.trLower) tonu premium."
            case .modeLocked(let m): "\(m.label.trLower) modu premium."
            case .userInitiated: "premium'a geç."
            }
        }

        var subline: String {
            switch self {
            case .dailyLimit: "premium ile sınırsız üret."
            case .toneLocked: "tüm tonlar + sınırsız üretim."
            case .modeLocked: "tüm modlar + sınırsız üretim."
            case .userInitiated: "tüm modlar + tüm tonlar + sınırsız üretim."
            }
        }
    }
}
