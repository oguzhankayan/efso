import SwiftUI
import SafariServices
import StoreKit
import UIKit
import UserNotifications

/// Refined-y2k profile / ayarlar. Arketip hero card (tappable) + 3 grouped
/// settings sections (iOS Settings familiar) + delete account + version footer.
struct ProfileView: View {
    @Bindable var vm: HomeViewModel
    let onClose: () -> Void
    let onHowItWorks: () -> Void
    let onAIConsent: () -> Void
    let onRecalibrate: () -> Void
    let onUpgrade: () -> Void

    @State private var subs = SubscriptionManager.shared
    @State private var showingArchetypeSwitcher = false
    @State private var showingVoiceSample = false
    @State private var showingDeleteConfirm = false
    @State private var deletingAccount = false
    @State private var deleteError: String?
    @State private var notificationAuthorized: Bool = false
    @State private var safariURL: URL?
    @State private var showingHistory = false
    @State private var selectedHistoryItem: ConversationHistoryItem?
    @State private var showingNotificationSettings = false
    @AppStorage(UDKey.aiConsentGiven.rawValue) private var aiConsentGiven: Bool = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)

                archetypeCard
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                subscriptionStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 22)

                accountSection
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                appSection
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                legalSection
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                rateButton
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                deleteAccountSection
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                versionFooter
                    .padding(.top, 18)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("hesabı silmek geri alınamaz", isPresented: $showingDeleteConfirm) {
            Button("vazgeç", role: .cancel) {}
            Button("sil", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("tüm konuşmaların, kalibrasyonun, abone bilgin silinir. apple ile tekrar giriş yapsan bile veriler dönmez.")
        }
        .alert("hesap silinemedi", isPresented: .constant(deleteError != nil)) {
            Button("tamam", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showingArchetypeSwitcher) {
            ArchetypeSwitcherSheet(vm: vm)
                .presentationDetents([.large])
                .presentationBackground(AppColor.bg0)
        }
        .sheet(isPresented: $showingVoiceSample) {
            VoiceSampleEditorView(onClose: { showingVoiceSample = false })
                .presentationBackground(AppColor.bg0)
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
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
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsSheet(isAuthorized: notificationAuthorized)
                .presentationBackground(AppColor.bg0)
                .presentationDetents([.medium])
                .onDisappear { Task { await refreshNotificationStatus() } }
        }
        .disabled(deletingAccount)
        .overlay {
            if deletingAccount {
                ZStack {
                    AppColor.bg0.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(AppColor.ink)
                        Text("hesap siliniyor")
                            .font(AppFont.body(13))
                            .foregroundColor(AppColor.text60)
                    }
                }
            }
        }
        .task { await refreshNotificationStatus() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { onClose() } label: {
                Text("← geri")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("kapat")
            Spacer()
        }
    }

    // MARK: - Archetype hero (holo border)

    private var archetypeCard: some View {
        Button { showingArchetypeSwitcher = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppColor.holographic)
                    .opacity(0.9)
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        if let arch = vm.archetype {
                            ArchetypeIconView(archetype: arch.iconKey, size: 88, glow: false)
                        } else {
                            Text("✨").font(.system(size: 44))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            EfsoTag("arketip", color: AppColor.accent)
                            Text(archetypeName)
                                .font(AppFont.displayItalic(30, weight: .regular))
                                .tracking(-0.025 * 30)
                                .foregroundColor(AppColor.ink)
                            Text(archetypeMonoLabel)
                                .font(AppFont.mono(10))
                                .tracking(0.12 * 10)
                                .foregroundColor(AppColor.text60)
                                .textCase(.uppercase)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(AppColor.text40)
                    }
                    .padding(20)

                    Rectangle().fill(AppColor.text10).frame(height: 1).padding(.horizontal, 20)

                    Button {
                        onRecalibrate()
                    } label: {
                        HStack {
                            Text("kalibrasyonu yenile")
                                .font(AppFont.mono(11))
                                .tracking(0.10 * 11)
                                .foregroundColor(AppColor.text60)
                            Spacer()
                            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                                .font(.system(size: 12))
                                .foregroundColor(AppColor.text40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24.8, style: .continuous)
                        .fill(LinearGradient(
                            colors: [AppColor.bg2, AppColor.bg1],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
                .padding(1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("arketipin: \(archetypeName), değiştirmek için dokun")
    }

    private var archetypeName: String {
        vm.archetype?.iconKey ?? "henüz yok"
    }

    private var archetypeMonoLabel: String {
        guard let a = vm.archetype else { return "" }
        return "\(a.label) · \(a.shortTitle)"
    }

    // MARK: - Subscription strip

    @ViewBuilder
    private var subscriptionStrip: some View {
        if subs.isActive {
            actionRow(title: "abonelik", trailing: "premium", chevron: true) {
                Task { if let ws = windowScene { try? await AppStore.showManageSubscriptions(in: ws) } }
            }
            .background(settingsCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onUpgrade()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lock")
                        .font(.system(size: 16))
                        .foregroundColor(AppColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("premium'a geç")
                            .font(AppFont.body(14, weight: .semibold))
                            .foregroundColor(AppColor.ink)
                        Text("günde \(EntitlementGate.freeDailyLimit) üretim. sınırsız için yükselt.")
                            .font(AppFont.body(12))
                            .foregroundColor(AppColor.text60)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColor.accent)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColor.bg1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppColor.accent.opacity(0.45), lineWidth: 1.2)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }

    // MARK: - Grouped sections

    private var accountSection: some View {
        settingsSection(header: "hesap") {
            actionRow(title: "son konuşmalar", trailing: vm.history.isEmpty ? nil : "\(vm.history.count)", chevron: true) {
                showingHistory = true
            }
            divider
            actionRow(title: "yazım tarzım", chevron: true) { showingVoiceSample = true }
        }
    }

    private var appSection: some View {
        settingsSection(header: "uygulama") {
            actionRow(title: "nasıl çalışır", chevron: true, action: onHowItWorks)
            divider
            actionRow(title: "yapay zeka onayı", trailing: aiConsentGiven ? "açık" : "kapalı", action: onAIConsent)
            divider
            actionRow(title: "bildirimler", trailing: notificationAuthorized ? "açık" : "kapalı", chevron: true) {
                showingNotificationSettings = true
            }
        }
    }

    private var legalSection: some View {
        settingsSection(header: "yasal") {
            inAppLinkRow(title: "gizlilik politikası", url: URL(string: "https://efso-app.pages.dev/privacy"))
            divider
            inAppLinkRow(title: "kullanım şartları", url: URL(string: "https://efso-app.pages.dev/terms"))
            divider
            inAppLinkRow(title: "destek", url: URL(string: "https://efso-app.pages.dev/support"))
        }
    }

    private var rateButton: some View {
        Button { requestReview() } label: {
            HStack {
                Text("efso'yu değerlendir")
                    .font(AppFont.body(14))
                    .foregroundColor(AppColor.text60)
                Spacer()
                Text("★")
                    .font(AppFont.body(14))
                    .foregroundColor(AppColor.accent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsSection<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header.uppercased(with: Locale(identifier: "tr")))
                .font(AppFont.mono(10))
                .tracking(0.14 * 10)
                .foregroundColor(AppColor.text40)
                .padding(.leading, 18)

            VStack(spacing: 0) {
                content()
            }
            .background(settingsCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var settingsCardBg: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppColor.bg1)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppColor.text10, lineWidth: 1)
            )
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColor.text10)
            .frame(height: 1)
            .padding(.leading, 18)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func actionRow(title: String, trailing: String? = nil, chevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppFont.body(14.5))
                    .foregroundColor(AppColor.ink)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(AppFont.body(13))
                        .foregroundColor(AppColor.text60)
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.text40)
                } else if trailing == nil {
                    Text("›").foregroundColor(AppColor.text40)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func inAppLinkRow(title: String, url: URL?) -> some View {
        if let url {
            Button {
                safariURL = url
            } label: {
                HStack {
                    Text(title)
                        .font(AppFont.body(14.5))
                        .foregroundColor(AppColor.ink)
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.text40)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func mailRow(title: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                HStack {
                    Text(title)
                        .font(AppFont.body(14.5))
                        .foregroundColor(AppColor.ink)
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.text40)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Delete account

    private var deleteAccountSection: some View {
        VStack(spacing: 10) {
            Button { showingDeleteConfirm = true } label: {
                HStack {
                    Text("hesabı sil")
                        .font(AppFont.body(14.5))
                        .foregroundColor(AppColor.danger)
                    Spacer()
                    Text("geri alınamaz")
                        .font(AppFont.mono(10))
                        .tracking(0.10 * 10)
                        .foregroundColor(AppColor.danger.opacity(0.7))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.danger.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var versionFooter: some View {
        VStack(spacing: 8) {
            Text(brandLine)
                .font(AppFont.body(12))
                .italic()
                .foregroundColor(AppColor.text40)
            Text("efso v\(Configuration.appVersion) (\(Configuration.buildNumber))")
                .font(AppFont.mono(10))
                .foregroundColor(AppColor.text40)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var brandLine: String {
        switch vm.archetype {
        case .dryroaster:           return "ayar yapma. yaşa."
        case .observer:             return "burada her ayar bir gözlem."
        case .softie_with_edges:    return "gerekirse kapatırsın. burada durur."
        case .chaos_agent:          return "ayar değil, şimdi nereye bakıyorsun."
        case .strategist:           return "doğru düğme yok, sadece doğru sıra."
        case .romantic_pessimist:   return "ayar bittiği yerde başka bir şey başlar."
        default:                    return "buradan çıkmadan önce, kafanı bul."
        }
    }

    // MARK: - Account delete

    @MainActor
    private func deleteAccount() async {
        deletingAccount = true
        defer { deletingAccount = false }
        do {
            try await vm.deleteAccount()
        } catch {
            // Hesap silme hatası — teknik detay kullanıcıya gösterilmez
            deleteError = "bir şeyler ters gitti. tekrar dene."
        }
    }

    private func refreshNotificationStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthorized = (s.authorizationStatus == .authorized
                                  || s.authorizationStatus == .provisional
                                  || s.authorizationStatus == .ephemeral)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = UIColor(AppColor.bg0)
        vc.preferredControlTintColor = UIColor(AppColor.ink)
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
