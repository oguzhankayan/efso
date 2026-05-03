import SwiftUI

/// Refined-y2k sonuç ekranı — observation pull-quote (mor sol-bordür) +
/// primary card (holographic 2pt highlight + ink CTA) + 2 alternatif.
struct ResultView: View {
    @Bindable var vm: HomeViewModel
    let result: GenerationResult

    @State private var copiedIndex: Int? = nil
    @State private var feedbackGiven: Bool? = nil
    @State private var safeAreaTopInset: CGFloat = 59
    @State private var visibleCardCount = 0

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if result.replies.isEmpty {
                failureState
            } else {
                contentScroll
                actionFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack {
            Button { vm.backToHome() } label: {
                Text("← yeni")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("yeni")

            Spacer()
            EfsoTag("\(result.mode.label.trLower) · \(toneLabel)", color: AppColor.text40)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTopInset)
        .padding(.bottom, 4)
        .task {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let inset = scene.windows.first?.safeAreaInsets.top, inset > 0 {
                safeAreaTopInset = inset
            }
        }
    }

    private var contentScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(Array(result.replies.enumerated()), id: \.element.id) { idx, reply in
                    ReplyCard(
                        toneAngle: reply.toneLabel,
                        text: reply.text,
                        isCopied: copiedIndex == reply.index,
                        onCopy: { copy(reply) }
                    )
                    .opacity(idx < visibleCardCount ? 1 : 0)
                    .offset(y: idx < visibleCardCount ? 0 : 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .onAppear { staggerReveal() }
    }

    private func staggerReveal() {
        Task {
            for i in 0..<result.replies.count {
                let stagger: Duration = .milliseconds(i * 100)
                try? await Task.sleep(for: i == 0 ? .milliseconds(120) : stagger)
                withAnimation(AppAnimation.standard) {
                    visibleCardCount = i + 1
                }
            }
        }
    }

    private var toneLabel: String {
        vm.selectedTone?.label.trLower ?? "üç ton"
    }

    private var failureState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(AppColor.text40)
            Text("üretim tutmadı.")
                .font(AppFont.displayItalic(24))
                .foregroundColor(AppColor.ink)
            Text(result.observation.isEmpty
                 ? "bağlantı veya parse sorunu. tekrar dene."
                 : result.observation)
                .font(AppFont.body(13))
                .foregroundColor(AppColor.text60)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 10) {
                HoloPrimaryButton(title: "tekrar dene") { vm.regenerate() }
                Button("geri dön") { vm.backToHome() }
                    .font(AppFont.body(13))
                    .foregroundColor(AppColor.text40)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionFooter: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Text("beğendin mi?")
                    .font(AppFont.mono(10))
                    .tracking(0.14 * 10)
                    .foregroundColor(AppColor.text40)
                    .textCase(.uppercase)
                Spacer()
                feedbackPill("👍", positive: true)
                feedbackPill("👎", positive: false)
            }

            HStack(spacing: 10) {
                Button {
                    vm.regenerate()
                } label: {
                    Text("tekrarla")
                        .font(AppFont.mono(12))
                        .tracking(0.10 * 12)
                        .foregroundColor(AppColor.text60)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppColor.text10, lineWidth: 1)
                        )
                }
                Button {
                    vm.backToHome()
                } label: {
                    Text("baştan")
                        .font(AppFont.mono(12))
                        .tracking(0.10 * 12)
                        .foregroundColor(AppColor.bg0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColor.ink)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }

    private func feedbackPill(_ glyph: String, positive: Bool) -> some View {
        let isActive = feedbackGiven == positive
        return Button {
            guard let first = result.replies.first else { return }
            feedbackGiven = positive
            sendFeedback(first, positive: positive)
        } label: {
            Text(glyph)
                .font(AppFont.body(13))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .opacity(isActive ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: feedbackGiven)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackGiven)
        .disabled(feedbackGiven != nil)
    }

    private func copy(_ reply: ReplyOption) {
        UIPasteboard.general.string = reply.text
        copiedIndex = reply.index
        ReviewTrigger.onReplyCopied()
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            if copiedIndex == reply.index { copiedIndex = nil }
        }
    }

    private func sendFeedback(_ reply: ReplyOption, positive: Bool) {
        guard let conversationId = result.conversationId else { return }

        if positive { ReviewTrigger.onPositiveFeedback() }

        struct FeedbackBody: Encodable {
            let conversation_id: String
            let selected_reply_index: Int?
            let feedback: String
        }
        struct FeedbackResp: Decodable { let ok: Bool }

        Task {
            do {
                _ = try await APIClient.shared.invokeJSON(
                    .promptFeedback,
                    body: FeedbackBody(
                        conversation_id: conversationId,
                        selected_reply_index: reply.index,
                        feedback: positive ? "positive" : "negative"
                    ),
                    as: FeedbackResp.self
                )
            } catch {
                AnalyticsService.shared.track(.generationFailed, properties: [
                    "context": "prompt_feedback",
                    "error": error.localizedDescription,
                ])
            }
        }
    }
}
