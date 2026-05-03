import Foundation

// MARK: - Question schema (matches backend types.ts CalibrationAnswer)

enum CalibrationQuestionType: String, Codable {
    case singleSelect = "single_select"
    case multiSelect = "multi_select"
    case multiSelectWithPriority = "multi_select_with_priority"
    case binary = "binary_scenario"
    case imageBinary = "image_binary"
    case likert = "likert"
    case slider = "slider"
    case freeText = "free_text"
}

struct CalibrationOption: Codable, Equatable, Hashable {
    let id: String?
    let text: String
    let emoji: String?
}

struct CalibrationQuestion: Codable, Equatable, Identifiable {
    let id: String
    let type: CalibrationQuestionType
    let title: String
    let subtitle: String?
    let options: [CalibrationOption]?
    let scaleMin: Int?
    let scaleMax: Int?
    let scaleLabels: [String]?
    let minLabel: String?
    let maxLabel: String?
    let optional: Bool?
    let footerLink: String?
    let maxLength: Int?
}

// MARK: - Answer storage

struct CalibrationAnswer: Codable, Equatable {
    let questionId: String
    let selected: [String]      // 1+ values; for free_text empty
    let freeText: String?

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case selected
        case freeText = "free_text"
    }
}

// MARK: - Archetype (matches backend types.ts)

enum ArchetypePrimary: String, Codable {
    case dryroaster, observer, softie_with_edges
    case chaos_agent, strategist, romantic_pessimist

    var label: String {
        switch self {
        case .dryroaster: "🥀 KESKİN"
        case .observer: "🪨 DERİN"
        case .softie_with_edges: "🍬 TATLI"
        case .chaos_agent: "🔥 ALEV"
        case .strategist: "✨ HAVALI"
        case .romantic_pessimist: "🎀 NAZLI"
        }
    }

    /// Tek karakter emoji — label başındaki emoji glyph'i.
    /// Önceden `prefix(1) + dropFirst().first` ile her erişimde hesaplanıyordu.
    var emoji: String {
        switch self {
        case .dryroaster: "🥀"
        case .observer: "🪨"
        case .softie_with_edges: "🍬"
        case .chaos_agent: "🔥"
        case .strategist: "✨"
        case .romantic_pessimist: "🎀"
        }
    }

    /// Asset catalog adı — ArchetypeSwitcherSheet, HomeView avatar, ProfileView card.
    var iconAssetName: String {
        switch self {
        case .dryroaster: "arch-dryroaster"
        case .observer: "arch-observer"
        case .softie_with_edges: "arch-softie"
        case .chaos_agent: "arch-chaos"
        case .strategist: "arch-strategist"
        case .romantic_pessimist: "arch-romantic"
        }
    }

    /// Kısa key — refined-y2k design'da arketip ismi olarak kullanılır
    /// ("dryroaster.", "softie." gibi). iconAssetName'in `arch-` prefix'siz hali.
    var iconKey: String {
        switch self {
        case .dryroaster: "dryroaster"
        case .observer: "observer"
        case .softie_with_edges: "softie"
        case .chaos_agent: "chaos"
        case .strategist: "strategist"
        case .romantic_pessimist: "romantic"
        }
    }

    /// Refined wordmark — italic display'de kullanılan kısa Türkçe alt başlık.
    var shortTitle: String {
        switch self {
        case .dryroaster: "kuru ironist"
        case .observer: "gözlemci"
        case .softie_with_edges: "kenarlı tatlı"
        case .chaos_agent: "kaos ajanı"
        case .strategist: "stratejist"
        case .romantic_pessimist: "romantik karamsar"
        }
    }

    var description: [String] {
        switch self {
        case .dryroaster: [
            "spesifik gözlem yaparsın, klişe sevmezsin",
            "kısa cümle, nokta dostusun",
            "soğuk değilsin ama mesafe seversin",
        ]
        case .observer: [
            "önce izlersin, sonra konuşursun",
            "duyguyu sözle dağıtmazsın",
            "sustuğunda en çok şey söylüyorsun",
        ]
        case .softie_with_edges: [
            "sıcak yaklaşırsın ama sınır bilirsin",
            "cringe sevmezsin ama melodramı affedersin",
            "duygu seninle saklanmaz, paylaşılır",
        ]
        case .chaos_agent: [
            "ortam senin enerjini bekliyor",
            "risk almak senin için varsayılan",
            "sıkıcılığı affetmiyorsun",
        ]
        case .strategist: [
            "cevap vermeden önce 3 hamle düşünüyorsun",
            "duyguyu yönetiyorsun, duygu seni değil",
            "bekleyebilen kazanır felsefesi var sende",
        ]
        case .romantic_pessimist: [
            "umutlu olmayı utanç sanmıyorsun",
            "ironi armor değil, dilin senin",
            "sevdiğin şey için savaşmayı erkenden öğrendin",
        ]
        }
    }
}

struct ArchetypeResult: Codable, Equatable {
    let archetypePrimary: ArchetypePrimary
    let archetypeSecondary: ArchetypePrimary
    let displayLabel: String
    let displayDescription: [String]

    enum CodingKeys: String, CodingKey {
        case archetypePrimary = "archetype_primary"
        case archetypeSecondary = "archetype_secondary"
        case displayLabel = "display_label"
        case displayDescription = "display_description"
    }
}
