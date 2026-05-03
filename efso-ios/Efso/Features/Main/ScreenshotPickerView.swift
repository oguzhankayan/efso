import SwiftUI
import PhotosUI
import UIKit

/// Refined-y2k cevap modu input — büyük italic başlık, dashed dropzone,
/// "elle yaz" satırı, sticky ton seçici + holo "üç cevap üret" CTA.
/// PhotoKit recents + clipboard paste + extra context disclosure korundu.
struct ScreenshotPickerView: View {
    @Bindable var vm: HomeViewModel
    let mode: Mode

    @State private var subs = SubscriptionManager.shared
    @State private var clipboardHasImage: Bool = false
    @State private var extraContextOpen: Bool = false
    @State private var cachedThumbnail: UIImage?
    @State private var manualTapTrigger: Bool = false
    @State private var safeAreaTopInset: CGFloat = 59
    @FocusState private var extraContextFocused: Bool


    var body: some View {
        VStack(spacing: 0) {
            topNav
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headline
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    contentArea
                        .padding(.top, 22)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("bitti") { extraContextFocused = false }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: manualTapTrigger)
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
               let inset = scene.windows.first?.safeAreaInsets.top, inset > 0 {
                safeAreaTopInset = inset
            }
            refreshClipboard()
            if let data = vm.pickedScreenshot { cachedThumbnail = UIImage(data: data) }
        }
        .onChange(of: vm.pickedScreenshot) { _, newData in
            cachedThumbnail = newData.flatMap { UIImage(data: $0) }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                refreshClipboard()
            }
        }
    }

    // MARK: - Top nav

    private var topNav: some View {
        HStack {
            Button { vm.backToHome() } label: {
                Text("← geri")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("geri")

            Spacer()
            EfsoTag(modeTitle, color: AppColor.text40)
            Spacer()
            if !subs.isActive {
                quotaChip
                    .frame(minWidth: 60, alignment: .trailing)
            } else {
                Color.clear.frame(width: 60, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTopInset)
        .padding(.bottom, 4)
    }

    private var modeTitle: String {
        mode == .cevap ? "cevap" : "\(mode.label.trLower)"
    }

    private var quotaChip: some View {
        let usedToday = vm.todayUsageCount
        let cap = 3
        return Text("\(min(usedToday, cap))/\(cap)")
            .font(AppFont.mono(10))
            .tracking(0.14 * 10)
            .foregroundColor(usedToday >= cap ? AppColor.warning : AppColor.text60)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColor.bg1))
            .overlay(Capsule().strokeBorder(AppColor.text10, lineWidth: 1))
    }

    // MARK: - Headline

    private var hasContent: Bool {
        vm.manualInputConfirmed || vm.pickerState != .empty
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: hasContent ? 0 : 8) {
            if !hasContent {
                Text(mode.pickerHeadline)
                    .font(AppFont.displayItalic(38, weight: .regular))
                    .tracking(-0.03 * 38)
                    .foregroundColor(AppColor.ink)
                    .lineSpacing(38 * 0.05)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(mode.pickerSubline)
                .font(AppFont.body(14))
                .foregroundColor(AppColor.text60)
                .lineSpacing(14 * 0.4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(AppAnimation.standard, value: hasContent)
    }

    // MARK: - Content router

    @ViewBuilder
    private var contentArea: some View {
        if vm.manualInputConfirmed {
            manualDoneState
        } else {
            switch vm.pickerState {
            case .empty:
                emptyState
            case .uploading:
                uploadingState
            case .done(let data):
                doneState(thumbnail: data)
            }
        }
    }

    // MARK: - EMPTY

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            dropzone
            orDivider
            manualRow
            if clipboardHasImage {
                pasteRow.transition(.opacity)
            }
        }
    }

    private var dropzone: some View {
        PhotosPicker(
            selection: $vm.pickedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColor.bg2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppColor.text10, lineWidth: 1)
                        )
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(AppColor.accent)
                }
                .frame(width: 56, height: 56)

                Text("screenshot bırak")
                    .font(AppFont.displayItalic(22, weight: .regular))
                    .tracking(-0.02 * 22)
                    .foregroundColor(AppColor.ink)

                Text("png · jpg · 24 saat sonra silinir")
                    .font(AppFont.mono(10))
                    .tracking(0.16 * 10)
                    .foregroundColor(AppColor.text40)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppColor.accent.opacity(0.04))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            AppColor.text30,
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                        )
                }
            )
        }
        .accessibilityLabel("ekran görüntüsü seç")
    }

    private var orDivider: some View {
        HStack {
            Spacer()
            EfsoTag("ya da", color: AppColor.text40)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var manualRow: some View {
        Button {
            manualTapTrigger.toggle()
            vm.isManualMode = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("elle yaz")
                            .font(AppFont.body(15))
                            .foregroundColor(AppColor.ink)
                        Text("·")
                            .foregroundColor(AppColor.text40)
                        Text(mode == .acilis ? "profili sen tarif et" : "konuşmayı sen aktar")
                            .font(AppFont.body(15))
                            .foregroundColor(AppColor.text60)
                    }
                }
                Spacer()
                Text("→")
                    .font(AppFont.mono(18))
                    .foregroundColor(AppColor.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var pasteRow: some View {
        Button { handlePaste() } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.pop)
                Text("panodan yapıştır")
                    .font(AppFont.body(14, weight: .medium))
                    .foregroundColor(AppColor.ink)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Uploading + done

    private var uploadingState: some View {
        VStack(spacing: 18) {
            if let img = cachedThumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
                    .opacity(0.75)
            }
            HStack(spacing: 10) {
                ProgressView().tint(AppColor.accent).scaleEffect(0.9)
                Text("yorumlanıyor")
                    .font(AppFont.body(14))
                    .foregroundColor(AppColor.text60)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func doneState(thumbnail data: Data) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(archetypeEmoji).font(.system(size: 14))
                Text("\(archetypeShortLabel) tarzında")
                    .font(AppFont.mono(11))
                    .tracking(0.14 * 11)
                    .foregroundColor(AppColor.text60)
                    .textCase(.uppercase)
                Spacer()
            }
            ZStack(alignment: .topTrailing) {
                if let img = cachedThumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                Circle()
                    .fill(AppColor.pop)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColor.bg0)
                    )
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColor.holographic, lineWidth: 1.2)
            )

            extraContextDisclosure
        }
    }

    private var extraContextDisclosure: some View {
        VStack(alignment: .leading, spacing: extraContextOpen ? 10 : 0) {
            Button {
                withAnimation(AppAnimation.standard) { extraContextOpen.toggle() }
                if extraContextOpen {
                    Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        extraContextFocused = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 13))
                        .foregroundColor(AppColor.text60)
                    Text("bilmem gereken bir şey?")
                        .font(AppFont.body(13, weight: .medium))
                        .foregroundColor(AppColor.ink)
                    if !vm.extraContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Circle().fill(AppColor.pop).frame(width: 5, height: 5)
                    }
                    Spacer()
                    Image(systemName: extraContextOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(AppColor.text40)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if extraContextOpen {
                ZStack(alignment: .topLeading) {
                    if vm.extraContext.isEmpty {
                        Text("örn: bu kişi eski sevgilim. iki yıl önce ayrıldık.")
                            .font(AppFont.body(13))
                            .italic()
                            .foregroundColor(AppColor.text30)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }
                    TextEditor(text: $vm.extraContext)
                        .focused($extraContextFocused)
                        .font(AppFont.body(13))
                        .foregroundColor(AppColor.ink)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .frame(minHeight: 92)
                        .onChange(of: vm.extraContext) { _, new in
                            if new.count > 500 {
                                vm.extraContext = String(new.prefix(500))
                            }
                        }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColor.bg1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppColor.text10, lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Bottom bar (sticky tone + CTA)

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 12) {
            tonePicker
                .padding(.horizontal, 20)
            cta
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .padding(.top, 12)
    }

    private var tonePicker: some View {
        TonePicker(
            tones: Tone.allLabels,
            selected: vm.selectedTone?.label.trLower ?? "",
            onSelect: { label in
                if let tone = Tone.allCases.first(where: { $0.label.trLower == label }) {
                    vm.selectedTone = tone
                }
            },
            label: ""
        )
    }

    @ViewBuilder
    private var cta: some View {
        if vm.manualInputConfirmed {
            HoloPrimaryButton(title: "üç cevap üret") { vm.proceedToManualGeneration() }
        } else {
            switch vm.pickerState {
            case .done:
                HoloPrimaryButton(title: "üç cevap üret") { vm.proceedToGeneration() }
            case .empty, .uploading:
                HoloPrimaryButton(title: "üç cevap üret", isEnabled: false) {}
                    .opacity(0.35)
            }
        }
    }

    // MARK: - Manual done state

    private var manualDoneState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(archetypeEmoji).font(.system(size: 14))
                Text("\(archetypeShortLabel) tarzında")
                    .font(AppFont.mono(11))
                    .tracking(0.14 * 11)
                    .foregroundColor(AppColor.text60)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    vm.manualInputConfirmed = false
                    vm.isManualMode = true
                    vm.pickerState = .empty
                } label: {
                    Text("düzenle")
                        .font(AppFont.mono(11))
                        .tracking(0.10 * 11)
                        .foregroundColor(AppColor.accent)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
            }

            if mode == .acilis {
                manualProfileSummary
            } else {
                manualChatSummary
            }

            extraContextDisclosure
        }
    }

    private var manualProfileSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !vm.manualHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileRow(label: "isim", value: vm.manualHandle)
            }
            if !vm.manualBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileRow(label: "bio", value: vm.manualBio)
            }
            let posts = vm.manualPosts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !posts.isEmpty {
                profileRow(label: "sevdikleri", value: posts.joined(separator: " · "))
            }
            let photos = vm.manualPhotoDescriptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !photos.isEmpty {
                profileRow(label: "fotoğraflar", value: photos.joined(separator: " · "))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColor.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColor.holographic, lineWidth: 1.2)
                )
        )
    }

    private func profileRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.mono(10))
                .tracking(0.14 * 10)
                .foregroundColor(AppColor.text40)
                .textCase(.uppercase)
            Text(value)
                .font(AppFont.body(13.5))
                .foregroundColor(AppColor.ink)
                .lineLimit(3)
        }
    }

    private var manualChatSummary: some View {
        VStack(spacing: 6) {
            ForEach(vm.manualMessages) { msg in
                HStack {
                    if msg.sender == .user { Spacer(minLength: 48) }
                    Text(msg.text)
                        .font(AppFont.body(13.5))
                        .foregroundColor(msg.sender == .user ? AppColor.bg0 : AppColor.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(msg.sender == .user ? AppColor.ink : AppColor.bg2)
                        )
                    if msg.sender == .other { Spacer(minLength: 48) }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColor.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColor.holographic, lineWidth: 1.2)
                )
        )
    }

    // MARK: - Helpers

    private func refreshClipboard() {
        clipboardHasImage = UIPasteboard.general.hasImages
    }

    private func handlePaste() {
        guard let img = UIPasteboard.general.image,
              let data = img.jpegData(compressionQuality: 0.92)
        else {
            vm.lastError = "panodaki görsel okunamadı"
            return
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        vm.acceptScreenshotData(data)
    }

    private var archetypeEmoji: String {
        guard let a = vm.archetype else { return "✨" }
        return String(a.label.first ?? "✨")
    }

    private var archetypeShortLabel: String {
        guard let a = vm.archetype else { return "" }
        let parts = a.label.split(separator: " ", maxSplits: 1)
        return (parts.last.map(String.init) ?? "").trLower
    }
}
