import SwiftUI
import UIKit

struct ManualChatComposerView: View {
    @Bindable var vm: HomeViewModel
    let mode: Mode

    @State private var inputText = ""
    @State private var selectedSender: HomeViewModel.ManualSender = .other
    @State private var safeAreaTopInset: CGFloat = 59
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.top, 14)
                            .padding(.horizontal, 20)
                        messagesArea
                            .padding(.top, 18)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.manualMessages.count) { _, _ in
                    guard let last = vm.manualMessages.last else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(180))
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            composerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { vm.backToHome() } label: {
                Text("× iptal")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("iptal")
            Spacer()
            EfsoTag("elle yaz", color: AppColor.text40)
            Spacer()
            if canSubmit {
                Button {
                    vm.lastError = nil
                    vm.confirmManualInput()
                } label: {
                    Text("tamam →")
                        .font(AppFont.mono(12))
                        .tracking(0.10 * 12)
                        .foregroundColor(AppColor.ink)
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("tamam")
                .transition(.opacity)
            } else {
                Color.clear.frame(width: 60, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTopInset)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.2), value: canSubmit)
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let inset = scene.windows.first?.safeAreaInsets.top, inset > 0 {
                safeAreaTopInset = inset
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("konuşmayı sen aktar.")
                .font(AppFont.displayItalic(28, weight: .regular))
                .tracking(-0.025 * 28)
                .foregroundColor(AppColor.ink)
            Text("karşıdaki ve sen, sırayla.")
                .font(AppFont.body(13.5))
                .foregroundColor(AppColor.text60)
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesArea: some View {
        VStack(spacing: 8) {
            ForEach(vm.manualMessages) { msg in
                messageBubble(msg)
                    .id(msg.id)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: vm.manualMessages.count)
    }

    private func messageBubble(_ msg: HomeViewModel.ManualMessage) -> some View {
        let isMe = msg.sender == .user
        return HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 48) }
            Text(msg.text)
                .font(AppFont.body(14.5))
                .foregroundColor(isMe ? AppColor.bg0 : AppColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleShape(isMe: isMe).fill(isMe ? AppColor.ink : AppColor.bg2))
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation {
                            vm.manualMessages.removeAll { $0.id == msg.id }
                        }
                    } label: {
                        Label("sil", systemImage: "trash")
                    }
                }
            if !isMe { Spacer(minLength: 48) }
        }
    }

    private func bubbleShape(isMe: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isMe ? 16 : 4,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: isMe ? 4 : 16,
            style: .continuous
        )
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        VStack(spacing: 10) {
            if let err = vm.lastError {
                Text(err)
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.warning)
                    .padding(.horizontal, 24)
            }
            senderToggle
                .padding(.horizontal, 20)
            inputRow
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var senderToggle: some View {
        HStack(spacing: 4) {
            ForEach([HomeViewModel.ManualSender.other, .user], id: \.self) { sender in
                let on = selectedSender == sender
                let label = sender == .other ? "karşıdaki" : "ben"
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedSender = sender
                    }
                } label: {
                    Text(label)
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundColor(on ? AppColor.bg0 : AppColor.text60)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(on ? AppColor.ink : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColor.bg2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("mesajı yaz...", text: $inputText, axis: .vertical)
                .focused($inputFocused)
                .font(AppFont.body(14))
                .foregroundColor(AppColor.ink)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                        .fill(AppColor.bg1)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                                .strokeBorder(AppColor.text10, lineWidth: 1)
                        )
                )
                .onSubmit { addMessage() }
            Button { addMessage() } label: {
                holoSendButton
            }
            .accessibilityLabel("gönder")
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var holoSendButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                .fill(AppColor.holographic)
                .frame(width: 48, height: 48)
            RoundedRectangle(cornerRadius: 12.5, style: .continuous)
                .fill(AppColor.ink)
                .frame(width: 45, height: 45)
            Text("↵")
                .font(AppFont.body(18, weight: .bold))
                .foregroundColor(AppColor.bg0)
        }
        .opacity(
            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1
        )
    }

    // MARK: - Logic

    private func addMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = HomeViewModel.ManualMessage(sender: selectedSender, text: trimmed)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            vm.manualMessages.append(msg)
        }
        inputText = ""
        selectedSender = selectedSender == .other ? .user : .other
    }

    private var canSubmit: Bool {
        var hasContent = false
        var hasOther = false
        for msg in vm.manualMessages {
            if !msg.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hasContent = true
                if msg.sender == .other { hasOther = true }
            }
        }
        return hasContent && hasOther
    }
}
