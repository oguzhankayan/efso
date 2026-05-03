import SwiftUI

/// Çıkış kartı — kullanıcının atacağı mesaj. Tüm kartlar eşit ağırlıkta.
struct ReplyCard: View {
    let toneAngle: String
    let text: String
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isPressed = false

    init(
        toneAngle: String,
        text: String,
        isCopied: Bool = false,
        onCopy: @escaping () -> Void
    ) {
        self.toneAngle = toneAngle
        self.text = text
        self.isCopied = isCopied
        self.onCopy = onCopy
    }

    private static let copiedTexts = [
        "kopyalandı",
        "aldın bunu",
        "panodan düşürme",
        "at gitsin",
        "hazır",
    ]

    private var copiedLabel: String {
        Self.copiedTexts[abs(text.hashValue) % Self.copiedTexts.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(toneAngle.trLower)
                .font(AppFont.mono(10, weight: .medium))
                .tracking(0.16 * 10)
                .foregroundColor(AppColor.text40)
                .textCase(.uppercase)
                .padding(.bottom, 10)

            Text(text)
                .font(AppFont.body(15.5))
                .foregroundColor(AppColor.ink)
                .lineSpacing(15.5 * 0.45)
                .tracking(-0.01 * 15.5)
                .padding(.bottom, 14)
                .fixedSize(horizontal: false, vertical: true)

            copyButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColor.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isCopied ? AppColor.text20 : AppColor.text10, lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.975 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
    }

    private var copyButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) { isPressed = false }
            }
            onCopy()
        } label: {
            HStack(spacing: 6) {
                if isCopied {
                    Text(copiedLabel)
                    Image(systemName: "checkmark")
                } else {
                    Text("kopyala")
                }
            }
            .font(AppFont.body(13, weight: .medium))
            .foregroundColor(AppColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(AppColor.text20, lineWidth: 1)
            )
            .contentTransition(.numericText())
        }
        .accessibilityLabel(isCopied ? "kopyalandı" : "kopyala")
        .sensoryFeedback(.success, trigger: isCopied)
        .animation(.easeOut(duration: 0.2), value: isCopied)
    }
}
