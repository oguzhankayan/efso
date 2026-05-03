import SwiftUI

/// Refined ton seçici — pill shape, ink fill on selection.
/// Mode ekranlarında (cevap/açılış/tonla/davet) generate butonunun hemen üstünde.
struct TonePicker: View {
    let tones: [String]
    let selected: String
    let onSelect: (String) -> Void
    var label: String = "ton"

    @State private var pressedTone: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: label.isEmpty ? 0 : 10) {
            if !label.isEmpty {
                EfsoTag(label, color: AppColor.text40)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tones, id: \.self) { tone in
                        let on = tone == selected
                        Button(action: { onSelect(tone) }) {
                            Text(tone.trLower)
                                .font(AppFont.body(13, weight: on ? .semibold : .regular))
                                .foregroundColor(on ? AppColor.bg0 : AppColor.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(
                                    Capsule().fill(on ? AppColor.ink : Color.clear)
                                )
                                .overlay(
                                    Capsule().stroke(on ? Color.clear : AppColor.text20, lineWidth: 1)
                                )
                                .contentShape(Capsule())
                                .scaleEffect(pressedTone == tone ? 0.92 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.65), value: pressedTone)
                        }
                        .accessibilityLabel(tone)
                        .accessibilityValue(on ? "seçili" : "")
                        .accessibilityHint("tonu seçmek için dokun")
                        .sensoryFeedback(.selection, trigger: selected)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in pressedTone = tone }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                        pressedTone = nil
                                    }
                                }
                        )
                    }
                }
            }
        }
    }
}
