import SwiftUI

struct ConversationHistorySheet: View {
    let history: [ConversationHistoryItem]
    @Binding var selectedItem: ConversationHistoryItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if history.isEmpty {
                    VStack(spacing: 8) {
                        Spacer(minLength: 80)
                        Text("henüz konuşma yok.")
                            .font(AppFont.body(14))
                            .foregroundColor(AppColor.text40)
                        Text("ilk üretiminden sonra burada görünür.")
                            .font(AppFont.body(12))
                            .foregroundColor(AppColor.text30)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(history.enumerated()), id: \.element.id) { idx, item in
                            Button {
                                dismiss()
                                Task {
                                    try? await Task.sleep(for: .milliseconds(320))
                                    selectedItem = item
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.relativeTime.trUpper)
                                            .font(AppFont.mono(10))
                                            .tracking(0.14 * 10)
                                            .foregroundColor(AppColor.text40)
                                        Spacer()
                                        EfsoTag(item.mode.label, color: AppColor.text30)
                                    }
                                    Text("\u{201C}\(item.snippet)\u{201D}")
                                        .font(AppFont.displayItalic(16, weight: .regular))
                                        .foregroundColor(AppColor.ink)
                                        .lineSpacing(16 * 0.35)
                                        .tracking(-0.01 * 16)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if idx < history.count - 1 {
                                Rectangle()
                                    .fill(AppColor.text10)
                                    .frame(height: 1)
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.bg0)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EfsoTag("son konuşmalar", color: AppColor.text60)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.text60)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("kapat")
                }
            }
        }
    }
}
