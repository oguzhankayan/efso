import SwiftUI

/// Refined-y2k manuel profil — italic "onu tanıyalım." + 4 alanlı liste +
/// holo CTA "kaydet ve devam".
struct ManualProfileEntryView: View {
    @Bindable var vm: HomeViewModel

    @FocusState private var focused: Field?
    private enum Field: Hashable { case handle, bio, post(Int), photo(Int) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    section(label: "isim", placeholder: "@elif", text: $vm.manualHandle, field: .handle)
                    sectionMultiline(label: "bio", placeholder: "profilde yazan açıklama", text: $vm.manualBio, field: .bio, minHeight: 90)
                    postsSection
                    photoSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("bitti") { focused = nil }
            }
        }
    }

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
            EfsoTag("profil bilgisi", color: AppColor.text40)
            Spacer()
            Color.clear.frame(width: 60, height: 44)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("onu tanıyalım.")
                .font(AppFont.displayItalic(30, weight: .regular))
                .tracking(-0.025 * 30)
                .foregroundColor(AppColor.ink)
            Text("ne kadar verirsen o kadar isabetli açılış. en az bir alan yeter.")
                .font(AppFont.body(13))
                .foregroundColor(AppColor.text60)
        }
        .padding(.horizontal, 4)
    }

    private func section(label: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EfsoTag(label, color: AppColor.text40)
            TextField(placeholder, text: text)
                .focused($focused, equals: field)
                .font(AppFont.body(14.5))
                .foregroundColor(AppColor.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(fieldBg)
        }
    }

    private func sectionMultiline(label: String, placeholder: String, text: Binding<String>, field: Field, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EfsoTag(label, color: AppColor.text40)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.text30)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                }
                TextEditor(text: text)
                    .focused($focused, equals: field)
                    .font(AppFont.body(14.5))
                    .foregroundColor(AppColor.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: minHeight)
            }
            .background(fieldBg)
        }
    }

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(label: "sevdikleri", count: vm.manualPosts.count) {
                vm.manualPosts.append("")
                let i = vm.manualPosts.count - 1
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    focused = .post(i)
                }
            }
            ForEach(vm.manualPosts.indices, id: \.self) { i in
                indexedRow(binding: $vm.manualPosts[i], placeholder: "post / tweet / sevdiği şey", field: .post(i)) {
                    vm.manualPosts.remove(at: i)
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(label: "nerden", count: vm.manualPhotoDescriptions.count) {
                vm.manualPhotoDescriptions.append("")
                let i = vm.manualPhotoDescriptions.count - 1
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    focused = .photo(i)
                }
            }
            ForEach(vm.manualPhotoDescriptions.indices, id: \.self) { i in
                indexedRow(binding: $vm.manualPhotoDescriptions[i], placeholder: "kahveci, gülümsüyor, dağ fotosu", field: .photo(i)) {
                    vm.manualPhotoDescriptions.remove(at: i)
                }
            }
        }
    }

    private func sectionHeader(label: String, count: Int, onAdd: @escaping () -> Void) -> some View {
        HStack {
            EfsoTag(label, color: AppColor.text40)
            Spacer()
            if count < 5 {
                Button(action: onAdd) {
                    Text("+ ekle")
                        .font(AppFont.mono(11, weight: .medium))
                        .tracking(0.10 * 11)
                        .foregroundColor(AppColor.accent)
                }
            }
        }
    }

    private func indexedRow(binding: Binding<String>, placeholder: String, field: Field, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: binding, axis: .vertical)
                .focused($focused, equals: field)
                .font(AppFont.body(14))
                .foregroundColor(AppColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .lineLimit(1...4)
                .background(fieldBg)
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(AppColor.text40)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("sil")
        }
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColor.bg1)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppColor.text10, lineWidth: 1)
            )
    }

    private var canSubmit: Bool {
        func nonEmpty(_ s: String) -> Bool { !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return nonEmpty(vm.manualBio) || nonEmpty(vm.manualHandle)
            || vm.manualPosts.contains(where: nonEmpty)
            || vm.manualPhotoDescriptions.contains(where: nonEmpty)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            if let err = vm.lastError {
                Text(err)
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.warning)
                    .padding(.horizontal, 24)
            }
            HoloPrimaryButton(title: "tamam", isEnabled: canSubmit) {
                vm.lastError = nil
                vm.confirmManualInput()
            }
            .opacity(canSubmit ? 1 : 0.35)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}
