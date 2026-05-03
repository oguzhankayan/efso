import Foundation
import Observation
import os.log
@preconcurrency import RevenueCat

private let logger = Logger(subsystem: "to.tikla.efso", category: "SubscriptionManager")

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
    private var debugOverride = false

    private override init() { super.init() }

    /// App açılışında çağrılır. RevenueCat init'i + offerings fetch.
    func bootstrap() {
        // Simulator + DEBUG: gating tamamen kapalı, premium gibi davran.
        // Frontend sınır kontrolleri (EntitlementGate.canGenerate, mode/tone)
        // hep true döner; geliştirici free tier limit'ine takılmaz.
        // Backend tarafı için ayrıca subscription_state row'unun seed'lenmesi
        // gerekir (efso-backend test fixture'ı).
        let key = Configuration.revenueCatAPIKey
        guard !key.isEmpty else {
            logger.warning("RC bootstrap: API key boş, isActive=\(Configuration.isDebug)")
            isActive = Configuration.isDebug
            return
        }

        Purchases.logLevel = Configuration.isDebug ? .debug : .warn
        Purchases.configure(withAPIKey: key)
        rcConfigured = true
        Purchases.shared.delegate = self
        logger.info("RC bootstrap: configured, rcConfigured=true")

        Task {
            await refreshCustomerInfo()
            await loadOfferings()
            logger.info("RC state: isActive=\(self.isActive), weekly=\(self.weeklyPackage != nil), yearly=\(self.yearlyPackage != nil)")
        }
    }

    /// Auth tamamlandığında user_id'yi RevenueCat'e bağla.
    func identify(userId: String) async {
        guard rcConfigured else {
            logger.warning("RC identify: skipped, not configured")
            return
        }
        logger.info("RC identify: \(userId)")
        do {
            _ = try await Purchases.shared.logIn(userId)
            await refreshCustomerInfo()
            logger.info("RC identify: success, isActive=\(self.isActive)")
        } catch {
            logger.error("RC identify failed: \(error.localizedDescription)")
            lastError = "bağlantı hatası. tekrar dene."
        }
    }

    func signOut() async {
        guard rcConfigured else { return }
        logger.info("RC signOut")
        _ = try? await Purchases.shared.logOut()
        isActive = false
        debugOverride = false
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
        logger.info("RC purchase: starting \(package.storeProduct.productIdentifier)")
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            #if DEBUG
            if !isActive && !result.userCancelled {
                logger.info("RC purchase: Xcode env — forcing isActive=true (debugOverride)")
                isActive = true
                debugOverride = true
                return true
            }
            #endif
            logger.info("RC purchase: success, isActive=\(self.isActive)")
            if isActive {
                try? await Task.sleep(for: .seconds(4))
                await refreshCustomerInfo()
            }
            return isActive
        } catch {
            let nsError = error as NSError
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                logger.info("RC purchase: cancelled by user")
                return false
            }
            if nsError.domain == RevenueCat.ErrorCode.errorDomain,
               nsError.code == RevenueCat.ErrorCode.productAlreadyPurchasedError.rawValue {
                logger.info("RC purchase: already purchased — refreshing customerInfo")
                await refreshCustomerInfo()
                return isActive
            }
            logger.error("RC purchase failed: domain=\(nsError.domain) code=\(nsError.code) \(error.localizedDescription)")
            lastError = "ödeme tamamlanamadı. tekrar dene."
            return false
        }
    }

    /// "Restore purchases" — başka cihazda satın aldıysa.
    func restore() async -> Bool {
        logger.info("RC restore: starting")
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            logger.info("RC restore: success, isActive=\(self.isActive)")
            return isActive
        } catch {
            logger.error("RC restore failed: \(error.localizedDescription)")
            lastError = "geri yükleme başarısız. tekrar dene."
            return false
        }
    }

    /// RevenueCat bazen sandbox purchase'ı `$RCAnonymousID...` altında tutar.
    /// Generation backend'i ise Supabase UUID üzerinden `subscription_state`
    /// okur. Premium lokal görünüyorsa ama backend hâlâ free dönüyorsa,
    /// purchase/restore öncesi kimliği tekrar Supabase UUID'ye bağla ve RC'nin
    /// webhook'u doğru user_id ile tekrar göndermesi için restore dene.
    func resyncCurrentSupabaseUser() async -> Bool {
        guard rcConfigured else { return isActive }
        guard let userId = AuthService.shared.userID?.uuidString else { return isActive }
        do {
            _ = try await Purchases.shared.logIn(userId)
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            if isActive {
                try? await Task.sleep(for: .seconds(2))
            }
            logger.info("RC resyncCurrentSupabaseUser: user=\(userId), isActive=\(self.isActive)")
            return isActive
        } catch {
            logger.error("RC resyncCurrentSupabaseUser failed: \(error.localizedDescription)")
            return isActive
        }
    }

    // MARK: - Internal

    private func refreshCustomerInfo() async {
        guard rcConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
            logger.info("RC refreshCustomerInfo: isActive=\(self.isActive)")
        } catch {
            logger.error("RC refreshCustomerInfo failed: \(error.localizedDescription)")
            lastError = "abonelik durumu alınamadı. tekrar dene."
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        if debugOverride { return }
        let was = isActive
        let ent = customerInfo.entitlements[entitlementId]
        isActive = ent?.isActive == true
        logger.info("RC apply: entitlement[\(self.entitlementId)] exists=\(ent != nil) isActive=\(ent?.isActive ?? false) product=\(ent?.productIdentifier ?? "nil") → isActive \(was) → \(self.isActive)")
        if customerInfo.entitlements.all.isEmpty {
            logger.warning("RC apply: NO entitlements found — check RevenueCat dashboard product→entitlement mapping")
        }
    }
}

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
