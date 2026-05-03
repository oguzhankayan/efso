import SwiftUI
import UIKit

/// Refined-y2k generation loading — chrome ring + italic "düşünüyor." +
/// process phase label. Streaming → reply stack. Failure → error + retry.
struct GenerationView: View {
    @Bindable var vm: HomeViewModel
    let mode: Mode

    @State private var firstReplyHapticFired = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if vm.generationPhase == .failed {
                failureBlock
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            } else if vm.streamingObservation.isEmpty {
                parsingActivity
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            } else {
                streamingContent
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AppAnimation.standard, value: vm.streamingObservation.isEmpty)
        .animation(AppAnimation.standard, value: vm.streamingReplies.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: firstReplyHapticFired)
        .onChange(of: vm.streamingReplies.count) { _, newCount in
            if newCount == 1 && !firstReplyHapticFired {
                firstReplyHapticFired = true
            }
        }
        .onChange(of: vm.generationPhase) { _, phase in
            if phase == .parsing {
                firstReplyHapticFired = false
            }
        }
        .onAppear { readSafeArea() }
    }

    private var topBar: some View {
        HStack {
            Button { vm.backToHome() } label: {
                Text("× iptal")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("iptal")
            Spacer()
            EfsoTag("\(mode.label.trLower) · \(toneLabel)", color: AppColor.text40)
            Spacer()
            Color.clear.frame(width: 60, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTopInset)
        .padding(.bottom, 4)
    }

    @State private var safeAreaTopInset: CGFloat = 59

    private func readSafeArea() {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
           let inset = scene.keyWindow?.safeAreaInsets.top, inset > 0 {
            safeAreaTopInset = inset
        }
    }

    private var toneLabel: String { vm.selectedTone?.label.trLower ?? "üç ton" }

    // MARK: - Parsing activity

    private var parsingActivity: some View {
        VStack(spacing: 0) {
            Spacer()
            chromeRing
                .frame(width: 100, height: 100)
            Text("düşünüyor.")
                .font(AppFont.displayItalic(26, weight: .regular))
                .tracking(-0.025 * 26)
                .foregroundColor(AppColor.ink)
                .padding(.top, 28)
            Spacer()
            phaseLabel
                .padding(.bottom, 32)
        }
    }

    private var chromeRing: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let angle = (elapsed.truncatingRemainder(dividingBy: 2.0) / 2.0) * 360
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppColor.holographic, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(angle))
                Text("e")
                    .font(AppFont.displayItalic(36))
                    .foregroundColor(AppColor.ink)
            }
        }
    }

    private var currentPhaseText: String {
        let isTextOnly = mode == .tonla
        switch vm.generationPhase {
        case .parsing:   return isTextOnly ? "metin okunuyor" : "görsel okunuyor"
        case .streaming: return "cevaplar yazılıyor"
        case .finishing: return "ince ayar"
        default:         return ""
        }
    }

    private var phaseLabel: some View {
        Text(currentPhaseText)
            .font(AppFont.mono(11))
            .tracking(0.14 * 11)
            .foregroundColor(AppColor.text40)
            .textCase(.uppercase)
            .animation(.easeInOut(duration: 0.3), value: currentPhaseText)
            .contentTransition(.opacity)
    }

    // MARK: - Streaming content

    private var streamingContent: some View {
        ScrollView(showsIndicators: false) {
            replyStack
                .padding(.bottom, 24)
        }
    }

    private var replyStack: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { idx in
                if let r = vm.streamingReplies[idx] {
                    ReplyCard(
                        toneAngle: r.toneLabel,
                        text: r.text,
                        onCopy: {
                            UIPasteboard.general.string = r.text
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    // MARK: - Failure

    private var failureBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            EfsoTag("tutmadı", color: AppColor.danger, dot: true, dotColor: AppColor.danger)
            Text(vm.lastError.map { humanize($0) } ?? "bağlantı sorunu. tekrar dener misin")
                .font(AppFont.displayItalic(20, weight: .regular))
                .foregroundColor(AppColor.ink)
                .lineSpacing(20 * 0.30)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button { vm.regenerate() } label: {
                    Text("yeniden dene")
                        .font(AppFont.mono(12))
                        .tracking(0.10 * 12)
                        .foregroundColor(AppColor.bg0)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppColor.ink))
                }
                Button { vm.backToHome() } label: {
                    Text("vazgeç")
                        .font(AppFont.mono(12))
                        .tracking(0.10 * 12)
                        .foregroundColor(AppColor.text60)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
    }

    private func humanize(_ raw: String) -> String {
        let lower = raw.trLower
        if lower.contains("timeout") || lower.contains("timed out") {
            return "bağlantı yavaş. bir daha dener misin"
        }
        if lower.contains("offline") || lower.contains("network") || lower.contains("connection") {
            return "internet kayıp. açınca dön"
        }
        if lower.contains("free_tier") || lower.contains("402") {
            return "günlük hak doldu. yarın yine"
        }
        #if DEBUG
        return "üretim tutmadı. \n\n[debug] \(raw)"
        #else
        return "üretim tutmadı. tekrar dener misin"
        #endif
    }
}
