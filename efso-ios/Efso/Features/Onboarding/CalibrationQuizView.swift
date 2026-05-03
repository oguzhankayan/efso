import SwiftUI

/// Refined-y2k quiz router — 6 cell tipi (single, binary, likert, slider, image_binary, free_text).
/// Üst chrome: holographic progress bar + step counter. Seçili kart accent border + ✓ rozeti.
struct CalibrationQuizView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var selectedValues: Set<String> = []
    @State private var likertValue: Int = 3
    @State private var sliderValue: Double = 0.5
    @State private var freeText: String = ""
    @FocusState private var freeTextFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OnbHeader(
                step: vm.quizIndex + 1,
                total: vm.totalQuestions,
                onBack: { vm.goToPreviousQuestion() }
            )

            if let q = vm.currentQuestion {
                ScrollView(showsIndicators: false) {
                    scrollContent(for: q)
                }
                .id(q.id)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                ctaBlock(for: q)
                    .padding(.bottom, 28)
            } else if vm.lastError != nil {
                VStack(spacing: 16) {
                    Text("bir şeyler ters gitti.")
                        .font(AppFont.displayItalic(20, weight: .regular))
                        .foregroundColor(AppColor.ink)
                    Text("uygulamayı kapat ve tekrar aç.")
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.text60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            }
        }
        .animation(AppAnimation.standard, value: vm.quizIndex)
        .onChange(of: vm.quizIndex) { _, _ in resetCellState() }
        .onAppear { resetCellState() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("bitti") { freeTextFocused = false }
            }
        }
    }

    @ViewBuilder
    private func scrollContent(for q: CalibrationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(String(format: "%02d", vm.quizIndex + 1)) / \(String(format: "%02d", vm.totalQuestions))")
                    .font(AppFont.mono(11, weight: .medium))
                    .tracking(0.14 * 11)
                    .foregroundColor(AppColor.accent)
                    .textCase(.uppercase)
                Text(q.title.trLower)
                    .font(AppFont.displayItalic(32, weight: .regular))
                    .tracking(-0.025 * 32)
                    .foregroundColor(AppColor.ink)
                    .lineSpacing(32 * 0.05)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub = q.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(AppFont.body(14))
                        .foregroundColor(AppColor.text60)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            cell(for: q)
                .padding(.horizontal, 20)
                .padding(.top, 28)
        }
    }

    @ViewBuilder
    private func ctaBlock(for q: CalibrationQuestion) -> some View {
        VStack(spacing: 14) {
            if let footer = q.footerLink {
                Button {
                    if footer == "atla" || q.optional == true {
                        vm.skipCurrentQuestion()
                    }
                } label: {
                    Text(footer.trUpper)
                        .font(AppFont.mono(11))
                        .tracking(0.14 * 11)
                        .foregroundColor(AppColor.text40)
                        .underline(true, color: AppColor.text20)
                }
            }
            HoloPrimaryButton(title: "devam", isEnabled: canContinue(for: q)) {
                saveAnswerAndContinue(for: q)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Cells

    @ViewBuilder
    private func cell(for q: CalibrationQuestion) -> some View {
        switch q.type {
        case .singleSelect:
            singleSelectCell(options: q.options ?? [])
        case .binary, .imageBinary:
            binaryCell(options: q.options ?? [], stacked: q.type == .imageBinary)
        case .multiSelect, .multiSelectWithPriority:
            multiSelectCell(options: q.options ?? [])
        case .likert:
            likertCell(min: q.scaleMin ?? 1, max: q.scaleMax ?? 5, labels: q.scaleLabels ?? [])
        case .slider:
            sliderCell(minLabel: q.minLabel ?? "", maxLabel: q.maxLabel ?? "")
        case .freeText:
            freeTextCell(maxLength: q.maxLength ?? 500)
        }
    }

    private func singleSelectCell(options: [CalibrationOption]) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.text) { opt in
                let on = selectedValues.contains(opt.text)
                Button { selectedValues = [opt.text] } label: {
                    HStack {
                        Text(opt.text.trLower)
                            .font(AppFont.body(15.5))
                            .foregroundColor(AppColor.ink)
                        Spacer()
                        if on {
                            Text("✓")
                                .font(AppFont.mono(11, weight: .medium))
                                .foregroundColor(AppColor.bg0)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(AppColor.accent))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? AppColor.bg2 : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(on ? AppColor.accent : AppColor.text10, lineWidth: 1)
                    )
                }
                .accessibilityValue(on ? "seçili" : "")
                .sensoryFeedback(.selection, trigger: selectedValues)
            }
        }
    }

    @ViewBuilder
    private func binaryCell(options: [CalibrationOption], stacked: Bool) -> some View {
        if stacked {
            VStack(spacing: 12) {
                ForEach(options, id: \.text) { opt in
                    binaryCard(opt, height: 130, stacked: true)
                }
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(options, id: \.text) { opt in
                    binaryCard(opt, height: 200, stacked: false)
                }
            }
        }
    }

    private func binaryCard(_ opt: CalibrationOption, height: CGFloat, stacked: Bool) -> some View {
        let key = opt.id ?? opt.text
        let on = selectedValues.contains(key)
        return Button { selectedValues = [key] } label: {
            ZStack(alignment: .topLeading) {
                if stacked {
                    HStack(spacing: 14) {
                        Text(opt.text.trLower)
                            .font(AppFont.body(17, weight: .medium))
                            .foregroundColor(AppColor.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if on {
                            Text("✓")
                                .font(AppFont.mono(11, weight: .medium))
                                .foregroundColor(AppColor.bg0)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(AppColor.accent))
                        }
                    }
                    .padding(18)
                } else {
                    VStack(spacing: 14) {
                        if let e = opt.emoji {
                            Text(e).font(.system(size: 34))
                        }
                        Text(opt.text.trLower)
                            .font(AppFont.body(15, weight: .medium))
                            .foregroundColor(AppColor.ink)
                            .lineSpacing(15 * 0.30)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(on ? AppColor.bg2 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(on ? AppColor.accent : AppColor.text10, lineWidth: on ? 1.5 : 1)
            )
        }
        .accessibilityValue(on ? "seçili" : "")
        .sensoryFeedback(.selection, trigger: selectedValues)
    }

    private func multiSelectCell(options: [CalibrationOption]) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.text) { opt in
                let on = selectedValues.contains(opt.text)
                Button {
                    if on { selectedValues.remove(opt.text) }
                    else { selectedValues.insert(opt.text) }
                } label: {
                    HStack {
                        Text(opt.text.trLower)
                            .font(AppFont.body(15))
                            .foregroundColor(AppColor.ink)
                        Spacer()
                        if on {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColor.accent)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? AppColor.bg2 : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(on ? AppColor.accent : AppColor.text10, lineWidth: 1)
                    )
                }
                .accessibilityValue(on ? "seçili" : "")
            }
        }
    }

    private func likertCell(min minValue: Int, max maxValue: Int, labels: [String]) -> some View {
        let dots: [Int] = Array(minValue...maxValue)
        return VStack(spacing: 28) {
            HStack {
                ForEach(dots, id: \.self) { (n: Int) in
                    let on = likertValue == n
                    Button { likertValue = n } label: {
                        Circle()
                            .fill(on ? AnyShapeStyle(AppColor.holographic) : AnyShapeStyle(Color.clear))
                            .frame(width: on ? 32 : 18, height: on ? 32 : 18)
                            .overlay(
                                Circle().stroke(on ? Color.clear : AppColor.text20, lineWidth: 1.5)
                            )
                            .shadow(color: on ? AppColor.accent.opacity(0.4) : .clear, radius: 10)
                            .frame(maxWidth: .infinity)
                            .animation(AppAnimation.standard, value: likertValue)
                    }
                    .accessibilityLabel("puan \(n)")
                    .accessibilityValue(on ? "seçili" : "")
                    .sensoryFeedback(.selection, trigger: likertValue)
                }
            }
            HStack {
                if labels.count >= 1 { Text(labels[0].trLower).foregroundColor(AppColor.text60) }
                Spacer()
                if labels.count >= 2 { Text(labels[1].trLower).foregroundColor(AppColor.text60) }
                Spacer()
                if labels.count >= 3 { Text(labels[2].trLower).foregroundColor(AppColor.text60) }
            }
            .font(AppFont.body(13))
        }
        .padding(.top, 30)
    }

    private func sliderCell(minLabel: String, maxLabel: String) -> some View {
        VStack(spacing: 24) {
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.bg2).frame(height: 4)
                GeometryReader { geo in
                    Capsule()
                        .fill(AppColor.holographic)
                        .frame(width: max(0, geo.size.width * sliderValue), height: 4)
                    Circle()
                        .fill(AppColor.ink)
                        .frame(width: 28, height: 28)
                        .shadow(color: AppColor.accent.opacity(0.4), radius: 10)
                        .position(x: geo.size.width * sliderValue, y: 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    sliderValue = max(0, min(1, value.location.x / geo.size.width))
                                }
                        )
                }
                .frame(height: 28)
            }
            .frame(height: 28)
            .padding(.top, 30)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("kaydırıcı")
            .accessibilityValue("\(Int(sliderValue * 100)) yüzde")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    sliderValue = min(1, sliderValue + 0.1)
                case .decrement:
                    sliderValue = max(0, sliderValue - 0.1)
                @unknown default:
                    break
                }
            }
            HStack {
                Text(minLabel.trLower).foregroundColor(AppColor.text60)
                Spacer()
                Text(maxLabel.trLower).foregroundColor(AppColor.text60)
            }
            .font(AppFont.body(13))
        }
    }

    private func freeTextCell(maxLength: Int) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if freeText.isEmpty {
                    Text("ne yapıyorsun, neden buradasın, ne tarz mesajlar atıyorsun. ne hissediyorsan yaz...")
                        .font(AppFont.displayItalic(16, weight: .regular))
                        .foregroundColor(AppColor.text30)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                }
                TextEditor(text: $freeText)
                    .focused($freeTextFocused)
                    .font(AppFont.body(16))
                    .foregroundColor(AppColor.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .frame(minHeight: 220)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
            Text("\(freeText.count) / \(maxLength) KARAKTER")
                .font(AppFont.mono(10))
                .tracking(0.14 * 10)
                .foregroundColor(AppColor.text40)
        }
    }

    // MARK: - Save + advance

    private func canContinue(for q: CalibrationQuestion) -> Bool {
        if q.optional == true { return true }
        switch q.type {
        case .singleSelect, .binary, .imageBinary, .multiSelect, .multiSelectWithPriority:
            return !selectedValues.isEmpty
        case .likert, .slider, .freeText:
            return true
        }
    }

    private func saveAnswerAndContinue(for q: CalibrationQuestion) {
        let answer: CalibrationAnswer
        switch q.type {
        case .singleSelect, .binary, .imageBinary, .multiSelect, .multiSelectWithPriority:
            answer = CalibrationAnswer(questionId: q.id, selected: Array(selectedValues), freeText: nil)
        case .likert:
            answer = CalibrationAnswer(questionId: q.id, selected: [String(likertValue)], freeText: nil)
        case .slider:
            answer = CalibrationAnswer(questionId: q.id, selected: [String(format: "%.2f", sliderValue)], freeText: nil)
        case .freeText:
            answer = CalibrationAnswer(questionId: q.id, selected: [], freeText: freeText.isEmpty ? nil : freeText)
        }
        vm.recordAnswer(answer)
        vm.nextQuestion()
    }

    private func resetCellState() {
        selectedValues = []
        likertValue = 3
        sliderValue = 0.5
        freeText = ""
        if let q = vm.currentQuestion, let prev = vm.quizAnswers[q.id] {
            switch q.type {
            case .singleSelect, .binary, .imageBinary, .multiSelect, .multiSelectWithPriority:
                selectedValues = Set(prev.selected)
            case .likert:
                if let v = prev.selected.first, let n = Int(v) { likertValue = n }
            case .slider:
                if let v = prev.selected.first, let f = Double(v) { sliderValue = f }
            case .freeText:
                freeText = prev.freeText ?? ""
            }
        }
    }
}

#Preview {
    CalibrationQuizView(vm: OnboardingViewModel())
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
}
