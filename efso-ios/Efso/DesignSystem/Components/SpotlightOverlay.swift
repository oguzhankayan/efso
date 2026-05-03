import SwiftUI
import UIKit

/// Tek-seferlik spotlight overlay — bir UI elementine kullanıcının dikkatini
/// çeker. Dismiss edildiğinde caller `onDismiss` ile UD flag yazar.
///
/// Tasarım kararları (2026-05-01 v2):
/// - Tam ekran dim: GeometryReader `.ignoresSafeArea()` ile notch + home
///   indicator dahil tüm yüzey. Safe-area kenarlarda parlak strip kalmaz.
/// - Cutout: ekran rect ∖ target circle (eo-fill).
/// - Hedef ringi holographic, çift kademe (inner solid + outer halo).
/// - Caption: hedefin altına, leading edge hedefin leading edge'iyle
///   hizalı. Ok ikonu yok; uzaysal ilişki cutout-glow + yakın caption
///   ile zaten net.
/// - Kenar overflow guard: caption ekran kenarına 24pt margin korur,
///   gerekirse içe çekilir.
/// - Tap anywhere dismiss eder. Spring fade-in/fade-out.
struct SpotlightOverlay: View {
    let targetCenter: CGPoint
    let targetRadius: CGFloat
    let title: String
    let subtitle: String?
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    @State private var visible = false
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            ZStack(alignment: .topLeading) {
                // Dimmed donut: full screen ∖ target circle.
                dimMask(screen: screen)

                // Outer halo — yumuşak parıltı, hedef ringe derinlik.
                Circle()
                    .stroke(AppColor.holographic, lineWidth: 0.8)
                    .frame(
                        width: (targetRadius + 14) * 2,
                        height: (targetRadius + 14) * 2
                    )
                    .position(targetCenter)
                    .opacity(visible ? (pulse ? 0.55 : 0.20) : 0)
                    .blur(radius: 1.5)
                    .allowsHitTesting(false)

                // Inner ring — net, sabit.
                Circle()
                    .stroke(AppColor.holographic, lineWidth: 1.5)
                    .frame(
                        width: (targetRadius + 8) * 2,
                        height: (targetRadius + 8) * 2
                    )
                    .position(targetCenter)
                    .opacity(visible ? 0.85 : 0)
                    .allowsHitTesting(false)

                // Caption — hedefin altında, leading-aligned.
                captionCard(screen: screen)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 6)
            }
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.28), value: visible)
            .onAppear {
                visible = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Halo pulse — sürekli, 1.4s tekrar.
                withAnimation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            }
        }
        // GeometryReader'ı da ekran sınırını aşırı tutsun ki notch + home
        // indicator alanları da dimlensin.
        .ignoresSafeArea()
    }

    /// Tam ekran dim + target circle cutout.
    /// Path eo-fill ile rect içinden circle çıkarılır (donut shape).
    private func dimMask(screen: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: screen))
            path.addEllipse(
                in: CGRect(
                    x: targetCenter.x - targetRadius - 4,
                    y: targetCenter.y - targetRadius - 4,
                    width: (targetRadius + 4) * 2,
                    height: (targetRadius + 4) * 2
                )
            )
        }
        .fill(
            AppColor.bg0.opacity(visible ? 0.92 : 0.0),
            style: FillStyle(eoFill: true)
        )
        .contentShape(Rectangle())   // tap anywhere
        .onTapGesture { dismiss() }
    }

    /// Caption — hedefin altına, leading edge hedef leading edge ile
    /// hizalı. Ekran kenarına 24pt margin guard.
    private func captionCard(screen: CGSize) -> some View {
        // Caption'ın görünür alanı ekrana 24pt margin korur.
        let sideMargin: CGFloat = 24
        let maxWidth: CGFloat = min(screen.width - sideMargin * 2, 320)

        // Leading edge hedefin leading edge'iyle hizalı (target.x - radius).
        // Ama ekran kenarına çarpmasın diye min/max ile clamp.
        let proposedX = targetCenter.x - targetRadius
        let leadingX = max(sideMargin, min(proposedX, screen.width - maxWidth - sideMargin))

        // Y: hedefin alt kenarından 28pt aşağı (halo outer ring'in
        // caption üst kenarına dokunmaması için breathing room).
        let topY = targetCenter.y + targetRadius + 28

        // Eğer caption ekranın alt yarısına kayıyorsa (target ekranın
        // alt yarısında ise), caption hedefin üstüne çıkar.
        let captionGoesAbove = (topY + 140) > screen.height
        let finalY = captionGoesAbove
            ? max(sideMargin, targetCenter.y - targetRadius - 20 - 140)
            : topY

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.body(15, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.text60)
                    .lineSpacing(12 * 0.35)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Text("anladım")
                    .font(AppFont.body(12, weight: .medium))
                    .foregroundColor(AppColor.bg0)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppColor.lime))
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(width: maxWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                .fill(AppColor.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                        .strokeBorder(AppColor.holographic, lineWidth: 1)
                        .opacity(0.6)
                )
                .shadow(color: AppColor.bg0.opacity(0.5), radius: 24, x: 0, y: 10)
        )
        // Caption'ın sol-üst köşesi (leadingX, finalY) konumunda olsun.
        .offset(x: leadingX, y: finalY)
        .onTapGesture { dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle ?? ""). dokunarak kapat.")
        .accessibilityAddTraits(.isButton)
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        visible = false
        // Fade-out animasyonu bitince state kapat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            isPresented = false
            onDismiss()
        }
    }
}
