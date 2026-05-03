import SwiftUI

/// Refined-y2k asistan sesi — pull-quote stilinde, mor sol-bordür ile.
/// Italic display serif. ObservationCard'ın yeni biçimi; ikisi de yaşar
/// (ObservationCard glass card varyantı, bu refined pull-quote varyantı).
struct AssistantObservationCard: View {
    let text: String
    var fontSize: CGFloat = 18
    var showLabel: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showLabel {
                EfsoTag("efso", color: AppColor.text60, dot: true, dotColor: AppColor.pop)
            }
            Text(text.trLower)
                .font(AppFont.displayItalic(fontSize, weight: .regular))
                .foregroundColor(AppColor.ink)
                .lineSpacing(fontSize * 0.20)
                .tracking(-0.015 * fontSize)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("efso gözlemi: \(text)")
        }
    }
}
