import Foundation

/// 4 mod: cevap, açılış, tonla, davet.
/// Tonla = ekran görüntüsü değil taslak text input. Diğer 3 mod ss alır.
/// Bio Phase 7+'a ertelendi (farklı flow shape).
enum Mode: String, Codable, CaseIterable, Identifiable {
    case cevap, acilis, tonla, davet
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cevap: "CEVAP"
        case .acilis: "İLK MESAJ"
        case .tonla: "TONLA"
        case .davet: "DAVET"
        }
    }

    var subtitle: String {
        switch self {
        case .cevap: "gelen mesaja cevap"
        case .acilis: "profilden ilk mesaj"
        case .tonla: "taslağına ton ver"
        case .davet: "buluşmaya taşı"
        }
    }

    /// Picker başlığı — mode'a göre değişir. Kullanıcı doğru ekranı yüklesin diye.
    var pickerHeadline: String {
        switch self {
        case .cevap: "konuşmanın ekran görüntüsünü ver"
        case .davet: "konuşmanın ekran görüntüsünü ver"
        case .acilis: "profilin ekran görüntüsünü ver"
        case .tonla: "taslağını yaz"
        }
    }

    /// Picker subline — kullanıcıya hangi tür ss beklediğimizi anlatır.
    var pickerSubline: String {
        switch self {
        case .cevap:
            "konuşmanın olduğu kadarı göstermen yeter. kim olduğun gizli kalır."
        case .davet:
            "konuşma biraz ısınmış olsun. soğuk zemine davet ezik kalır."
        case .acilis:
            "hangi uygulamadan olursa olsun. profilde bio, post veya foto görünsün yeter."
        case .tonla:
            "ne demek istediğini yaz, biz tona çevirelim."
        }
    }

    var systemIcon: String {
        switch self {
        case .cevap: "bubble.left"
        case .acilis: "sparkles"
        case .tonla: "wand.and.stars"
        case .davet: "calendar.badge.plus"
        }
    }

    /// Tonla taslak text input alır, ss değil.
    var requiresScreenshot: Bool { self != .tonla }

    /// MVP: tüm modlar açık. Phase 4'te paywall gelirse buradan gate edilir.
    var requiresPremium: Bool { false }
}
