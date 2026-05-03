import SwiftUI
import UserNotifications

struct NotificationSettingsSheet: View {
    let isAuthorized: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("notif_daily_reminder") private var dailyReminder = true
    @AppStorage("notif_tips") private var tips = true
    @AppStorage("notif_updates") private var updates = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Capsule()
                    .fill(AppColor.bg2)
                    .frame(width: 40, height: 4)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.text40)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("kapat")
                .padding(.trailing, 8)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("bildirimler")
                    .font(AppFont.displayItalic(24, weight: .regular))
                    .tracking(-0.02 * 24)
                    .foregroundColor(AppColor.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if !isAuthorized {
                systemPermissionBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            VStack(spacing: 0) {
                notifToggle(title: "günlük hatırlatma", subtitle: "konuşma güncellemen var", isOn: $dailyReminder)
                divider
                notifToggle(title: "ipuçları", subtitle: "daha iyi mesajlar için öneriler", isOn: $tips)
                divider
                notifToggle(title: "yenilikler", subtitle: "yeni özellikler ve güncellemeler", isOn: $updates)
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                    .fill(AppColor.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous)
                            .strokeBorder(AppColor.text10, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.section, style: .continuous))
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CosmicBackground())
        .preferredColorScheme(.dark)
    }

    private var systemPermissionBanner: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 16))
                    .foregroundColor(AppColor.warning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("bildirimler kapalı")
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundColor(AppColor.ink)
                    Text("ayarlardan izin ver")
                        .font(AppFont.body(12))
                        .foregroundColor(AppColor.text60)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.text40)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColor.warning.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppColor.warning.opacity(0.2), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func notifToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(14.5))
                    .foregroundColor(AppColor.ink)
                Text(subtitle)
                    .font(AppFont.body(12))
                    .foregroundColor(AppColor.text40)
            }
        }
        .tint(AppColor.accent)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColor.text10)
            .frame(height: 1)
            .padding(.leading, 18)
    }
}
