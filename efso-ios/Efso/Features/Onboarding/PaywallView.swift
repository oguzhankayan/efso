import SwiftUI
import RevenueCat

/// Paywall — Rizz playbook: full-bleed bg + kısa value prop + tek CTA → sheet.
/// Fiyat, disclosure, dismiss, footer link'ler hepsi sheet içinde.
struct PaywallView: View {
    let onContinue: () -> Void
    let onDismiss: (() -> Void)?
    var lockReason: EntitlementGate.LockReason?

    @State private var showPlanSheet = false

    init(
        onContinue: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        lockReason: EntitlementGate.LockReason? = nil
    ) {
        self.onContinue = onContinue
        self.onDismiss = onDismiss
        self.lockReason = lockReason
    }

    var body: some View {
        VStack(spacing: 0) {
            if onDismiss != nil { dismissBar } else { Spacer().frame(height: 0) }

            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.lg) {
                titleBlock
                featureList
            }
            .padding(.horizontal, AppSpacing.lg)

            HoloPrimaryButton(title: "ücretsiz dene") {
                showPlanSheet = true
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                backgroundImage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [.clear, AppColor.bg0.opacity(0.55), AppColor.bg0.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 420)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showPlanSheet) {
            PlanSelectorSheet(
                onPurchased: {
                    showPlanSheet = false
                    onContinue()
                },
                onDecline: {
                    showPlanSheet = false
                    onContinue()
                },
                onCancel: { showPlanSheet = false },
                showDecline: onDismiss == nil
            )
            .presentationDetents([.fraction(0.6)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(AppColor.bg0)
        }
    }

    private var dismissBar: some View {
        HStack {
            Spacer()
            Button { onDismiss?() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColor.text40)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("kapat")
        }
        .padding(.top, AppSpacing.sm)
        .padding(.trailing, AppSpacing.sm)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text("efso'yu ücretsiz")
                    .foregroundColor(AppColor.ink)
                Text("denemeni istiyoruz.")
                    .foregroundColor(AppColor.accent)
            }
            .font(AppFont.displayItalic(34, weight: .regular))
            .tracking(-0.025 * 34)
            .lineSpacing(34 * -0.04)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(subhead)
                .font(AppFont.body(14))
                .foregroundColor(AppColor.text60)
                .lineSpacing(14 * 0.4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subhead: String {
        if let reason = lockReason {
            return reason.headline
        }
        return "3 gün ücretsiz. ne diyeceğini bulmana yardım etsin, sonra karar ver."
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md - AppSpacing.xs) {
            ForEach(features, id: \.self) { f in
                HStack(alignment: .center, spacing: AppSpacing.md - 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColor.accent)
                    Text(f)
                        .font(AppFont.body(14.5))
                        .foregroundColor(AppColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private let features: [String] = [
        "sınırsız cevap, her mod, her ton",
        "30 gün konuşma arşivi",
        "kalibrasyonu istediğin kadar yenile",
    ]

    private var backgroundImage: some View {
        Image("paywall-bg")
            .resizable()
            .scaledToFill()
    }
}

// MARK: - Plan selector sheet (fiyat + disclosure + footer hepsi burada)

struct PlanSelectorSheet: View {
    let onPurchased: () -> Void
    let onDecline: () -> Void
    let onCancel: () -> Void
    let showDecline: Bool

    @State private var subs = SubscriptionManager.shared
    @State private var purchasing = false
    @State private var trialEnabled = true
    @State private var error: String?
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var restoreError: String?
    @State private var restoreSuccess = false

    init(
        onPurchased: @escaping () -> Void,
        onDecline: @escaping () -> Void = {},
        onCancel: @escaping () -> Void,
        showDecline: Bool = true
    ) {
        self.onPurchased = onPurchased
        self.onDecline = onDecline
        self.onCancel = onCancel
        self.showDecline = showDecline
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("planını seç")
                .font(AppFont.displayItalic(26))
                .tracking(-0.02 * 26)
                .foregroundColor(AppColor.ink)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)

            trialToggleRow
                .padding(.bottom, AppSpacing.md)

            if trialEnabled {
                trialTimeline
                    .padding(.bottom, AppSpacing.md)
            } else {
                directPriceCard
                    .padding(.bottom, AppSpacing.md)
            }

            VStack(spacing: AppSpacing.sm) {
                HoloPrimaryButton(
                    title: purchasing ? "..." : (trialEnabled ? "ücretsiz başlat" : "abone ol"),
                    isEnabled: !purchasing
                ) {
                    Task { await runPurchase() }
                }

                if showDecline {
                    Button {
                        onDecline()
                    } label: {
                        Text("şimdi değil")
                            .font(AppFont.body(13))
                            .foregroundColor(AppColor.text40)
                            .underline(true, color: AppColor.text20)
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if let error {
                    Text(error)
                        .font(AppFont.body(11))
                        .foregroundColor(AppColor.danger)
                        .multilineTextAlignment(.center)
                }
            }

            Text(trialEnabled
                 ? "3 gün ücretsiz. sonra haftalık \(weeklyPriceText) otomatik yenilenir. istediğin zaman iptal et."
                 : "haftalık \(weeklyPriceText) otomatik yenilenir. istediğin zaman iptal et.")
                .font(AppFont.body(10))
                .foregroundColor(AppColor.text40)
                .multilineTextAlignment(.center)
                .lineSpacing(10 * 0.35)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.top, AppSpacing.sm)

            Spacer(minLength: 0)

            footerRow
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: trialEnabled)
        .sheet(isPresented: $showTerms) {
            LegalSheet(kind: .terms) { showTerms = false }
                .presentationBackground(AppColor.bg0)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalSheet(kind: .privacy) { showPrivacy = false }
                .presentationBackground(AppColor.bg0)
        }
        .alert("geri yükleme", isPresented: .constant(restoreError != nil)) {
            Button("tamam", role: .cancel) { restoreError = nil }
        } message: {
            Text(restoreError ?? "")
        }
        .alert("aktif abonelik bulundu", isPresented: $restoreSuccess) {
            Button("devam", role: .cancel) {
                restoreSuccess = false
                onPurchased()
            }
        } message: {
            Text("premium erişimin geri yüklendi.")
        }
    }

    // MARK: - Trial toggle

    private var trialToggleRow: some View {
        HStack {
            Text("ücretsiz deneme")
                .font(AppFont.body(15, weight: .medium))
                .foregroundColor(AppColor.ink)
            Spacer()
            Toggle("", isOn: $trialEnabled)
                .labelsHidden()
                .tint(AppColor.accent)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.bg2.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
        .sensoryFeedback(.impact(weight: .light), trigger: trialEnabled)
        .accessibilityLabel("ücretsiz deneme \(trialEnabled ? "açık" : "kapalı")")
    }

    // MARK: - Trial timeline

    private var trialTimeline: some View {
        VStack(spacing: 0) {
            timelineRow(
                dotColor: AppColor.pop,
                label: "bugün",
                detail: "3 gün ücretsiz",
                price: "0",
                isTop: true
            )
            timelineRow(
                dotColor: AppColor.accent,
                label: trialEndDateText,
                detail: "haftalık yenilenir",
                price: weeklyPriceText,
                isTop: false
            )
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.bg2.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func timelineRow(
        dotColor: Color,
        label: String,
        detail: String,
        price: String,
        isTop: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                if !isTop {
                    Rectangle()
                        .fill(AppColor.text20)
                        .frame(width: 1.5, height: 12)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                if isTop {
                    Rectangle()
                        .fill(AppColor.text20)
                        .frame(width: 1.5, height: 12)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundColor(AppColor.ink)
                Text(detail)
                    .font(AppFont.body(11))
                    .foregroundColor(isTop ? AppColor.pop : AppColor.text40)
            }

            Spacer()

            Text(price)
                .font(AppFont.body(14, weight: .semibold))
                .foregroundColor(AppColor.ink)
        }
        .padding(.vertical, 4)
    }

    private var trialEndDateText: String {
        let date = Calendar.istanbul.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    // MARK: - Direct price card (trial off)

    private var directPriceCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("haftalık")
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundColor(AppColor.ink)
                Text("sınırsız cevap, tüm tonlar")
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.text60)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(weeklyPriceText)
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundColor(AppColor.ink)
                if let perDay = perDayText {
                    Text(perDay)
                        .font(AppFont.body(11))
                        .foregroundColor(AppColor.text40)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.bg2.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 0) {
            footerLink("restore") { Task { await runRestore() } }
            footerDot
            footerLink("şartlar") { showTerms = true }
            footerDot
            footerLink("gizlilik") { showPrivacy = true }
        }
        .frame(maxWidth: .infinity)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.trUpper)
                .font(AppFont.mono(10))
                .tracking(0.14 * 10)
                .foregroundColor(AppColor.text40)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footerDot: some View {
        Text("·")
            .font(AppFont.mono(10))
            .foregroundColor(AppColor.text20)
    }

    // MARK: - Pricing

    private var weeklyPriceText: String {
        subs.weeklyPackage?.storeProduct.localizedPriceString ?? "₺49 / hafta"
    }

    private var perDayText: String? {
        guard let pkg = subs.weeklyPackage else { return "günlük ~₺7" }
        let price = pkg.storeProduct.price as Decimal
        let perDay = NSDecimalNumber(decimal: price / 7).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 1
        formatter.locale = pkg.storeProduct.priceFormatter?.locale ?? Locale(identifier: "tr_TR")
        let str = formatter.string(from: NSNumber(value: perDay)) ?? ""
        return str.isEmpty ? nil : "günlük \(str)"
    }

    // MARK: - Actions

    private func runPurchase() async {
        error = nil
        guard let pkg = subs.weeklyPackage else {
            error = "ödeme şu an kullanılamıyor. lütfen birazdan tekrar dene."
            return
        }
        purchasing = true
        let ok = await subs.purchase(pkg)
        purchasing = false
        if ok {
            onPurchased()
        } else {
            error = "ödeme tamamlanamadı veya iptal edildi."
        }
    }

    private func runRestore() async {
        let ok = await subs.restore()
        if ok {
            restoreSuccess = true
        } else {
            restoreError = "aktif aboneliğin görünmüyor. mağazadan satın aldığından emin misin?"
        }
    }
}

#Preview("hard paywall") {
    PaywallView(onContinue: {})
        .background(AppColor.bg0)
        .preferredColorScheme(.dark)
}

#Preview("soft modal") {
    PaywallView(
        onContinue: {},
        onDismiss: {},
        lockReason: .dailyLimit
    )
    .background(AppColor.bg0)
    .preferredColorScheme(.dark)
}
