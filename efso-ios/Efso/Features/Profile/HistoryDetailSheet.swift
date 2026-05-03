import SwiftUI

struct HistoryDetailSheet: View {
    let item: ConversationHistoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var copiedIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColor.bg2)
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    EfsoTag("\(item.mode.label) · \(item.relativeTime)", color: AppColor.text60)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.text40)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("kapat")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if !item.replies.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(Array(item.replies.enumerated()), id: \.element.id) { idx, reply in
                                ReplyCard(
                                    toneAngle: reply.toneLabel,
                                    text: reply.text,
                                    isCopied: copiedIndex == reply.index,
                                    onCopy: { copyReply(reply) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
    }

    private func copyReply(_ reply: ReplyOption) {
        UIPasteboard.general.string = reply.text
        withAnimation { copiedIndex = reply.index }
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            withAnimation {
                if copiedIndex == reply.index { copiedIndex = nil }
            }
        }
    }
}
