import AuthenticationServices
import Foundation
import Supabase

/// Auth service — anonymous-first.
/// İlk launch'ta otomatik anon user oluşur. SignInView yok, gate yok.
/// Premium subscription Apple ID'ye bağlı olduğu için reinstall'da
/// "restore" ile geri gelir; conversation history app silindiğinde gider.
@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()

    private(set) var session: Session?
    private(set) var isLoading = false
    private(set) var lastError: APIError?

    /// Cold-launch'ta restore + (gerekirse) anon sign-in bitene kadar `true`.
    /// RootView bu süreçte splash gösterir, flicker olmaz.
    private(set) var isRestoring: Bool = true

    var isSignedIn: Bool { session != nil }
    var userID: UUID? { session?.user.id }

    private init() {
        observeAppleCredentialRevocation()
        Task { await bootstrap() }
    }

    /// Apple Sign In credential revoke edildiğinde kullanıcıyı çıkış yaptır.
    /// Apple bu listener'ı zorunlu tutuyor (App Review guideline 4.8).
    private func observeAppleCredentialRevocation() {
        Task {
            for await _ in NotificationCenter.default.notifications(named: ASAuthorizationAppleIDProvider.credentialRevokedNotification) {
                await signOut()
            }
        }
    }

    /// Cold launch: önce mevcut session'ı restore et, yoksa anon user oluştur.
    func bootstrap() async {
        defer { isRestoring = false }
        do {
            let session = try await SupabaseService.shared.auth.session
            self.session = session
            await identifyVendors(session: session)
        } catch {
            // Session yok → yeni anon user oluştur.
            await signInAnonymouslyIfNeeded()
        }
    }

    /// Idempotent — zaten session varsa no-op.
    func signInAnonymouslyIfNeeded() async {
        guard session == nil else { return }
        do {
            let session = try await SupabaseService.shared.auth.signInAnonymously()
            self.session = session
            await identifyVendors(session: session)
        } catch {
            self.session = nil
            // Anonim oturum oluşturulamadı — teknik detay saklanmaz
            self.lastError = .unknown("bağlantı hatası. tekrar dene.")
        }
    }

    /// Sign-in sonrası user_id'yi RevenueCat + analytics'a tanıt.
    private func identifyVendors(session: Session) async {
        let uuid = session.user.id
        await SubscriptionManager.shared.identify(userId: uuid.uuidString)
        AnalyticsService.shared.identify(userID: uuid)
    }

    /// Mevcut session'ı kapat. Sonrasında bootstrap çağrılırsa yeni anon user
    /// oluşur. AI consent revoke, recalibrate, account delete gibi reset
    /// flow'larında kullanılır.
    func signOut() async {
        try? await SupabaseService.shared.auth.signOut()
        self.session = nil
        KeychainManager.delete(.supabaseSession)
        // Yeni anon user oluştur — kullanıcı app'i kapatmadan devam edebilsin.
        await signInAnonymouslyIfNeeded()
    }
}
