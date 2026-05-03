import SwiftUI

/// Refined-y2k demographic — italic "seni kim tanıyalım?" + yaş 4-grid + cinsiyet liste.
struct DemographicView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnbHeader(step: 3, total: 5, onBack: { vm.goBack() })

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("seni\ntanıyalım.")
                        .font(AppFont.displayItalic(38, weight: .regular))
                        .tracking(-0.03 * 38)
                        .foregroundColor(AppColor.ink)
                        .lineSpacing(38 * 0.0)
                    Text("üç hızlı seçim. tarzını buradan kalibre ediyoruz.")
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.text60)
                        .lineSpacing(14 * 0.4)
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 12) {
                        EfsoTag("yaş", color: AppColor.text40)
                        HStack(spacing: 8) {
                            ForEach(AgeBracket.allCases, id: \.self) { a in
                                ageCell(a)
                            }
                        }
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 12) {
                        EfsoTag("cinsiyet", color: AppColor.text40)
                        VStack(spacing: 8) {
                            ForEach(Gender.allCases, id: \.self) { g in
                                genderRow(g)
                            }
                        }
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        EfsoTag("ne arıyorsun", color: AppColor.text40)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)],
                                  spacing: 10) {
                            ForEach(Intent.allCases, id: \.self) { intent in
                                intentCard(intent)
                            }
                        }
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            HoloPrimaryButton(title: "devam", isEnabled: vm.demographic.isComplete) {
                vm.advance()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private func ageCell(_ a: AgeBracket) -> some View {
        let on = vm.demographic.ageBracket == a
        return Button { vm.demographic.ageBracket = a } label: {
            Text(a.label)
                .font(AppFont.body(14, weight: on ? .semibold : .medium))
                .foregroundColor(on ? AppColor.bg0 : AppColor.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? AppColor.ink : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(on ? Color.clear : AppColor.text20, lineWidth: 1)
                )
        }
        .accessibilityValue(on ? "seçili" : "")
        .sensoryFeedback(.selection, trigger: vm.demographic.ageBracket)
    }

    private func genderRow(_ g: Gender) -> some View {
        let on = vm.demographic.gender == g
        return Button {
            vm.demographic.gender = g
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack {
                Text(g.label.trLower)
                    .font(AppFont.body(15))
                    .foregroundColor(AppColor.ink)
                Spacer()
                if on {
                    Text("✓")
                        .font(AppFont.mono(11))
                        .foregroundColor(AppColor.accent)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? AppColor.bg2 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? AppColor.text20 : AppColor.text10, lineWidth: 1)
            )
        }
        .accessibilityValue(on ? "seçili" : "")
    }

    private func intentHaptic(_ intent: Intent) {
        switch intent {
        case .relationship: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .casual, .fun: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .taken:        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    private func intentCard(_ intent: Intent) -> some View {
        let on = vm.demographic.intent == intent
        return Button {
            vm.demographic.intent = intent
            intentHaptic(intent)
        } label: {
            HStack(spacing: 12) {
                Text(intent.emoji).font(.system(size: 18))
                Text(intent.label.trLower)
                    .font(AppFont.body(14))
                    .foregroundColor(AppColor.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(on ? AppColor.bg2 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? AppColor.accent : AppColor.text10, lineWidth: 1)
            )
        }
        .accessibilityValue(on ? "seçili" : "")
    }
}

#Preview {
    DemographicView(vm: OnboardingViewModel())
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
}
