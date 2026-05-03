import SwiftUI

/// Çıkış kartı — kullanıcının atacağı mesaj. Tüm kartlar eşit ağırlıkta.
struct ReplyCard: View {
    let toneAngle: String
    let text: String
    let isCopied: Bool
    let onCopy: () -> Void
    let onRefine: (() -> Void)?

    @State private var isPressed = false

    init(
        toneAngle: String,
        text: String,
        isCopied: Bool = false,
        onCopy: @escaping () -> Void,
        onRefine: (() -> Void)? = nil
    ) {
        self.toneAngle = toneAngle
        self.text = text
        self.isCopied = isCopied
        self.onCopy = onCopy
        self.onRefine = onRefine
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

            actionRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColor.bg2, AppColor.bg1],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isCopied ? AppColor.text20 : AppColor.text10, lineWidth: 1.5)
                )
        )
        .scaleEffect(isPressed ? 0.975 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            copyButton

            Button {
                if let onRefine { onRefine() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .medium))
                        .accessibilityHidden(true)
                    Text("tonla")
                }
                .font(AppFont.body(13, weight: .medium))
                .foregroundColor(AppColor.text60)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(onRefine == nil)
            .opacity(onRefine == nil ? 0.45 : 1)
            .accessibilityLabel("bu cevabı tonla")
        }
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
            .foregroundColor(AppColor.bg0)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isCopied ? AppColor.pop : AppColor.ink)
            )
            .contentTransition(.numericText())
        }
        .accessibilityLabel(isCopied ? "kopyalandı" : "kopyala")
        .sensoryFeedback(.success, trigger: isCopied)
        .animation(.easeOut(duration: 0.2), value: isCopied)
    }
}
