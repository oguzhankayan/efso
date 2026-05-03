import SwiftUI

/// Kalibrasyon yenileme — sign out etmeden sadece quiz tekrar.
/// CalibrationIntro → Quiz → Result → onComplete callback.
struct RecalibrationFlowView: View {
    @State private var vm = OnboardingViewModel()
    let onComplete: (ArchetypePrimary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CosmicBackground()
            currentStep
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id(vm.step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AppAnimation.standard, value: vm.step)
        .animation(AppAnimation.standard, value: vm.quizIndex)
        .onAppear {
            vm.step = .calibrationIntro
        }
        .onChange(of: vm.step) { _, newStep in
            if newStep == .completed, let arch = vm.archetype {
                onComplete(arch.archetypePrimary)
            }
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch vm.step {
        case .calibrationIntro:
            CalibrationIntroView(vm: vm)
                .overlay(alignment: .topLeading) { closeButton }
        case .calibrationQuiz:
            CalibrationQuizView(vm: vm)
                .overlay(alignment: .topLeading) { closeButton }
        case .calibrationResult:
            CalibrationResultView(vm: vm)
        default:
            EmptyView()
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.text60)
                .frame(width: 44, height: 44)
        }
        .padding(.top, 4)
        .padding(.leading, 12)
        .accessibilityLabel("kapat")
    }
}
