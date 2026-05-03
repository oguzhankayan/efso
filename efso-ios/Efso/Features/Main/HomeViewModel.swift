import Foundation
import SwiftUI
import PhotosUI
import Sentry

/// Main flow state machine: Home → Picker → Tone → Generation → Result.
/// Phase 2'de mock data kullanır. Phase 2.4'te gerçek backend bağlanır.
enum FlowStage: Equatable {
    case home
    case picker(Mode)
    /// Generation aşamasında input kaynağı vm state'inden okunur (screenshot
    /// veya draft). Stage sadece mode taşır.
    case generation(Mode)
    case result(GenerationResult)
}

@Observable
@MainActor
final class HomeViewModel {
    /// ISO formatter'lar pahalı; loadHistory başına 2 alloc yerine class-level
    /// tek instance. Thread-safety: ISO8601DateFormatter Sendable (Apple docs).
    nonisolated(unsafe) static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var stage: FlowStage = .home
    var pickerState: PickerState = .empty
    var lastError: String?
    var history: [ConversationHistoryItem] = []
    /// Cold-launch'ta history bir kez yüklenene kadar `false`. Free quota
    /// chip lokal `history`'den hesaplar — yüklenmeden chip "0/3" gösterip
    /// sonra server'dan 402 dönerse kafa karışır. Bu flag chip'i gate'ler.
    var historyLoadedOnce: Bool = false
    /// Server-truth quota — generate-replies done event'inden gelir.
    /// nil = henüz bilinmiyor (cold launch) veya premium (sınırsız).
    /// `serverIsPremium` ile beraber okunur.
    var remainingToday: Int?
    var remainingRefinesToday: Int?
    var serverIsPremium: Bool = false
    var isRefining: Bool = false

    // MARK: - Cached stats

    /// Bugün kullanılan üretim sayısı — free quota chip'leri için.
    var todayUsageCount: Int {
        history.filter { Calendar.istanbul.isDateInToday($0.createdAt) }.count
    }

    /// Backend free_tier_exceeded → paywall trigger. HomeView sheet observes.
    var paywallTrigger: EntitlementGate.LockReason?

    // For picker
    var pickedItem: PhotosPickerItem? {
        didSet {
            pickerLoadTask?.cancel()
            pickerLoadTask = Task { await handlePickedItem() }
        }
    }
    var pickedScreenshot: Data?

    // Profile cache — cold launch'ta UDKey'den, sonra DB'den güncellenir.
    var archetype: ArchetypePrimary? = {
        if let raw = UserDefaults.standard.string(.currentArchetype),
           let cached = ArchetypePrimary(rawValue: raw) {
            return cached
        }
        return .dryroaster
    }()

    /// Kullanıcının seçtiği ton. nil = backend default (mode'a özgü 3 farklı ton).
    /// Setlendiğinde 3 cevap aynı tonda farklı açılardan üretilir.
    /// tonla modunda zorunlu (UI tarafında enforce edilir).
    var selectedTone: Tone?

    /// Tonla modu için kullanıcı taslağı + opsiyonel karşı tarafın son mesajı.
    var draftText: String = ""
    var contextText: String = ""

    /// "bilmem gereken bir şey?" — picker ekranındaki opsiyonel kullanıcı notu.
    /// parse-screenshot edge function'ına multipart `extra_context` field'ı
    /// olarak gönderilir, conversations.extra_context'e yazılır, generate'te
    /// L4 prompt'una <extra_context> block olarak inject edilir.
    var extraContext: String = ""

    // MARK: - Manuel giriş state
    //
    // Kullanıcı ekran görüntüsü atmadan konuşmayı/profili elle yazdığında
    // bu alanlar dolar. Submit'te `manual_input` JSON'u parse-screenshot
    // edge function'ına gider, vision call atlanır, synthetic ParseResult
    // kurulur.
    //
    // - cevap/davet: manualMessages + otherName.
    // - açılış: manualBio, manualHandle, manualPosts, manualPhotoDescriptions.

    /// Bir konuşma turu — sender + text. UI alternating bubble olarak gösterir.
    struct ManualMessage: Identifiable, Equatable {
        let id: UUID
        var sender: ManualSender
        var text: String
        init(id: UUID = UUID(), sender: ManualSender, text: String = "") {
            self.id = id
            self.sender = sender
            self.text = text
        }
    }
    enum ManualSender: String, Codable { case user, other }

    var manualMessages: [ManualMessage] = []
    var manualOtherName: String = ""
    /// açılış için: manuel profil alanları
    var manualBio: String = ""
    var manualHandle: String = ""
    var manualPosts: [String] = []
    var manualPhotoDescriptions: [String] = []

    /// `true` iken picker yerine ManualChatComposer / ManualProfileEntry açılır.
    /// Picker'daki "elle yaz" butonu set eder. Mode değişiminde resetlenir.
    var isManualMode: Bool = false

    /// Manuel giriş onaylandı, picker'a dönüldü (ton seçimi + üret).
    var manualInputConfirmed: Bool = false

    /// Aktif generation Task — `backToHome()` veya `regenerate()` çağrılınca
    /// cancel edilir. Aksi halde abandoned SSE stream'leri kotayı ısırırdı:
    /// kullanıcı home'a dönmüş olsa bile backend reply üretmeye devam eder.
    private var generationTask: Task<Void, Never>?
    private var pickerLoadTask: Task<Void, Never>?

    enum PickerState: Equatable {
        case empty
        case uploading(progress: Double)
        case done(thumbnail: Data)
    }

    init() {
        Task {
            await loadArchetype()
            await loadHistory()
        }
    }

    func loadArchetype() async {
        guard let uid = AuthService.shared.userID?.uuidString else { return }
        do {
            struct Row: Decodable { let archetype_primary: String? }
            let rows: [Row] = try await SupabaseService.shared.client
                .from("profiles")
                .select("archetype_primary")
                .eq("id", value: uid)
                .execute()
                .value
            if let raw = rows.first?.archetype_primary,
               let parsed = ArchetypePrimary(rawValue: raw) {
                archetype = parsed
                UserDefaults.standard.set(raw, .currentArchetype)
            }
        } catch {
            SentrySDK.capture(message: "loadArchetype failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Stage transitions

    func selectMode(_ mode: Mode) {
        resetFlowState()
        selectedTone = mode == .tonla ? .esprili : nil
        stage = .picker(mode)
    }

    func backToHome() {
        // In-flight SSE stream'i iptal et — abandoned generation kotayı
        // ısırmasın. Task cancel cooperative; URLSession.bytes loop'u
        // for-try-await'te CancellationError throw eder, finishes.
        generationTask?.cancel()
        generationTask = nil
        resetFlowState()
        stage = .home
    }

    /// Picker'a dön (done state'ten 'değiştir').
    func resetPicker() {
        let currentMode: Mode? = {
            switch stage {
            case .picker(let m): return m
            case .generation(let m): return m
            default: return nil
            }
        }()
        guard let currentMode else { return }
        resetFlowState()
        stage = .picker(currentMode)
    }

    private func resetFlowState() {
        pickerState = .empty
        pickedScreenshot = nil
        pickedItem = nil
        draftText = ""
        contextText = ""
        extraContext = ""
        manualMessages = []
        manualOtherName = ""
        manualBio = ""
        manualHandle = ""
        manualPosts = []
        manualPhotoDescriptions = []
        isManualMode = false
        manualInputConfirmed = false
        streamingObservation = ""
        streamingReplies = [:]
        conversationId = nil
        generationPhase = .idle
        lastError = nil
    }

    /// Picker'a geri dön — ton değiştirip yeniden üretebilsin.
    /// Screenshot/manual state korunur, conversationId sıfırlanır
    /// (yeni üretim yeni history entry oluşturur).
    func regenerate() {
        let mode: Mode? = {
            switch stage {
            case .result(let r): return r.mode
            case .generation(let m): return m
            default: return nil
            }
        }()
        guard let mode else { return }
        generationTask?.cancel()
        generationTask = nil
        streamingObservation = ""
        streamingReplies = [:]
        lastError = nil
        generationPhase = .idle
        conversationId = nil

        if mode == .tonla {
            stage = .picker(mode)
        } else if manualInputConfirmed {
            isManualMode = true
            stage = .picker(mode)
        } else if pickerState != .empty {
            stage = .picker(mode)
        } else {
            backToHome()
        }
    }

    /// Screenshot picker'dan generation'a geçiş (cevap/açılış/davet).
    func proceedToGeneration() {
        guard case .picker(let mode) = stage,
              let data = pickedScreenshot else {
            lastError = "önce ekran görüntüsü seç"
            return
        }
        guard checkQuotaOrPaywall() else { return }
        stage = .generation(mode)
        generationTask = Task { await runUnifiedGeneration(mode: mode, imageData: data) }
    }

    /// Manuel giriş onayı — validasyon geçerse picker'a döner (ton seçimi için).
    func confirmManualInput() {
        guard case .picker(let mode) = stage else { return }

        if mode == .acilis {
            let hasSignal = !manualBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !manualHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || manualPosts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                || manualPhotoDescriptions.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard hasSignal else {
                lastError = "en az bir alan doldur (bio, handle, post veya foto açıklaması)"
                return
            }
        } else {
            let cleaned = manualMessages
                .map { ManualMessage(id: $0.id, sender: $0.sender, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.text.isEmpty }
            guard !cleaned.isEmpty else {
                lastError = "en az bir mesaj gir"
                return
            }
            guard cleaned.contains(where: { $0.sender == .other }) else {
                lastError = "en az bir karşı taraf mesajı gerekli"
                return
            }
            manualMessages = cleaned
        }

        manualInputConfirmed = true
        isManualMode = false
        pickerState = .done(thumbnail: Data())
    }

    /// Manuel giriş ekranından generation'a geçiş (cevap/açılış/davet).
    func proceedToManualGeneration() {
        guard case .picker(let mode) = stage else { return }
        guard checkQuotaOrPaywall() else { return }
        stage = .generation(mode)
        generationTask = Task { await runUnifiedManualGeneration(mode: mode) }
    }

    /// Tonla draft view'dan generation'a geçiş.
    func proceedToTonlaGeneration() {
        guard case .picker(.tonla) = stage else { return }
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "taslak boş"
            return
        }
        guard selectedTone != nil else {
            lastError = "ton seç"
            return
        }
        guard checkQuotaOrPaywall() else { return }
        stage = .generation(.tonla)
        generationTask = Task { await runUnifiedTonlaGeneration() }
    }

    private func checkQuotaOrPaywall() -> Bool {
        let subs = SubscriptionManager.shared
        if !(subs.isActive || serverIsPremium) && !EntitlementGate.canGenerate(isPremium: false, todayCount: todayUsageCount) {
            paywallTrigger = .dailyLimit
            return false
        }
        return true
    }

    /// Streaming partial result — GenerationView reads this for live UI.
    /// Phase 2.4 wired to real SSE.
    var streamingObservation: String = ""
    var streamingReplies: [Int: ReplyOption] = [:]
    var conversationId: String?

    /// İki aşamalı pipeline'ın hangi adımında olduğumuzu UI'ya bildirir.
    /// `.idle` generation dışında. `.parsing` Stage 1 (vision). `.streaming`
    /// SSE'den ilk event geldikten sonra. `.finishing` 3/3 reply de elimizde.
    /// `.failed` parse veya stream hata vermişse — view retry chip gösterir.
    enum GenerationPhase: Equatable {
        case idle
        case parsing
        case streaming
        case finishing
        case failed
    }
    var generationPhase: GenerationPhase = .idle

    func updateArchetype(_ newArchetype: ArchetypePrimary) async throws {
        let prev = archetype
        archetype = newArchetype
        UserDefaults.standard.set(newArchetype.rawValue, .currentArchetype)
        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(["archetype_primary": newArchetype.rawValue])
                .eq("id", value: AuthService.shared.userID?.uuidString ?? "")
                .execute()
        } catch {
            archetype = prev
            UserDefaults.standard.set(prev?.rawValue, .currentArchetype)
            throw error
        }
    }

    func deleteAccount() async throws {
        struct EmptyBody: Encodable {}
        struct EmptyResp: Decodable { let ok: Bool }
        _ = try await APIClient.shared.invokeJSON(
            .deleteAccount,
            body: nil as EmptyBody?,
            as: EmptyResp.self
        )
        UserDefaults.standard.set(false, .onboardingCompleted)
        UserDefaults.standard.set(false, .aiConsentGiven)
        UserDefaults.standard.set(false, .archetypeSpotlightSeen)
        UserDefaults.standard.set(false, .modeHintSeen)
        UserDefaults.standard.removeObject(forKey: UDKey.currentArchetype.rawValue)
        await SubscriptionManager.shared.signOut()
        try? await AuthService.shared.signOut()
    }

    func revokeAIConsent() async {
        UserDefaults.standard.set(false, .aiConsentGiven)
        UserDefaults.standard.set(false, .onboardingCompleted)
        UserDefaults.standard.set(false, .modeHintSeen)
        if let uid = AuthService.shared.userID?.uuidString {
            try? await SupabaseService.shared
                .from("profiles")
                .update(["ai_consent_given": false])
                .eq("id", value: uid)
                .execute()
        }
        await SubscriptionManager.shared.signOut()
        try? await AuthService.shared.signOut()
    }

    func reset() {
        stage = .home
        pickerState = .empty
        pickedScreenshot = nil
        pickedItem = nil
    }

    // MARK: - Picker handling

    /// PhotosPicker dışındaki yollar (recent strip tap, paste from clipboard)
    /// için ortak entry. Picker state machine'e tek yerden besler.
    func acceptScreenshotData(_ data: Data) {
        pickerState = .uploading(progress: 0.6)
        let resized = Self.resizedJPEGData(from: data) ?? data
        pickedScreenshot = resized
        // Küçük gecikme — UI'nin uploading state'ini frame atlamadan
        // gösterebilmesi için. Sadece hissel feedback amaçlı.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            pickerState = .done(thumbnail: resized)
        }
    }

    private func handlePickedItem() async {
        guard let item = pickedItem else { return }
        pickerState = .uploading(progress: 0.3)
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let resized = Self.resizedJPEGData(from: data) ?? data
                pickerState = .uploading(progress: 0.7)
                try? await Task.sleep(for: .milliseconds(400))
                pickedScreenshot = resized
                pickerState = .done(thumbnail: resized)
            } else {
                lastError = "fotoğraf yüklenemedi"
                pickerState = .empty
            }
        } catch {
            // Fotoğraf yükleme hatası — teknik detay kullanıcıya gösterilmez
            lastError = "fotoğraf yüklenemedi. tekrar dene."
            pickerState = .empty
        }
    }

    private static func resizedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1568
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    // MARK: - Manual generation (kullanıcı ekran görüntüsü atmaz, elle yazar)

    /// Manuel giriş akışı — `manual_input` JSON'u parse-screenshot'a multipart
    /// form field olarak yollanır, vision call atlanır, synthetic ParseResult
    /// kurulur. Sonrası runRealGeneration ile aynı: generate-replies SSE.
    private func runManualGeneration(mode: Mode) async {
        let json: String
        do {
            json = try buildManualInputJSON(mode: mode)
        } catch {
            // Manuel giriş JSON encode hatası — teknik detay kullanıcıya gösterilmez
            lastError = "bir şeyler ters gitti. tekrar dene."
            generationPhase = .failed
            return
        }
        var formFields: [String: String] = [
            "mode": mode.rawValue,
            "manual_input": json,
        ]
        let trimmedExtra = extraContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExtra.isEmpty {
            formFields["extra_context"] = trimmedExtra
        }
        await runGenerationFromMultipart(mode: mode, imageData: nil, formFields: formFields)
    }

    /// `manual_input` JSON serializer. Mode'a göre chat veya profile shape.
    private func buildManualInputJSON(mode: Mode) throws -> String {
        struct ChatPayload: Encodable {
            let messages: [ChatMsg]
            let other_name: String?
            let platform: String
        }
        struct ChatMsg: Encodable {
            let sender: String
            let text: String
        }
        struct ProfilePayload: Encodable {
            let profile: ProfileBody
            let platform: String
        }
        struct ProfileBody: Encodable {
            let bio: String?
            let handle: String?
            let posts: [String]
            let photo_descriptions: [String]
        }

        let encoder = JSONEncoder()
        if mode == .acilis {
            let bio = manualBio.trimmingCharacters(in: .whitespacesAndNewlines)
            let handle = manualHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            let posts = manualPosts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let photos = manualPhotoDescriptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let payload = ProfilePayload(
                profile: .init(
                    bio: bio.isEmpty ? nil : bio,
                    handle: handle.isEmpty ? nil : handle,
                    posts: posts,
                    photo_descriptions: photos
                ),
                platform: "unknown"
            )
            let data = try encoder.encode(payload)
            guard let json = String(data: data, encoding: .utf8) else {
                throw APIError.unknown("json encoding failed")
            }
            return json
        } else {
            let msgs = manualMessages
                .map { ChatMsg(sender: $0.sender.rawValue,
                               text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.text.isEmpty }
            let other = manualOtherName.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = ChatPayload(
                messages: msgs,
                other_name: other.isEmpty ? nil : other,
                platform: "unknown"
            )
            let data = try encoder.encode(payload)
            guard let json = String(data: data, encoding: .utf8) else {
                throw APIError.unknown("json encoding failed")
            }
            return json
        }
    }

    // MARK: - Unified OpenAI generation (v2)

    private func runUnifiedGeneration(mode: Mode, imageData: Data) async {
        await resyncPremiumIfNeeded()
        var formFields: [String: String] = ["mode": mode.rawValue]
        let trimmedExtra = extraContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExtra.isEmpty {
            formFields["extra_context"] = trimmedExtra
        }
        await streamUnifiedMultipart(mode: mode, imageData: imageData, formFields: formFields)
    }

    private func runUnifiedManualGeneration(mode: Mode) async {
        await resyncPremiumIfNeeded()
        let json: String
        do {
            json = try buildManualInputJSON(mode: mode)
        } catch {
            lastError = "bir şeyler ters gitti. tekrar dene."
            generationPhase = .failed
            return
        }
        var formFields: [String: String] = [
            "mode": mode.rawValue,
            "manual_input": json,
        ]
        let trimmedExtra = extraContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExtra.isEmpty {
            formFields["extra_context"] = trimmedExtra
        }
        await streamUnifiedMultipart(mode: mode, imageData: nil, formFields: formFields)
    }

    private func runUnifiedTonlaGeneration() async {
        await resyncPremiumIfNeeded()
        streamingObservation = ""
        streamingReplies = [:]
        conversationId = nil
        generationPhase = .parsing

        struct Body: Encodable {
            let mode: String
            let draft: String
            let tone: String
            let context_message: String?
        }
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Body(
            mode: Mode.tonla.rawValue,
            draft: trimmedDraft,
            tone: selectedTone?.rawValue ?? Tone.esprili.rawValue,
            context_message: trimmedContext.isEmpty ? nil : trimmedContext
        )
        await consumeGenerationEvents(
            mode: .tonla,
            events: APIClient.shared.invokeStream(.generate, body: body)
        )
    }

    private func resyncPremiumIfNeeded() async {
        if SubscriptionManager.shared.isActive {
            _ = await SubscriptionManager.shared.resyncCurrentSupabaseUser()
        }
    }

    private func streamUnifiedMultipart(
        mode: Mode,
        imageData: Data?,
        formFields: [String: String]
    ) async {
        streamingObservation = ""
        streamingReplies = [:]
        conversationId = nil
        generationPhase = .parsing

        await consumeGenerationEvents(
            mode: mode,
            events: APIClient.shared.invokeMultipartStream(
                .generate,
                imageData: imageData,
                imageMimeType: "image/jpeg",
                formFields: formFields
            )
        )
    }

    private func consumeGenerationEvents(
        mode: Mode,
        events: AsyncThrowingStream<SSEEvent, Error>
    ) async {
        var observation = ""
        do {
            for try await event in events {
                try Task.checkCancellation()
                switch event {
                case .parseSummary:
                    if generationPhase == .parsing { generationPhase = .streaming }
                case .observation(let text):
                    observation = text
                    streamingObservation = text
                    if generationPhase == .parsing { generationPhase = .streaming }
                case .reply(let index, let tone, let text):
                    streamingReplies[index] = ReplyOption(index: index, tone: tone, text: text)
                    if generationPhase == .parsing { generationPhase = .streaming }
                    if streamingReplies.count == 3 { generationPhase = .finishing }
                case .done(_, let id, let remaining, let remainingRefines, let isPrem):
                    conversationId = id
                    remainingToday = remaining
                    remainingRefinesToday = remainingRefines
                    serverIsPremium = isPrem
                case .unknown:
                    continue
                case .error(let msg):
                    if (msg.trLower.contains("free_tier")
                        || msg.contains("402")
                        || msg.trLower.contains("limit")
                        || msg.trLower.contains("doldu")) {
                        if SubscriptionManager.shared.isActive {
                            lastError = "premium aktif ama sunucu senkronu bekliyor. birkaç saniye sonra tekrar dene."
                            generationPhase = .failed
                            return
                        }
                        paywallTrigger = .dailyLimit
                        stage = .home
                        return
                    }
                    lastError = msg.isEmpty ? "bir şeyler ters gitti. tekrar dene." : msg
                    generationPhase = .failed
                    return
                }
            }

            let finalReplies = (0..<3).compactMap { streamingReplies[$0] }
            guard finalReplies.count == 3 else {
                lastError = "üretim yarıda kaldı. tekrar dene."
                generationPhase = .failed
                SentrySDK.capture(message: "SSE drop unified: \(finalReplies.count)/3 reply, mode=\(mode.rawValue)")
                return
            }

            generationPhase = .idle
            stage = .result(GenerationResult(
                observation: observation,
                replies: finalReplies,
                conversationId: conversationId,
                mode: mode
            ))
            await loadHistory()
            ReviewTrigger.onGenerationCompleted(totalCount: history.count)
        } catch {
            if Task.isCancelled { return }
            if isFreeTierError(error) {
                if SubscriptionManager.shared.isActive {
                    lastError = "premium aktif ama sunucu senkronu bekliyor. birkaç saniye sonra tekrar dene."
                    generationPhase = .failed
                    return
                }
                paywallTrigger = .dailyLimit
                stage = .home
                return
            }
            lastError = "bağlantı hatası. tekrar dene."
            generationPhase = .failed
        }
    }

    func refineReply(index: Int, tone: Tone) async {
        guard case .result(var result) = stage,
              let conversationId = result.conversationId else { return }
        isRefining = true
        defer { isRefining = false }

        struct Body: Encodable {
            let conversation_id: String
            let reply_index: Int
            let tone: String
        }
        struct Response: Decodable {
            let reply: ReplyDTO
            let remaining_refines_today: Int?
            let is_premium: Bool

            struct ReplyDTO: Decodable {
                let index: Int
                let tone: String
                let text: String
            }
        }

        do {
            let response: Response = try await APIClient.shared.invokeJSON(
                .refineReply,
                body: Body(conversation_id: conversationId, reply_index: index, tone: tone.rawValue),
                as: Response.self
            )
            let updated = ReplyOption(
                index: response.reply.index,
                tone: response.reply.tone,
                text: response.reply.text
            )
            result.replies = result.replies.map { $0.index == index ? updated : $0 }
            remainingRefinesToday = response.remaining_refines_today
            serverIsPremium = response.is_premium
            withAnimation(AppAnimation.standard) {
                stage = .result(result)
            }
        } catch {
            if isFreeTierError(error) {
                paywallTrigger = .dailyLimit
            } else {
                lastError = "tonlama olmadı. tekrar dene."
            }
        }
    }

    /// runRealGeneration + runManualGeneration ortak gövdesi.
    /// imageData nil ise manuel akış (form fields'ta manual_input olmalı).
    private func runGenerationFromMultipart(
        mode: Mode,
        imageData: Data?,
        formFields: [String: String]
    ) async {
        streamingObservation = ""
        streamingReplies = [:]
        conversationId = nil
        generationPhase = .parsing

        struct ParseResp: Decodable {
            let conversation_id: String
            let parse_result: ParseResultDTO
            let duration_ms: Int
        }

        let parseResp: ParseResp
        do {
            parseResp = try await APIClient.shared.invokeMultipart(
                .parseScreenshot,
                imageData: imageData,
                imageMimeType: "image/jpeg",
                formFields: formFields,
                as: ParseResp.self
            )
            conversationId = parseResp.conversation_id
        } catch {
            if isFreeTierError(error) {
                paywallTrigger = .dailyLimit
                stage = .home
                return
            }
            lastError = "ekran görüntüsü okunamadı. tekrar dene."
            generationPhase = .failed
            return
        }

        await streamGenerateReplies(conversationId: parseResp.conversation_id, mode: mode)
    }

    /// generate-replies SSE bölümü (parse-screenshot sonrası ortak).
    private func streamGenerateReplies(conversationId: String, mode: Mode) async {
        struct GenBody: Encodable {
            let conversation_id: String
            let tone: String?
        }
        let body = GenBody(conversation_id: conversationId, tone: selectedTone?.rawValue)
        var finalReplies: [ReplyOption] = []
        var observation = ""
        do {
            for try await event in APIClient.shared.invokeStream(.generateReplies, body: body) {
                try Task.checkCancellation()
                switch event {
                case .parseSummary:
                    break
                case .observation(let text):
                    observation = text
                    streamingObservation = text
                    if generationPhase == .parsing { generationPhase = .streaming }
                case .reply(let index, let tone, let text):
                    let r = ReplyOption(index: index, tone: tone, text: text)
                    streamingReplies[index] = r
                    if generationPhase == .parsing { generationPhase = .streaming }
                    if streamingReplies.count == 3 { generationPhase = .finishing }
                case .done(_, _, let remaining, let remainingRefines, let isPrem):
                    self.remainingToday = remaining
                    self.remainingRefinesToday = remainingRefines
                    self.serverIsPremium = isPrem
                    break
                case .unknown:
                    break
                case .error(let msg):
                    if msg.trLower.contains("free_tier")
                        || msg.contains("402")
                        || msg.trLower.contains("limit")
                        || msg.trLower.contains("doldu") {
                        paywallTrigger = .dailyLimit
                        stage = .home
                        return
                    }
                    lastError = "bir şeyler ters gitti. tekrar dene."
                    generationPhase = .failed
                    return
                }
            }
            // SSE drop detection: stream sessizce biterse partial result
            // ResultView'a gitmemeli (kullanıcı bozuk üretim için kota
            // harcardı). 3 reply gelmediyse fail.
            finalReplies = (0..<3).compactMap { streamingReplies[$0] }
            guard finalReplies.count == 3 else {
                lastError = "üretim yarıda kaldı. tekrar dene."
                generationPhase = .failed
                SentrySDK.capture(message:
                    "SSE drop: \(finalReplies.count)/3 reply, mode=\(mode.rawValue)"
                )
                return
            }
            generationPhase = .idle
            stage = .result(GenerationResult(
                observation: observation,
                replies: finalReplies,
                conversationId: conversationId,
                mode: mode
            ))
            await loadHistory()
            ReviewTrigger.onGenerationCompleted(totalCount: history.count)
        } catch {
            if Task.isCancelled { return }
            if isFreeTierError(error) {
                paywallTrigger = .dailyLimit
                stage = .home
                return
            }
            lastError = "bağlantı hatası. tekrar dene."
            generationPhase = .failed
        }
    }

    // MARK: - Real generation (Phase 2.3 + 2.4 wired)

    private func runRealGeneration(mode: Mode, imageData: Data) async {
        streamingObservation = ""
        streamingReplies = [:]
        conversationId = nil
        generationPhase = .parsing

        // Stage 1: parse-screenshot (multipart)
        struct ParseResp: Decodable {
            let conversation_id: String
            let parse_result: ParseResultDTO
            let duration_ms: Int
        }

        let parseResp: ParseResp
        do {
            // Form fields: mode (zorunlu) + opsiyonel extra_context.
            // Boş trim'lenmiş not gönderilmez — backend zaten null kabul ediyor.
            var formFields: [String: String] = ["mode": mode.rawValue]
            let trimmedExtra = extraContext.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedExtra.isEmpty {
                formFields["extra_context"] = trimmedExtra
            }
            parseResp = try await APIClient.shared.invokeMultipart(
                .parseScreenshot,
                imageData: imageData,
                imageMimeType: "image/jpeg",
                formFields: formFields,
                as: ParseResp.self
            )
            conversationId = parseResp.conversation_id
        } catch {
            if isFreeTierError(error) {
                paywallTrigger = .dailyLimit
                stage = .home
                return
            }
            lastError = "ekran görüntüsü okunamadı. tekrar dene."
            generationPhase = .failed
            return
        }

        await streamGenerateReplies(conversationId: parseResp.conversation_id, mode: mode)
    }

    /// Mirror of backend ParseResult — only fields we care about on the client.
    private struct ParseResultDTO: Decodable {
        let platform_detected: String?
        let context_summary_tr: String?
    }

    /// 402 Payment Required → free tier limit aşıldı.
    private func isFreeTierError(_ error: Error) -> Bool {
        if let api = error as? APIError, case .freeTierExceeded = api { return true }
        let s = error.localizedDescription.trLower
        return s.contains("free_tier") || s.contains("402")
    }

    // MARK: - Tonla generation (text input, ss yok)

    private func runTonlaGeneration() async {
        streamingObservation = ""
        streamingReplies = [:]
        conversationId = nil
        generationPhase = .parsing

        // 1) Conversation row aç (ss + parse yok)
        struct CreateBody: Encodable {
            let mode: String
            let draft: String
            let context_message: String?
        }
        struct CreateResp: Decodable { let conversation_id: String }

        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = contextText.trimmingCharacters(in: .whitespacesAndNewlines)

        let createResp: CreateResp
        do {
            createResp = try await APIClient.shared.invokeJSON(
                .createTextConversation,
                body: CreateBody(
                    mode: Mode.tonla.rawValue,
                    draft: trimmedDraft,
                    context_message: trimmedContext.isEmpty ? nil : trimmedContext
                ),
                as: CreateResp.self
            )
            conversationId = createResp.conversation_id
        } catch {
            if isFreeTierError(error) {
                paywallTrigger = .dailyLimit
                stage = .home
                return
            }
            lastError = "bağlantı hatası. tekrar dene."
            generationPhase = .failed
            return
        }

        // 2) generate-replies stream — tone REQUIRED for tonla
        struct GenBody: Encodable {
            let conversation_id: String
            let tone: String?
        }
        let body = GenBody(
            conversation_id: createResp.conversation_id,
            tone: selectedTone?.rawValue
        )

        var observation = ""
        do {
            for try await event in APIClient.shared.invokeStream(.generateReplies, body: body) {
                try Task.checkCancellation()
                switch event {
                case .parseSummary:
                    break
                case .observation(let text):
                    observation = text
                    streamingObservation = text
                    if generationPhase == .parsing { generationPhase = .streaming }
                case .reply(let index, let tone, let text):
                    streamingReplies[index] = ReplyOption(index: index, tone: tone, text: text)
                    if generationPhase == .parsing { generationPhase = .streaming }
                    if streamingReplies.count == 3 { generationPhase = .finishing }
                case .done(_, _, let remaining, let remainingRefines, let isPrem):
                    self.remainingToday = remaining
                    self.remainingRefinesToday = remainingRefines
                    self.serverIsPremium = isPrem
                case .unknown:
                    continue
                case .error(let msg):
                    if msg.trLower.contains("free_tier")
                        || msg.contains("402")
                        || msg.trLower.contains("limit")
                        || msg.trLower.contains("doldu") {
                        paywallTrigger = .dailyLimit
                        stage = .home
                        return
                    }
                    lastError = "bir şeyler ters gitti. tekrar dene."
                    generationPhase = .failed
                    return
                }
            }
        } catch {
            if Task.isCancelled { return }
            if isFreeTierError(error) {
                paywallTrigger = .dailyLimit
                stage = .home
                return
            }
            lastError = "bağlantı hatası. tekrar dene."
            generationPhase = .failed
            return
        }

        // SSE drop detection — tonla için de partial result reject.
        let finalReplies = (0..<3).compactMap { streamingReplies[$0] }
        guard finalReplies.count == 3 else {
            lastError = "üretim yarıda kaldı. tekrar dene."
            generationPhase = .failed
            SentrySDK.capture(message:
                "SSE drop (tonla): \(finalReplies.count)/3"
            )
            return
        }
        generationPhase = .idle

        stage = .result(GenerationResult(
            observation: observation,
            replies: finalReplies,
            conversationId: conversationId,
            mode: .tonla
        ))

        ReviewTrigger.onGenerationCompleted(totalCount: history.count + 1)

        history.insert(.init(
            id: conversationId ?? UUID().uuidString,
            mode: .tonla,
            platform: "draft",
            createdAt: Date(),
            snippet: "\"\(trimmedDraft.prefix(80))\"",
            observation: observation,
            replies: finalReplies
        ), at: 0)
    }

    // ─── mock helpers retired (backend gerçek üretim yapıyor) ───
    /*

    private func mockObservation(for mode: Mode) -> String {
        switch mode {
        case .cevap: "üçü de farklı açıdan giriyor. 02 risk seviyesi en yüksek."
        case .acilis: "profilde bir detay var, klişeden uzak. ona dokun."
        case .bio: "üç versiyon, üç farklı ses. en az birinde kendini gör."
        case .hayalet: "üçüncü gün eşiği. yazma da geçerli bir cevap."
        case .davet: "konuşmanın zemini iyi. davet için hazır."
        }
    }

    private func mockReplies(for mode: Mode, tone: Tone) -> [ReplyOption] {
        // Sample data — gerçek üretim Phase 2.4'te.
        switch mode {
        case .cevap:
            return [
                .init(index: 0, toneAngle: "DOĞRUDAN ENGAGE",
                      text: "üç gün sonra 'selam' yetmez. en azından 'merhaba' deseydin. ne yapıyoruz?"),
                .init(index: 1, toneAngle: "İMA",
                      text: "ortadan kaybolan birinin geri dönüşü, genelde dönmek için değil bakmak için olur. hangisi sen?"),
                .init(index: 2, toneAngle: "KISA",
                      text: "selam. üç gün uzun bir sessizlik. iyi misin?"),
            ]
        case .acilis:
            return [
                .init(index: 0, toneAngle: "SPESİFİK", text: "huysuz kediyle huysuz insan arasında fark var mı?"),
                .init(index: 1, toneAngle: "SORU", text: "üç huysuzluğun ortak özelliği ne?"),
                .init(index: 2, toneAngle: "İRONİ", text: "kahve, kitap, kedi listene 'huy' eklersen tehlikeli oluyor."),
            ]
        default:
            return [
                .init(index: 0, toneAngle: "ANGLE 1", text: "mock cevap 1"),
                .init(index: 1, toneAngle: "ANGLE 2", text: "mock cevap 2"),
                .init(index: 2, toneAngle: "ANGLE 3", text: "mock cevap 3"),
            ]
        }
    }

    */

    /// Supabase'ten son 20 conversation'ı çekip history listesini doldurur.
    /// VM init'te ve generation sonrası state senkronizasyonu için çağrılır.
    /// 30 günlük retention zaten DB tarafında; biz sadece son N tanesini gösteriyoruz.
    func loadHistory() async {
        struct ConvRow: Decodable {
            let id: String
            let mode: String
            let created_at: String
            let parse_result: ParseResultDTO?
            let generation_result: GenerationResultDTO?

            struct ParseResultDTO: Decodable {
                let platform_detected: String?
            }
            struct GenerationResultDTO: Decodable {
                let observation: String?
                let replies: [ReplyDTO]?
                struct ReplyDTO: Decodable {
                    let index: Int?
                    let tone: String?
                    let text: String
                }
            }
        }

        do {
            let rows: [ConvRow] = try await SupabaseService.shared
                .from("conversations")
                .select("id, mode, created_at, parse_result, generation_result")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            let items: [ConversationHistoryItem] = rows.compactMap { r in
                guard let mode = Mode(rawValue: r.mode) else { return nil }
                // Generation tamamlanmamış (parse OK ama gen NULL) row'ları
                // history'de göstermenin anlamı yok — kullanıcıya "tutmadı"
                // satırı boş gösterir, em-dash ban'ını da tetikler.
                guard let snippetText = r.generation_result?.replies?.first?.text,
                      !snippetText.isEmpty else { return nil }
                let date = Self.isoFractional.date(from: r.created_at)
                    ?? Self.isoPlain.date(from: r.created_at)
                    ?? Date()
                // 80 char hard cap; UI lineLimit(2) zaten doğal truncate yapıyor.
                // Ellipsis eklemiyoruz (brand voice "üç nokta yok").
                let snippet = "\"\(snippetText.prefix(80))\""
                let replies: [ReplyOption] = (r.generation_result?.replies ?? []).enumerated().map { i, dto in
                    ReplyOption(index: dto.index ?? i, tone: dto.tone ?? "direkt", text: dto.text)
                }
                return ConversationHistoryItem(
                    id: r.id,
                    mode: mode,
                    platform: r.parse_result?.platform_detected ?? "image",
                    createdAt: date,
                    snippet: snippet,
                    observation: r.generation_result?.observation,
                    replies: replies
                )
            }
            self.history = items
            self.historyLoadedOnce = true
        } catch {
            // History boşa düşmesi geçerli state ama hatayı görünmez bırakma —
            // Sentry'ye kırp ve uyandır. Eski kod sessiz yutuyordu.
            self.history = []
            // Network fail'de bile chip-gate açılsın (sonsuz "—/3" gösterme).
            // Truth: history boş, ama kullanıcı henüz cold-launch yapmadı varsay.
            self.historyLoadedOnce = true
            SentrySDK.capture(message: "loadHistory failed: \(error.localizedDescription)")
        }
    }
}
