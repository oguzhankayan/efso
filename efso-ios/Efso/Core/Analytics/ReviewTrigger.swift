import StoreKit
import UIKit

/// Doğal anlarda App Store review dialog'u tetikler.
///
/// Apple yılda 3 kez gösteriyor, fazlasını yoksayıyor.
/// Biz sadece doğru anı seçiyoruz:
/// - İlk başarılı cevap kopyalandığında
/// - 3. ve 10. üretim tamamlandığında
/// - Pozitif feedback (👍) verildiğinde (ilk seferde)
@MainActor
enum ReviewTrigger {
    private static let copyTriggeredKey = "efso.review.copyTriggered"
    private static let feedbackTriggeredKey = "efso.review.feedbackTriggered"
    private static let lastPromptDateKey = "efso.review.lastPromptDate"

    /// Cevap kopyalandığında — kullanıcı değer aldığını kanıtlamış.
    static func onReplyCopied() {
        guard !UserDefaults.standard.bool(forKey: copyTriggeredKey) else { return }
        guard daysSinceLastPrompt() >= 14 else { return }
        UserDefaults.standard.set(true, forKey: copyTriggeredKey)
        requestReview()
    }

    /// Üretim başarıyla tamamlandığında — 3. ve 10. kullanımda.
    static func onGenerationCompleted(totalCount: Int) {
        guard totalCount == 3 || totalCount == 10 else { return }
        guard daysSinceLastPrompt() >= 14 else { return }
        requestReview()
    }

    /// Pozitif feedback verildiğinde — ilk seferde.
    static func onPositiveFeedback() {
        guard !UserDefaults.standard.bool(forKey: feedbackTriggeredKey) else { return }
        guard daysSinceLastPrompt() >= 14 else { return }
        UserDefaults.standard.set(true, forKey: feedbackTriggeredKey)
        requestReview()
    }

    private static func requestReview() {
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        AppStore.requestReview(in: scene)
    }

    private static func daysSinceLastPrompt() -> Int {
        guard let last = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date else {
            return Int.max
        }
        return Calendar.istanbul.dateComponents([.day], from: last, to: Date()).day ?? Int.max
    }
}
