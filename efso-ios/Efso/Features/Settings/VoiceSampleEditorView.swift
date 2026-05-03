import SwiftUI

/// Yazım tarzı editörü — kullanıcının mesaj örneklerinden stil öğrenir.
struct VoiceSampleEditorView: View {
    let onClose: () -> Void

    @State private var sample: String = ""
    @State private var initialSample: String = ""
    @State private var loading: Bool = true
    @State private var saving: Bool = false
    @State private var error: String?
    @State private var loadFailed: Bool = false
    @FocusState private var focused: Bool

    private let maxLength: Int = 500

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    editor
                    if !sample.isEmpty {
                        detectCard
                    }
                    if let error {
                        Text(error)
                            .font(AppFont.body(12))
                            .foregroundColor(AppColor.danger)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)

            HoloPrimaryButton(title: saving ? "kaydediliyor" : "kaydet ve uygula", isEnabled: isDirty && !saving && !loadFailed) {
                Task { await save() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("bitti") { focused = false }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { onClose() } label: {
                Text("← geri")
                    .font(AppFont.mono(12))
                    .tracking(0.10 * 12)
                    .foregroundColor(AppColor.text60)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            Spacer()
            EfsoTag("yazım tarzı", color: AppColor.text40)
            Spacer()
            Color.clear.frame(width: 60, height: 44)
        }
        .padding(.top, 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("nasıl yazdığını\nbiz ezberleyelim.")
                .font(AppFont.displayItalic(30, weight: .regular))
                .tracking(-0.025 * 30)
                .foregroundColor(AppColor.ink)
                .lineSpacing(30 * 0.05)
            Text("son 5-10 mesajını yapıştır. üslup, kelime, noktalama, hepsi sayar.")
                .font(AppFont.body(13.5))
                .foregroundColor(AppColor.text60)
                .lineSpacing(13.5 * 0.4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if sample.isEmpty && !loading {
                    Text("\"yarın boş musun\"\n\"hadi gel kahve içelim\"\n\"of sıkıldım yaa\"\n...")
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.text30)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                if loading {
                    ProgressView()
                        .tint(AppColor.text40)
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if loadFailed {
                    VStack(spacing: 14) {
                        Text("yüklenemedi.")
                            .font(AppFont.body(14))
                            .foregroundColor(AppColor.text60)
                        Button {
                            Task { await load() }
                        } label: {
                            Text("tekrar dene")
                                .font(AppFont.mono(12))
                                .foregroundColor(AppColor.accent)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
                TextEditor(text: $sample)
                    .focused($focused)
                    .font(AppFont.body(14))
                    .foregroundColor(AppColor.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 220)
                    .disabled(loading || loadFailed)
                    .opacity((loading || loadFailed) ? 0 : 1)
                    .onChange(of: sample) { _, new in
                        if new.count > maxLength {
                            sample = String(new.prefix(maxLength))
                        }
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppColor.text20, lineWidth: 1)
                    )
            )
            HStack {
                Text("\(sample.count) / \(maxLength)")
                    .font(AppFont.mono(10))
                    .tracking(0.14 * 10)
                    .foregroundColor(AppColor.text40)
                Spacer()
                Button {
                    focused = true
                } label: {
                    Text("+ ÖRNEK EKLE")
                        .font(AppFont.mono(10))
                        .tracking(0.14 * 10)
                        .foregroundColor(AppColor.accent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var detectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EfsoTag("tespit · şu an", color: AppColor.accent)
            Text("\"kısa cümleler, lowercase, hafif bıkkınlık tonu. emoji yok.\"")
                .font(AppFont.displayItalic(15.5, weight: .regular))
                .foregroundColor(AppColor.ink)
                .lineSpacing(15.5 * 0.30)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.bg2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppColor.text10, lineWidth: 1)
                )
        )
    }

    private var isDirty: Bool {
        sample.trimmingCharacters(in: .whitespacesAndNewlines)
            != initialSample.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct ProfileRow: Decodable {
        let voice_sample: String?
    }

    private func load() async {
        loading = true
        loadFailed = false
        defer { loading = false }
        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            let response: [ProfileRow] = try await SupabaseService.shared
                .from("profiles")
                .select("voice_sample")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            let current = response.first?.voice_sample ?? ""
            sample = current
            initialSample = current
        } catch {
            self.loadFailed = true
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = trimmed.isEmpty ? nil : trimmed
        struct UpdatePayload: Encodable { let voice_sample: String? }
        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            try await SupabaseService.shared
                .from("profiles")
                .update(UpdatePayload(voice_sample: value))
                .eq("id", value: userId)
                .execute()
            initialSample = sample
            error = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            // Kaydetme hatası — teknik detay kullanıcıya gösterilmez
            self.error = "kaydedilemedi. tekrar dene."
        }
    }
}
