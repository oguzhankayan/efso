import SwiftUI

/// Refined-y2k arketip değiştirici sheet — italic "başka bir sesle dene." +
/// 6 arketip listesi (custom ikon + key + meta) + ink "kaydet" CTA.
struct ArchetypeSwitcherSheet: View {
    @Bindable var vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ArchetypePrimary
    @State private var saving = false
    @State private var error: String?

    init(vm: HomeViewModel) {
        self._vm = Bindable(vm)
        _selected = State(initialValue: vm.archetype ?? .dryroaster)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Capsule()
                    .fill(AppColor.bg2)
                    .frame(width: 40, height: 4)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, AppSpacing.md)

            VStack(alignment: .leading, spacing: 8) {
                EfsoTag("arketipini değiştir", color: AppColor.text60, dot: true)
                Text("başka bir sesle dene.")
                    .font(AppFont.displayItalic(24, weight: .regular))
                    .tracking(-0.02 * 24)
                    .foregroundColor(AppColor.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(ArchetypePrimary.allCases, id: \.self) { arch in
                        archetypeCard(arch)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
    }

    private func archetypeCard(_ arch: ArchetypePrimary) -> some View {
        let on = selected == arch
        return Button {
            withAnimation(AppAnimation.standard) { selected = arch }
        } label: {
            HStack(spacing: 14) {
                ArchetypeIconView(archetype: arch.iconKey, size: 48, glow: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(arch.iconKey)
                        .font(AppFont.displayItalic(19, weight: .regular))
                        .tracking(-0.02 * 19)
                        .foregroundColor(AppColor.ink)
                    Text("\(arch.label) · \(arch.shortTitle)")
                        .font(AppFont.mono(10))
                        .tracking(0.12 * 10)
                        .foregroundColor(AppColor.text40)
                        .textCase(.uppercase)
                }
                Spacer()
                if on {
                    Text("aktif")
                        .font(AppFont.mono(11))
                        .tracking(0.12 * 11)
                        .foregroundColor(AppColor.accent)
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(on ? AppColor.bg2 : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(on ? AppColor.text20 : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let error {
                Text(error)
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            HoloPrimaryButton(title: saving ? "kaydediliyor" : "kaydet", isEnabled: selected != vm.archetype && !saving) {
                Task { await save() }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 26)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        error = nil
        do {
            try await vm.updateArchetype(selected)
            dismiss()
        } catch {
            // Arketip kaydetme hatası — teknik detay kullanıcıya gösterilmez
            self.error = "kaydedilemedi. tekrar dene."
        }
    }
}

extension ArchetypePrimary: CaseIterable {
    public static var allCases: [ArchetypePrimary] {
        [.dryroaster, .observer, .softie_with_edges, .chaos_agent, .strategist, .romantic_pessimist]
    }
}
