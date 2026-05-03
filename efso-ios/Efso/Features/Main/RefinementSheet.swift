import SwiftUI

struct RefinementSheet: View {
    let remainingRefines: Int?
    let isPremium: Bool
    let isRefining: Bool
    let onSubmit: (Tone) -> Void
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTone: Tone = .esprili

    private var limitHit: Bool {
        !isPremium && (remainingRefines ?? EntitlementGate.freeRefineLimit) <= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(AppColor.text20)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("bunu daha...")
                    .font(AppFont.displayItalic(30, weight: .regular))
                    .tracking(-0.02 * 30)
                    .foregroundColor(AppColor.ink)
                Text("aynı bağlam, başka enerji.")
                    .font(AppFont.body(13.5))
                    .foregroundColor(AppColor.text60)
            }

            toneGrid

            if !isPremium {
                Text(limitHit ? "günlük tonlama doldu" : "kalan: \(remainingRefines ?? EntitlementGate.freeRefineLimit)/\(EntitlementGate.freeRefineLimit)")
                    .font(AppFont.mono(10))
                    .tracking(0.14 * 10)
                    .foregroundColor(limitHit ? AppColor.warning : AppColor.text40)
                    .textCase(.uppercase)
            }

            if limitHit {
                HoloPrimaryButton(title: "premium'a geç") {
                    dismiss()
                    onUpgrade()
                }
            } else {
                HoloPrimaryButton(title: isRefining ? "üretiliyor" : "benzerini üret", isEnabled: !isRefining) {
                    onSubmit(selectedTone)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.bg0)
    }

    private var toneGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            ForEach(Tone.allCases) { tone in
                Chip(
                    label: tone.label,
                    isSelected: selectedTone == tone,
                    size: .large,
                    emoji: tone.emoji
                ) {
                    selectedTone = tone
                }
            }
        }
    }
}
