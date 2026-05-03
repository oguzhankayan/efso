import SwiftUI

/// Refined-y2k arketip ifşası — büyük italic display + custom ikon + gözlem kart + CTA.
/// VM ve flow korundu; sadece görsel katman yenilendi.
struct CalibrationResultView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var revealedCount: Int = 0
    @State private var safeAreaTopInset: CGFloat = 59

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, safeAreaTopInset)
                .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 16) {
                EfsoTag("arketip belirlendi", color: AppColor.ink, dot: true)

                Text(archetypeName)
                    .font(AppFont.displayItalic(56, weight: .regular))
                    .tracking(-0.03 * 56)
                    .foregroundColor(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(archetypeMonoLabel)
                    .font(AppFont.mono(11, weight: .medium))
                    .tracking(0.16 * 11)
                    .foregroundColor(AppColor.accent)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 36)

            HStack {
                Spacer()
                if let arch = vm.archetype {
                    ArchetypeIconView(archetype: arch.archetypePrimary.iconKey, size: 200)
                } else if vm.lastError != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(AppColor.danger)
                        .accessibilityHidden(true)
                        .frame(width: 200, height: 200)
                } else {
                    ProgressView().tint(AppColor.accent).frame(width: 200, height: 200)
                }
                Spacer()
            }
            .padding(.top, 20)

            Spacer(minLength: 16)

            descriptionCard
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ctaBlock
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let inset = scene.windows.first?.safeAreaInsets.top, inset > 0 {
                safeAreaTopInset = inset
            }
            if vm.archetype == nil {
                await vm.submitCalibration()
            }
            startReveal()
        }
    }

    private var header: some View {
        HStack {
            EfsoTag("09 / 09 · kalibrasyon", color: AppColor.text40)
            Spacer()
            EfsoWordmark(size: 18, color: AppColor.text60)
        }
    }

    @ViewBuilder
    private var descriptionCard: some View {
        if let arch = vm.archetype {
            VStack(alignment: .leading, spacing: 14) {
                let primary = arch.displayDescription.first ?? ""
                Text("\u{201C}\(primary)\u{201D}")
                    .font(AppFont.displayItalic(17, weight: .regular))
                    .foregroundColor(AppColor.ink)
                    .lineSpacing(17 * 0.30)
                    .tracking(-0.01 * 17)
                    .fixedSize(horizontal: false, vertical: true)

                if arch.displayDescription.count > 1 {
                    let traits = Array(arch.displayDescription.dropFirst())
                    HStack(spacing: 8) {
                        ForEach(Array(traits.enumerated()), id: \.offset) { idx, trait in
                            Text(trait.trLower)
                                .font(AppFont.mono(10))
                                .tracking(0.10 * 10)
                                .foregroundColor(AppColor.text60)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .overlay(
                                    Capsule().strokeBorder(AppColor.text10, lineWidth: 1)
                                )
                                .opacity(idx < revealedCount ? 1 : 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
        } else if let err = vm.lastError {
            VStack(alignment: .leading, spacing: 8) {
                Text("hesaplanamadı")
                    .font(AppFont.displayItalic(20))
                    .foregroundColor(AppColor.danger)
                Text(err)
                    .font(AppFont.body(13))
                    .foregroundColor(AppColor.text60)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColor.bg1)
            )
        }
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            if vm.lastError != nil {
                PrimaryButton("tekrar dene") { vm.retryCalibrationSubmit() }
                Button("← geri dön") { vm.goBack() }
                    .font(AppFont.body(13))
                    .foregroundColor(AppColor.text40)
                    .frame(height: 44)
                    .accessibilityLabel("geri dön")
            } else {
                PrimaryButton("devam et", isEnabled: vm.archetype != nil, action: vm.advance)
            }
            Text("kalibrasyonu istediğin zaman yenileyebilirsin")
                .font(AppFont.mono(10))
                .tracking(0.10 * 10)
                .foregroundColor(AppColor.text40)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Computed

    private var archetypeName: String {
        guard let arch = vm.archetype else { return "..." }
        // Label: "🥀 EFSO" → "dryroaster" map ile primaryKey'i al
        return arch.archetypePrimary.iconKey
    }

    private var archetypeMonoLabel: String {
        guard let arch = vm.archetype else { return "" }
        return "\(arch.displayLabel) · \(arch.archetypePrimary.shortTitle)"
    }

    private func startReveal() {
        revealedCount = 0
        Task { @MainActor in
            for i in 1...4 {
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.easeOut(duration: 0.35)) {
                    revealedCount = i
                }
            }
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.archetype = ArchetypeResult(
        archetypePrimary: .dryroaster,
        archetypeSecondary: .observer,
        displayLabel: ArchetypePrimary.dryroaster.label,
        displayDescription: ArchetypePrimary.dryroaster.description
    )
    return CalibrationResultView(vm: vm)
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
}
