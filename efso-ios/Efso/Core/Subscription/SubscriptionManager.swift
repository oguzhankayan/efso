import Foundation
import Observation
@preconcurrency import RevenueCat

/// Subscription state — RevenueCat wrapper.
/// `bootstrap()` EfsoApp init'te çağrılır. UI `currentEntitlement` izler.
/// Free/premium ayrımı tek `isActive` boolean'a indirgenir.
@Observable
@MainActor
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    var isActive: Bool = false
    var isLoading: Bool = false
    var lastError: String?

    /// Offerings (paywall'da gösterilecek paketler — weekly/yearly).
    var weeklyPackage: Package?
    var yearlyPackage: Package?

    private let entitlementId = "premium"
    private let weeklyProductId = "efso_weekly"
    private let yearlyProductId = "efso_yearly"
    private var rcConfigured = false

    private override init() { super.init() }

    /// App açılışında çağrılır. RevenueCat init'i + offerings fetch.
    func bootstrap() {
        // Simulator + DEBUG: gating tamamen kapalı, premium gibi davran.
        // Frontend sınır kontrolleri (EntitlementGate.canGenerate, mode/tone)
        // hep true döner; geliştirici free tier limit'ine takılmaz.
        // Backend tarafı için ayrıca subscription_state row'unun seed'lenmesi
        // gerekir (efso-backend test fixture'ı).
        #if targetEnvironment(simulator) && DEBUG
        isActive = true
        return
        #else
        let key = Configuration.revenueCatAPIKey
        guard !key.isEmpty else {
            // Free build (TestFlight öncesi) — RevenueCat bypass.
            // DEBUG'da physical device'da key yoksa, sessizce premium vermek
            // tehlikeli (TestFlight build'de fark edilmeyebilir). Assertion
            // ile gürültü yap.
            assertionFailure("REVENUECAT_API_KEY boş — physical device DEBUG'da bypass aktif. Release'e gitmemeli.")
            isActive = Configuration.isDebug ? true : false
            return
        }

        Purchases.logLevel = Configuration.isDebug ? .debug : .warn
        Purchases.configure(withAPIKey: key)
        rcConfigured = true
        Purchases.shared.delegate = self

        Task {
            await refreshCustomerInfo()
            await loadOfferings()
        }
        #endif
    }

    /// Auth tamamlandığında user_id'yi RevenueCat'e bağla.
    func identify(userId: String) async {
        guard rcConfigured else { return }
        do {
            _ = try await Purchases.shared.logIn(userId)
            await refreshCustomerInfo()
        } catch {
            // RevenueCat identify hatası — kullanıcıya gösterilmez
            lastError = "bağlantı hatası. tekrar dene."
        }
    }

    func signOut() async {
        guard rcConfigured else { return }
        _ = try? await Purchases.shared.logOut()
        isActive = false
    }

    // MARK: - Offerings + purchase

    private func loadOfferings() async {
        guard rcConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { return }
            weeklyPackage = current.package(identifier: "$rc_weekly")
                ?? current.availablePackages.first { $0.storeProduct.productIdentifier == weeklyProductId }
            yearlyPackage = current.package(identifier: "$rc_annual")
                ?? current.availablePackages.first { $0.storeProduct.productIdentifier == yearlyProductId }
        } catch {
            // Offerings yükleme hatası — kullanıcıya teknik detay gösterme
            lastError = "fiyat bilgisi alınamadı. tekrar dene."
        }
    }

    /// Paywall purchase action — döndüğünde isActive set edilmiş olur.
    /// Race window'ı: RC SDK purchase başarılı → RC sunucu webhook ateşler →
    /// Supabase `subscription_state` row update edilir. Bu zincir ~1-5s
    /// sürebilir. Kullanıcı paywall kapatıp hemen üretim çağırırsa
    /// backend hâlâ free görür ve 402 yer. Çözüm: purchase başarılı ise
    /// kısa bir bekleme + customerInfo refresh ile webhook propagation
    /// için "iyi-niyet" gecikmesi. Paywall'da "..." spinner zaten gösteriliyor.
    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            if isActive {
                // Webhook propagation ortalama 1-3s; 4s defansiyel.
                // Kullanıcıya hissel olarak "ödeme işleniyor" geliyor.
                try? await Task.sleep(for: .seconds(4))
                await refreshCustomerInfo()
            }
            return isActive
        } catch {
            // Cancel = hata değil
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                return false
            }
            // Satın alma hatası — teknik detay kullanıcıya gösterilmez
            lastError = "ödeme tamamlanamadı. tekrar dene."
            return false
        }
    }

    /// "Restore purchases" — başka cihazda satın aldıysa.
    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            return isActive
        } catch {
            // Restore hatası — teknik detay kullanıcıya gösterilmez
            lastError = "geri yükleme başarısız. tekrar dene."
            return false
        }
    }

    // MARK: - Internal

    private func refreshCustomerInfo() async {
        guard rcConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
        } catch {
            // CustomerInfo refresh hatası — kullanıcıya gösterilmez
            lastError = "abonelik durumu alınamadı. tekrar dene."
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        isActive = customerInfo.entitlements[entitlementId]?.isActive == true
    }
}

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
