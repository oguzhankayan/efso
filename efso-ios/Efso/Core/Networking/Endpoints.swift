import Foundation

/// Edge function endpoint isimleri — `SupabaseService.shared.functions.invoke(...)` ile çağrılır.
enum Endpoint: String {
    case calibrate = "calibrate"
    case parseScreenshot = "parse-screenshot"
    case createTextConversation = "create-text-conversation"
    case generateReplies = "generate-replies"
    case generate = "generate"
    case refineReply = "refine-reply"
    case promptFeedback = "prompt-feedback"
    case revenueCatWebhook = "revenuecat-webhook"
    /// Apple Guideline 5.1.1 — in-app account deletion. Kullanıcının
    /// tüm verisini + auth row'unu siler.
    case deleteAccount = "delete-account"
}
