import SwiftUI
import UIKit

/// Refined-y2k home — editorial mode list. Kart-grid emekli; her mod
/// 36pt italic isim + tek satır mono açıklama + numerik prefix (01-04).
/// Asistan sesi gözlem + editorial mode list + context footer.
struct HomeView: View {
    @State private var vm = HomeViewModel()
    @State private var showArchetypeSwitcher = false
    @State private var showProfile = false
    @State private var showHowItWorks = false
    @State private var paywallReason: EntitlementGate.LockReason?
    @State private var subs = SubscriptionManager.shared
    @State private var showingAIConsentRevoke = false
    @State private var showingRecalibrate = false
    @State private var showRecalibrationFlow = false
    @AppStorage(UDKey.archetypeSpotlightSeen.rawValue) private var archetypeSpotlightSeen: Bool = false
    @State private var showArchetypeSpotlight: Bool = false
    @AppStorage(UDKey.modeHintSeen.rawValue) private var modeHintSeen: Bool = false
    @State private var showModeHint: Bool = false
    @State private var modeHintPulse: Bool = false
    @State private var selectedHistoryItem: ConversationHistoryItem?
    @State private var safeAreaTopInset: CGFloat = 47
    @State private var cachedStats: HomeStats?

    var body: some View {
        ZStack(alignment: .top) {
            switch vm.stage {
            case .home:
                homeContent
            case .picker(let mode):
                if mode == .tonla {
                    TonlaDraftView(vm: vm)
                } else if vm.isManualMode {
                    if mode == .acilis {
                        ManualProfileEntryView(vm: vm)
                    } else {
                        ManualChatComposerView(vm: vm, mode: mode)
                    }
                } else {
                    ScreenshotPickerView(vm: vm, mode: mode)
                }
            case .generation(let mode):
                GenerationView(vm: vm, mode: mode)
            case .result(let result):
                ResultView(vm: vm, result: result)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AppAnimation.standard, value: stageKey)
        .sheet(item: $paywallReason, onDismiss: { paywallReason = nil }) { reason in
            PaywallView(
                onContinue: { paywallReason = nil },
                onDismiss: { paywallReason = nil },
                lockReason: reason
            )
            .presentationBackground(AppColor.bg0)
        }
        .onChange(of: vm.paywallTrigger) { _, new in
            if let new {
                paywallReason = new
                vm.paywallTrigger = nil
            }
        }
        .alert("yapay zeka onayını geri çek?", isPresented: $showingAIConsentRevoke) {
            Button("vazgeç", role: .cancel) {}
            Button("geri çek", role: .destructive) {
                Task { await vm.revokeAIConsent() }
            }
        } message: {
            Text("bu olmadan uygulama çalışamaz. çıkış yapılacak. verilerinin silinmesi için support@efso.app ile iletişime geç.")
        }
        .alert("kalibrasyonu yeniden mi ölçelim?", isPresented: $showingRecalibrate) {
            Button("vazgeç", role: .cancel) {}
            Button("yenile", role: .destructive) {
                showRecalibrationFlow = true
            }
        } message: {
            Text("9 sorudan oluşan kalibrasyon yeniden başlar.")
        }
        .fullScreenCover(isPresented: $showRecalibrationFlow) {
            RecalibrationFlowView { newArchetype in
                vm.archetype = newArchetype
                UserDefaults.standard.set(newArchetype.rawValue, .currentArchetype)
                showRecalibrationFlow = false
            }
        }
        .overlay {
            if showArchetypeSpotlight {
                SpotlightOverlay(
                    targetCenter: CGPoint(x: 24 + 18, y: safeAreaTopInset + 6 + 22 + 14 + 18),
                    targetRadius: 22,
                    title: "tarzını buradan değiştir",
                    subtitle: "istediğin zaman avatara dokun, başka bir arketipe geç. nasıl çalışır bilgisi sağ üstteki ayarlarda.",
                    isPresented: $showArchetypeSpotlight,
                    onDismiss: { archetypeSpotlightSeen = true }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let inset = scene.windows.first?.safeAreaInsets.top {
                safeAreaTopInset = inset
            }
            if !archetypeSpotlightSeen {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    if !archetypeSpotlightSeen {
                        showArchetypeSpotlight = true
                    }
                }
            }
            if !modeHintSeen {
                let delay: Duration = archetypeSpotlightSeen ? .milliseconds(400) : .milliseconds(1800)
                Task {
                    try? await Task.sleep(for: delay)
                    guard !modeHintSeen else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        showModeHint = true
                    }
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        modeHintPulse = true
                    }
                }
            }
        }
        .onChange(of: vm.history) { _, _ in
            cachedStats = computeHomeStats()
        }
    }

    private var homeStats: HomeStats {
        cachedStats ?? computeHomeStats()
    }

    private var stageKey: String {
        switch vm.stage {
        case .home: "home"
        case .picker(let m): "picker-\(m.rawValue)"
        case .generation(let m): "gen-\(m.rawValue)"
        case .result: "result"
        }
    }

    // MARK: - Home content (refined editorial)

    private var homeContent: some View {
        VStack(spacing: 0) {
            EfsoWordmark(size: 22)
                .padding(.top, safeAreaTopInset + 6)

            topBar
                .padding(.top, 14)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            observationStrip
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            modeList

            Spacer(minLength: 12)

            quotaCard
                .padding(.horizontal, 24)

            contextFooter
                .padding(.top, quotaCardVisible ? 10 : 0)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showArchetypeSwitcher) {
            ArchetypeSwitcherSheet(vm: vm)
                .presentationDetents([.large])
                .presentationBackground(AppColor.bg0)
        }
        .sheet(isPresented: $showHowItWorks) {
            HowItWorksView(onClose: { showHowItWorks = false })
                .presentationBackground(AppColor.bg0)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                vm: vm,
                onClose: { showProfile = false },
                onHowItWorks: {
                    showProfile = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(320))
                        showHowItWorks = true
                    }
                },
                onAIConsent: {
                    showProfile = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(320))
                        showingAIConsentRevoke = true
                    }
                },
                onRecalibrate: {
                    showProfile = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(320))
                        showingRecalibrate = true
                    }
                },
                onUpgrade: {
                    showProfile = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(320))
                        paywallReason = .userInitiated
                    }
                }
            )
            .presentationBackground(AppColor.bg0)
        }
        .sheet(isPresented: $showingHistory) {
            ConversationHistorySheet(
                history: vm.history,
                selectedItem: $selectedHistoryItem
            )
            .presentationBackground(AppColor.bg0)
            .presentationDetents([.large])
        }
        .sheet(item: $selectedHistoryItem) { item in
            HistoryDetailSheet(item: item)
                .presentationBackground(AppColor.bg0)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { showArchetypeSwitcher = true } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppColor.bg2.opacity(0.7))
                        Circle()
                            .strokeBorder(AppColor.holographic, lineWidth: 1)
                        if let arch = vm.archetype {
                            Image(arch.iconAssetName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(4)
                                .accessibilityHidden(true)
                        } else {
                            Text("✨").font(.system(size: 18))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: 36, height: 36)

                    if let arch = vm.archetype {
                        Text(arch.iconKey)
                            .font(AppFont.mono(10))
                            .tracking(0.12 * 10)
                            .foregroundColor(AppColor.text40)
                            .textCase(.uppercase)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("tarz değiştir, şu an \(archetypeShortLabel)")

            Spacer()

            Button { showProfile = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColor.text60)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("ayarlar")
        }
    }

    // MARK: - Observation strip (asistan sesi, lila highlight)

    private var observationStrip: some View {
        observationLine
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var observationLine: some View {
        let stats = homeStats
        let parts = todayObservation(stats: stats)
        Text(attributedObservation(parts: parts))
            .font(AppFont.displayItalic(22, weight: .regular))
            .tracking(-0.02 * 22)
            .lineSpacing(22 * 0.20)
            .foregroundColor(AppColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// İlk parça nötr ink, ikinci parça chrome lilac accent.
    private func attributedObservation(parts: (String, String?)) -> AttributedString {
        var combined = AttributedString(parts.0)
        combined.foregroundColor = AppColor.ink
        if let highlight = parts.1 {
            var hi = AttributedString(" \(highlight)")
            hi.foregroundColor = AppColor.accent
            combined.append(hi)
        }
        return combined
    }

    private func todayObservation(stats: HomeStats) -> (String, String?) {
        let arch = vm.archetype ?? .dryroaster

        if stats.weekCount == 0 {
            return firstVisitObservation(arch: arch)
        }
        if stats.streakDays >= 3 {
            return streakObservation(arch: arch, days: stats.streakDays)
        }
        if stats.weekCount >= 5 {
            return highUsageObservation(arch: arch, count: stats.weekCount)
        }
        return normalObservation(arch: arch, count: stats.weekCount)
    }

    private func firstVisitObservation(arch: ArchetypePrimary) -> (String, String?) {
        switch arch {
        case .dryroaster:       return ("henüz hiç denemedim.", "ilk ss yeter.")
        case .observer:         return ("sessizlik de bir cevap.", "ama bir dene.")
        case .softie_with_edges: return ("burada yenisin.", "birlikte bakalım.")
        case .chaos_agent:      return ("boş ekran sıkıcı.", "bir şey at bakalım.")
        case .strategist:       return ("veri yok, analiz yok.", "ilk hamle sende.")
        case .romantic_pessimist: return ("henüz bir şey yok.", "belki de öyle kalır. belki de değil.")
        }
    }

    private func streakObservation(arch: ArchetypePrimary, days: Int) -> (String, String?) {
        switch arch {
        case .dryroaster:       return ("\(days) gün üst üste.", nil)
        case .observer:         return ("\(days) gün aralıksız.", "bir örüntü var.")
        case .softie_with_edges: return ("\(days) gündür buradasın.", nil)
        case .chaos_agent:      return ("\(days) gün. durmadın.", "momentum iyi.")
        case .strategist:       return ("\(days) günlük seri.", nil)
        case .romantic_pessimist: return ("\(days) gün üst üste geldin.", nil)
        }
    }

    private func highUsageObservation(arch: ArchetypePrimary, count: Int) -> (String, String?) {
        switch arch {
        case .dryroaster:       return ("bu hafta \(count) cevap.", "yoğun geçmiş.")
        case .observer:         return ("\(count) cevap bu hafta.", "hareketli.")
        case .softie_with_edges: return ("bu hafta \(count) tane olmuş.", nil)
        case .chaos_agent:      return ("\(count) cevap.", "devam.")
        case .strategist:       return ("bu hafta \(count).", "veri birikiyor.")
        case .romantic_pessimist: return ("\(count) cevap bu hafta.", nil)
        }
    }

    private func normalObservation(arch: ArchetypePrimary, count: Int) -> (String, String?) {
        switch arch {
        case .dryroaster:       return ("bu hafta \(count) cevap.", nil)
        case .observer:         return ("\(count) cevap.", "sakin tempo.")
        case .softie_with_edges: return ("bu hafta \(count) cevap ürettin.", nil)
        case .chaos_agent:      return ("\(count) cevap.", "daha var mı?")
        case .strategist:       return ("\(count) cevap bu hafta.", nil)
        case .romantic_pessimist: return ("bu hafta \(count) cevap.", nil)
        }
    }

    // MARK: - Mode list (editorial)

    private struct ModeRow: Identifiable {
        let id: Mode
        let kbd: String
        let title: String
        let desc: String
    }

    private static let modes: [ModeRow] = [
        .init(id: .cevap,  kbd: "01", title: "cevap",  desc: "screenshot ver, üç ton üç cevap."),
        .init(id: .acilis, kbd: "02", title: "açılış", desc: "profilden ilk mesaj."),
        .init(id: .tonla,  kbd: "03", title: "tonla",  desc: "taslağını seçtiğin tona çevir."),
        .init(id: .davet,  kbd: "04", title: "davet",  desc: "buluşmaya geçiş cümlesi."),
    ]

    private var modeList: some View {
        VStack(spacing: 0) {
            ForEach(Self.modes) { mode in
                Button { tryEnterMode(mode.id) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(mode.kbd)
                            .font(AppFont.mono(11))
                            .tracking(0.18 * 11)
                            .foregroundColor(AppColor.text40)
                            .frame(width: 26, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(mode.title)
                                .font(AppFont.displayItalic(36, weight: .regular))
                                .tracking(-0.03 * 36)
                                .foregroundColor(AppColor.ink)
                            Text(mode.desc)
                                .font(AppFont.body(13.5))
                                .foregroundColor(AppColor.text60)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.title) modu, \(mode.desc)")
                .background {
                    if mode.id == .cevap && showModeHint {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColor.holographic.opacity(modeHintPulse ? 0.08 : 0.02))
                            .padding(.horizontal, 16)
                    }
                }

                if mode.id == .cevap && showModeHint {
                    modeHintBanner
                }

                if mode.id != Self.modes.last?.id {
                    Rectangle()
                        .fill(AppColor.text10)
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                }
            }
        }
    }

    @ViewBuilder
    private var modeHintBanner: some View {
        Button {
            dismissModeHint()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColor.holographic.opacity(modeHintPulse ? 0.7 : 0.3))
                    .frame(width: 6, height: 6)
                Text("bir ekran görüntüsü yükle, gerisini biz hallederiz.")
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.text60)
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func dismissModeHint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            showModeHint = false
        }
        modeHintSeen = true
    }

    // MARK: - Quota card

    @ViewBuilder
    private var quotaCard: some View {
        if subs.isActive {
            EmptyView()
        } else if !vm.historyLoadedOnce && vm.remainingToday == nil {
            EmptyView()
        } else {
            freeQuotaStrip
        }
    }

    private var freeQuotaStrip: some View {
        let cap = EntitlementGate.freeDailyLimit
        let usedToday: Int = {
            if let remaining = vm.remainingToday { return cap - remaining }
            return vm.todayUsageCount
        }()
        let remaining = max(0, cap - usedToday)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("günlük üretim")
                    .font(AppFont.mono(10))
                    .tracking(0.14 * 10)
                    .foregroundColor(AppColor.text40)
                    .textCase(.uppercase)
                HStack(spacing: 4) {
                    Text("\(remaining)")
                        .font(AppFont.body(14, weight: .semibold))
                        .foregroundColor(AppColor.pop)
                    Text("/ \(cap) kaldı")
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.ink)
                }
            }
            Spacer()
            Button {
                paywallReason = .userInitiated
            } label: {
                Text("premium")
                    .font(AppFont.mono(11))
                    .tracking(0.14 * 11)
                    .foregroundColor(AppColor.ink)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppColor.text20, lineWidth: 1)
                    )
            }
            .accessibilityLabel("premium'a geç")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("bugün \(usedToday) cevap üretildi, sınır \(cap)")
    }

    // MARK: - Mode entry gate

    private func tryEnterMode(_ mode: Mode) {
        if showModeHint { dismissModeHint() }
        if !EntitlementGate.canUseMode(mode, isPremium: subs.isActive) {
            paywallReason = .modeLocked(mode)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        vm.selectMode(mode)
    }

    // MARK: - Stats

    private struct HomeStats {
        let weekCount: Int
        let streakDays: Int
    }

    private func computeHomeStats() -> HomeStats {
        let cal = Calendar.istanbul
        let now = Date()
        let weekAgo = now.addingTimeInterval(-7 * 86400)
        let weekItems = vm.history.filter { $0.createdAt >= weekAgo }
        let activeDays: Set<DateComponents> = Set(vm.history.map {
            cal.dateComponents([.year, .month, .day], from: $0.createdAt)
        })
        var streak = 0
        var cursor = now
        while true {
            let comps = cal.dateComponents([.year, .month, .day], from: cursor)
            if activeDays.contains(comps) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }
        return HomeStats(weekCount: weekItems.count, streakDays: streak)
    }

    // MARK: - Context footer

    @State private var showingHistory = false

    private var quotaCardVisible: Bool {
        !subs.isActive && (vm.historyLoadedOnce || vm.remainingToday != nil)
    }

    private var contextFooter: some View {
        Button { showingHistory = true } label: {
            HStack(spacing: 6) {
                Text(contextFooterText)
                    .font(AppFont.mono(10))
                    .tracking(0.12 * 10)
                    .foregroundColor(AppColor.text40)
                    .textCase(.uppercase)
                if !vm.history.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColor.text30)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.history.isEmpty)
    }

    private var contextFooterText: String {
        guard let last = vm.history.first else {
            return "henüz konuşma yok"
        }
        return "son konuşma \(last.relativeTime)"
    }

    // MARK: - Computed

    private var archetypeShortLabel: String {
        guard let archetype = vm.archetype else { return "" }
        let parts = archetype.label.split(separator: " ", maxSplits: 1)
        return (parts.last.map(String.init) ?? "").trLower
    }
}

#Preview {
    HomeView()
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
}
