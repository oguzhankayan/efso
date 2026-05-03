import SwiftUI

/// Refined-y2k demo upload — 3 seçenek (galeri, örnek konuşma, elle yaz) +
/// "şimdilik atla" alt link. Animasyon/typewriter yok; sade.
struct DemoUploadView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnbHeader(step: 10, total: 11, showBack: false)

            VStack(alignment: .leading, spacing: 14) {
                EfsoTag("ilk üretimin", color: AppColor.accent, dot: true)
                Text("bir konuşma\ndene.")
                    .font(AppFont.displayItalic(38, weight: .regular))
                    .tracking(-0.03 * 38)
                    .foregroundColor(AppColor.ink)
                    .lineSpacing(38 * 0.0)
                Text("gerçek bir dm screenshot'ı at. ya da örnek konuşmayı kullan. ikisi de sayılır.")
                    .font(AppFont.body(14))
                    .foregroundColor(AppColor.text60)
                    .lineSpacing(14 * 0.4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            VStack(spacing: 12) {
                primaryOption
                secondaryOption(emoji: "✦", title: "örnek konuşma", subtitle: "\u{201C}üç gün suskun\u{201D} senaryosunu dene", accent: true)
                secondaryOption(emoji: "Aa", title: "elle yaz", subtitle: "konuşmayı sen aktar", accent: false)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 14) {
                Button { onContinue() } label: {
                    Text("ŞİMDİLİK ATLA")
                        .font(AppFont.mono(11))
                        .tracking(0.14 * 11)
                        .foregroundColor(AppColor.text40)
                        .underline(true, color: AppColor.text20)
                }
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var primaryOption: some View {
        Button { onContinue() } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                        .fill(AppColor.bg2)
                    Text("📷").font(.system(size: 22))
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("screenshot seç")
                        .font(AppFont.displayItalic(18, weight: .regular))
                        .foregroundColor(AppColor.ink)
                    Text("GALERİDEN")
                        .font(AppFont.mono(10))
                        .tracking(0.14 * 10)
                        .foregroundColor(AppColor.text40)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColor.bg1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppColor.text20, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            )
        }
        .buttonStyle(.plain)
    }

    private func secondaryOption(emoji: String, title: String, subtitle: String, accent: Bool) -> some View {
        Button { onContinue() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColor.bg2)
                    Text(emoji)
                        .font(emoji == "Aa" ? AppFont.mono(14) : AppFont.displayItalic(18))
                        .foregroundColor(accent ? AppColor.accent : AppColor.text60)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.body(15, weight: .medium))
                        .foregroundColor(AppColor.ink)
                    Text(subtitle)
                        .font(AppFont.body(12))
                        .foregroundColor(AppColor.text60)
                }
                Spacer()
                Text("→").foregroundColor(accent ? AppColor.accent : AppColor.text40)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DemoUploadView(onContinue: {})
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
}
