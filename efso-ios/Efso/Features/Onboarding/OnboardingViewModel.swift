import Foundation
import Observation

/// Onboarding flow state machine (Rizz playbook reorder).
/// Paywall önce, kalibrasyon sonra — conversion first.
enum OnboardingStep: Int, CaseIterable {
    case splash
    case valueIntro           // 2-page value carousel
    case notification
    case demographic          // yaş, cinsiyet, niyet
    case aiConsent
    case paywall
    case calibrationIntro     // quiz tanıtımı (post-paywall)
    case calibrationQuiz
    case calibrationResult
    case completed
}

@Observable
@MainActor
final class OnboardingViewModel {
    var step: OnboardingStep = .splash

    var demographic = DemographicAnswers()
    var quizAnswers: [String: CalibrationAnswer] = [:]
    var quizIndex: Int = 0
    var questions: [CalibrationQuestion] = []

    var archetype: ArchetypeResult?
    var notificationGranted: Bool = false
    var aiConsentGiven: Bool = false

    var isSubmitting = false
    var lastError: String?

    init() {
        loadQuestions()
    }

    // MARK: - Step navigation

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1), prev.rawValue >= 0 else { return }
        step = prev
    }

    // MARK: - Quiz

    var currentQuestion: CalibrationQuestion? {
        questions.indices.contains(quizIndex) ? questions[quizIndex] : nil
    }

    var totalQuestions: Int { questions.count }

    func recordAnswer(_ answer: CalibrationAnswer) {
        quizAnswers[answer.questionId] = answer
    }

    func nextQuestion() {
        if quizIndex < questions.count - 1 {
            quizIndex += 1
        } else {
            advance()
        }
    }

    func skipCurrentQuestion() {
        guard let q = currentQuestion, q.optional == true else { return }
        nextQuestion()
    }

    func goToPreviousQuestion() {
        if quizIndex > 0 {
            quizIndex -= 1
        } else {
            goBack()
        }
    }

    // MARK: - Calibration submission

    func submitCalibration() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let answers = Array(quizAnswers.values)

        struct CalibrateBody: Encodable {
            let answers: [CalibrationAnswer]
        }

        do {
            let result: ArchetypeResult = try await APIClient.shared.invokeJSON(
                .calibrate,
                body: CalibrateBody(answers: answers),
                as: ArchetypeResult.self
            )
            self.archetype = result
            self.lastError = nil
        } catch {
            // Kalibrasyon ağ hatası — kullanıcıya teknik detay gösterme
            self.lastError = "bağlantı hatası. tekrar dene."
            self.archetype = nil
        }
    }

    func retryCalibrationSubmit() {
        Task { await submitCalibration() }
    }

    // MARK: - Question loading

    private func loadQuestions() {
        guard let url = Bundle.main.url(forResource: "calibration-questions", withExtension: "json") else {
            // Uygulama kaynak dosyası eksik — teknik detay
            self.lastError = "bir şeyler ters gitti. uygulamayı güncelle."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            self.questions = try JSONDecoder().decode([CalibrationQuestion].self, from: data)
        } catch {
            // JSON decode hatası — teknik detay kullanıcıya gösterilmez
            self.lastError = "bir şeyler ters gitti. uygulamayı güncelle."
        }
    }
}
