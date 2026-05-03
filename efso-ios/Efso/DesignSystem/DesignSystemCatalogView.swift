import SwiftUI

/// Tüm design system primitives + token'ları tek ekranda gösteren canlı katalog.
/// Phase 0.4 DoD: bu ekranı simulator'da aç, tüm component'lerin doğru göründüğünü doğrula.
struct DesignSystemCatalogView: View {
    @State private var selectedChip = "kadın"
    @State private var copiedReplyIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Logo(size: 88)
                    .padding(.top, 60)

                section("Buttons") {
                    PrimaryButton("başla") {}
                    PrimaryButton("kalibre et", style: .holoBorder) {}
                    PrimaryButton("ücretsiz başlat", style: .holoFill) {}
                    PrimaryButton("disabled", isEnabled: false) {}
                }

                section("Chips · onboarding selection") {
                    HStack(spacing: 8) {
                        Chip(label: "kadın", isSelected: selectedChip == "kadın", size: .large) { selectedChip = "kadın" }
                        Chip(label: "erkek", isSelected: selectedChip == "erkek", size: .large) { selectedChip = "erkek" }
                        Chip(label: "belirtmiyorum", isSelected: selectedChip == "belirtmiyorum", size: .large) { selectedChip = "belirtmiyorum" }
                    }
                }

                section("Reply cards · output sesi") {
                    VStack(spacing: 12) {
                        ReplyCard(
                            toneAngle: "doğrudan engage",
                            text: "merhaba diyen herkese güzel diyor musun yoksa sadece bana mı?",
                            isCopied: copiedReplyIndex == 0,
                            onCopy: { copiedReplyIndex = 0 }
                        )
                        ReplyCard(
                            toneAngle: "yön çevirme",
                            text: "şu an seninle konuşuyorum. devamına sen karar ver.",
                            isCopied: copiedReplyIndex == 1,
                            onCopy: { copiedReplyIndex = 1 }
                        )
                        ReplyCard(
                            toneAngle: "ileri taşıma",
                            text: "perşembe akşam müsaitim. kahve veya bir şey?",
                            isCopied: copiedReplyIndex == 2,
                            onCopy: { copiedReplyIndex = 2 }
                        )
                    }
                }

                section("Skeleton · streaming") {
                    ProgressView().tint(AppColor.accent)
                }

                colorPalette

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 24)
        }
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.trUpper)
                .font(AppFont.mono(11))
                .tracking(0.08 * 11)
                .foregroundColor(AppColor.lime)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorPalette: some View {
        section("Color tokens") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    swatch("bg0", AppColor.bg0)
                    swatch("bg1", AppColor.bg1)
                    swatch("bg2", AppColor.bg2)
                    swatch("pink", AppColor.pink)
                    swatch("lime", AppColor.lime)
                    swatch("blue", AppColor.blue)
                    swatch("danger", AppColor.danger)
                    swatch("warning", AppColor.warning)
                }
            }
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColor.holographic)
                    .frame(height: 60)
                Text("holographic")
                    .font(AppFont.mono(11))
                    .foregroundColor(AppColor.text40)
            }
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
            Text(name)
                .font(AppFont.mono(10))
                .foregroundColor(AppColor.text40)
        }
    }
}

#Preview {
    DesignSystemCatalogView()
}
