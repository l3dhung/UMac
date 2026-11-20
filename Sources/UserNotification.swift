import AppKit
import SwiftUI
import UserNotifications

/// Mức độ thông báo: quyết định có phát âm thanh hay không.
enum NotificationLevel {
    /// Báo tin (đã khoá sạc, hết giờ chống ngủ…): im lặng.
    case info
    /// Cần chú ý (pin 20%, nhiệt độ cao…): có âm thanh.
    case warning
    /// Khẩn cấp (pin 10%): có âm thanh, luôn hiện kể cả khi đang mở UMac.
    case critical
}

/// Gửi thông báo hệ thống mang tên và icon UMac (Notification Center).
/// Nếu người dùng tắt quyền thông báo, hiện thẻ nhỏ góc màn hình thay thế để không mất cảnh báo.
func postUserNotification(title: String, body: String, level: NotificationLevel = .info) {
    DispatchQueue.main.async {
        UMacNotifier.shared.post(title: title, body: body, level: level)
    }
}

@MainActor
final class UMacNotifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = UMacNotifier()

    @Published private(set) var isAuthorized = false
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Xin quyền một lần lúc mở app để thông báo đầu tiên không bị lỡ.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                appLog("🔔 Notifications: xin quyền lỗi: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { self.isAuthorized = granted }
        }
    }

    func post(title: String, body: String, level: NotificationLevel) {
        center.getNotificationSettings { settings in
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            DispatchQueue.main.async {
                self.isAuthorized = allowed
                if allowed {
                    self.deliver(title: title, body: body, level: level)
                } else if level != .info {
                    // Không có quyền: vẫn hiện cảnh báo quan trọng bằng thẻ trong app.
                    ToastPanel.shared.show(title: title, body: body, level: level)
                }
            }
        }
    }

    private func deliver(title: String, body: String, level: NotificationLevel) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = level == .info ? nil : .default
        content.interruptionLevel = level == .critical ? .timeSensitive : (level == .warning ? .active : .passive)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                appLog("🔔 Notifications: gửi lỗi: \(error.localizedDescription)")
                DispatchQueue.main.async { ToastPanel.shared.show(title: title, body: body, level: level) }
            }
        }
    }

    /// UMac là app menu bar: khi bảng đang mở, macOS coi app ở "foreground" và mặc định
    /// nuốt thông báo. Vẫn hiện banner (và âm thanh nếu có).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

// MARK: - Fallback toast (khi không có quyền thông báo)

@MainActor
final class ToastPanel {
    static let shared = ToastPanel()

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(title: String, body: String, level: NotificationLevel) {
        let size = NSSize(width: 340, height: 74)
        let panel = self.panel ?? makePanel(size: size)
        self.panel = panel
        panel.contentView = NSHostingView(rootView: ToastView(title: title, message: body, level: level))

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 14, y: frame.maxY - size.height - 10))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 1 }

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (level == .critical ? 8 : 5), execute: work)
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 }) {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        return panel
    }
}

private struct ToastView: View {
    let title: String
    let message: String
    let level: NotificationLevel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 340, height: 74, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(level == .critical ? Color.red.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
