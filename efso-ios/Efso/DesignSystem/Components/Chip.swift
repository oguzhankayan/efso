import SwiftUI

/// Refined-y2k pill — selected: ink fill (dark text); unselected: outlined.
/// Mode tone selector ve onboarding seçimleri burayı kullanır.
struct Chip: View {
    let label: String
    let isSelected: Bool
    var size: Size
    var emoji: String?
    let action: () -> Void

    enum Size { case regular, large }

    init(
        label: String,
        isSelected: Bool = false,
        size: Size = .regular,
        emoji: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.size = size
        self.emoji = emoji
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.system(size: 14))
                }
                Text(label.trLower)
            }
            .font(AppFont.body(size == .large ? 15 : 14, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? AppColor.bg0 : AppColor.ink)
            .padding(.horizontal, size == .large ? 20 : 16)
            .frame(height: 44)
            .background(
                Capsule().fill(isSelected ? AppColor.ink : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : AppColor.text20, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
