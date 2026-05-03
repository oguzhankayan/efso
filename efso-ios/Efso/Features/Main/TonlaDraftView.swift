import SwiftUI
import UIKit

/// Refined-y2k tonla modu — büyük italic "taslağı yaz." + textarea +
/// asistan sesli SES SIZIYOR hint kartı + ton seçici + holo CTA.
struct TonlaDraftView: View {
    @Bindable var vm: HomeViewModel

    @State private var subs = SubscriptionManager.shared
    @FocusState private var draftFocused: Bool
    @FocusState private var contextFocused: Bool
    @State private var showContextField = false
    @State private var safeAreaTopInset: CGFloat = 59

    private var canSubmit: Bool {
        !vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && vm.selectedTone != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    draftInput
                    voiceLeakHint
                    contextSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("bitti") {
                    draftFocused = false
                    contextFocused = false
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { vm.backToHome() } label: {
                Text("← geri")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("geri")
            Spacer()
            EfsoTag("tonla", color: AppColor.text40)
            Spacer()
            if !subs.isActive {
                quotaChip
                    .frame(minWidth: 60, alignment: .trailing)
                    .padding(.trailing, 14)
            } else {
                Color.clear.frame(width: 60, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTopInset)
        .padding(.bottom, 4)
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let inset = scene.windows.first?.safeAreaInsets.top, inset > 0 {
                safeAreaTopInset = inset
            }
        }
    }

    private var quotaChip: some View {
        let usedToday = vm.todayUsageCount
        let cap = EntitlementGate.freeDailyLimit
        return Text("\(min(usedToday, cap))/\(cap)")
            .font(AppFont.mono(10))
            .tracking(0.14 * 10)
            .foregroundColor(usedToday >= cap ? AppColor.warning : AppColor.text60)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColor.bg1))
            .overlay(Capsule().strokeBorder(AppColor.text10, lineWidth: 1))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("taslağı yaz.")
                .font(AppFont.displayItalic(38, weight: .regular))
                .tracking(-0.03 * 38)
                .foregroundColor(AppColor.ink)
            Text("ne demek istediğini yaz. ton biz bakarız.")
                .font(AppFont.body(14))
                .foregroundColor(AppColor.text60)
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
    }

    private var draftInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if vm.draftText.isEmpty {
                    Text("yazdığını buraya yapıştır")
                        .font(AppFont.body(15))
                        .foregroundColor(AppColor.text40)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.draftText)
                    .font(AppFont.body(16))
                    .foregroundColor(AppColor.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 180)
                    .focused($draftFocused)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(draftFocused ? AppColor.accent : AppColor.text20, lineWidth: 1)
                    )
            )
            HStack {
                Text("\(vm.draftText.count) / 1500 karakter")
                    .font(AppFont.mono(10))
                    .tracking(0.14 * 10)
                    .foregroundColor(AppColor.text40)
                Spacer()
                if vm.draftText.count > 200 {
                    Text("UZUN · KISALT")
                        .font(AppFont.mono(10))
                        .tracking(0.14 * 10)
                        .foregroundColor(AppColor.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var voiceLeakHint: some View {
        if vm.draftText.count > 200 {
            HStack(alignment: .top, spacing: 10) {
                Text("✦")
                    .foregroundColor(AppColor.accent)
                Text("uzun mesajlar gücünü azaltır. kısa tut, soru ile bitir.")
                    .font(AppFont.displayItalic(13.5, weight: .regular))
                    .foregroundColor(AppColor.ink)
                    .lineSpacing(13.5 * 0.30)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColor.bg2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private var contextSection: some View {
        if showContextField {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    EfsoTag("karşı tarafın son mesajı", color: AppColor.text40)
                    Spacer()
                    Button {
                        vm.contextText = ""
                        showContextField = false
                    } label: {
                        Text("kaldır")
                            .font(AppFont.mono(11))
                            .tracking(0.10 * 11)
                            .foregroundColor(AppColor.text40)
                    }
                }
                ZStack(alignment: .topLeading) {
                    if vm.contextText.isEmpty {
                        Text("dil eşleşsin diye")
                            .font(AppFont.body(13))
                            .foregroundColor(AppColor.text40)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                    }
                    TextEditor(text: $vm.contextText)
                        .focused($contextFocused)
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.ink)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 70)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColor.bg1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppColor.text10, lineWidth: 1)
                        )
                )
            }
        } else {
            Button { showContextField = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("karşı tarafın son mesajını ekle")
                }
                .font(AppFont.mono(11))
                .tracking(0.10 * 11)
                .foregroundColor(AppColor.text60)
            }
        }
    }

    @ViewBuilder
    private var bottomBlock: some View {
        VStack(spacing: 12) {
            TonePicker(
                tones: Tone.allLabels,
                selected: vm.selectedTone?.label.trLower ?? "",
                onSelect: { label in
                    if let tone = Tone.allCases.first(where: { $0.label.trLower == label }) {
                        vm.selectedTone = tone
                    }
                },
                label: ""
            )
            .padding(.horizontal, 20)

            HoloPrimaryButton(title: "tonla", isEnabled: canSubmit) {
                draftFocused = false
                contextFocused = false
                vm.proceedToTonlaGeneration()
            }
            .opacity(canSubmit ? 1 : 0.35)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .padding(.top, 10)
    }
}
