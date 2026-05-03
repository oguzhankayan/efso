import SwiftUI

/// AI consent — Apple Review minimum gerekli disclosures + GDPR Art. 7 uyumlu rıza.
/// Default checkbox FALSE (dark pattern değil), 44pt tap target, dürüst data sharing.
struct AIConsentView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var consentChecked: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                EfsoWordmark(size: 18)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xxl + AppSpacing.md)

            VStack(alignment: .leading, spacing: AppSpacing.sm + 2) {
                Text("yapay zeka\nşeffaflığı.")
                    .font(AppFont.displayItalic(36, weight: .regular))
                    .tracking(-0.025 * 36)
                    .foregroundColor(AppColor.ink)

                Text("efso yapay zeka kullanır. çıktılar her zaman doğru olmayabilir. nasıl çalıştığını aşağıda gör.")
                    .font(AppFont.body(14.5))
                    .foregroundColor(AppColor.text60)
                    .lineSpacing(14.5 * 0.4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(items, id: \.0) { (q, a) in
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(q.trUpper)
                                .font(AppFont.mono(10, weight: .medium))
                                .tracking(0.16 * 10)
                                .foregroundColor(AppColor.text40)
                            Text(a)
                                .font(AppFont.body(13.5))
                                .foregroundColor(AppColor.ink)
                                .lineSpacing(13.5 * 0.40)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, AppSpacing.md - 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(AppColor.text10).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            }

            HStack(spacing: AppSpacing.md - 2) {
                Button { consentChecked.toggle() } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(consentChecked ? AppColor.accent : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(consentChecked ? AppColor.accent : AppColor.text40, lineWidth: 1.5)
                            )
                            .frame(width: 22, height: 22)
                        if consentChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(AppColor.bg0)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("yapay zeka onayı")
                .accessibilityValue(consentChecked ? "işaretli" : "işaretli değil")
                .sensoryFeedback(.selection, trigger: consentChecked)

                Group {
                    Text("şartları kabul ediyorum. ")
                        .foregroundColor(AppColor.ink)
                    + Text("tüm metni oku")
                        .foregroundColor(AppColor.text60)
                        .underline(true, color: AppColor.text20)
                }
                .font(AppFont.body(13.5))
                .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg - AppSpacing.sm)
            .padding(.top, AppSpacing.md)

            HoloPrimaryButton(title: "kabul et ve devam", isEnabled: consentChecked) {
                vm.aiConsentGiven = true
                UserDefaults.standard.set(true, .aiConsentGiven)
                Task {
                    if let uid = AuthService.shared.userID?.uuidString {
                        try? await SupabaseService.shared
                            .from("profiles")
                            .update(["ai_consent_given": true])
                            .eq("id", value: uid)
                            .execute()
                    }
                }
                vm.advance()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private let items: [(String, String)] = [
        ("ne işliyor",
         "ekran görüntülerini, yazdıklarını ve kalibrasyon cevaplarını işler."),
        ("ne kadar tutuyor",
         "screenshot 24 saat. konuşma 30 gün. kalibrasyon, silene kadar."),
        ("kiminle paylaşıyor",
         "anthropic ve google ile yalnızca üretim anında işlenir. depolanmaz, satılmaz, üçüncü tarafa verilmez."),
        ("geri alabilir miyim",
         "evet. ayarlar, ardından veri ve yapay zeka bölümünden onayı geri çekebilirsin."),
    ]
}

#Preview {
    AIConsentView(vm: OnboardingViewModel())
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
}
