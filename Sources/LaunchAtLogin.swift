import Foundation
import ServiceManagement

/// Bật/tắt "Mở cùng máy" bằng `SMAppService.mainApp` (macOS 13+). macOS tự quản lý mục
/// trong Cài đặt hệ thống → Chung → Mục đăng nhập; app không cần helper riêng.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled = false
    /// Người dùng (hoặc quản trị) đang chặn trong Mục đăng nhập — cần bật tay.
    @Published private(set) var needsApproval = false
    @Published private(set) var errorMessage: String?

    private init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            appLog("🚀 LaunchAtLogin: \(enabled ? "bật" : "tắt")")
        } catch {
            errorMessage = "Không đổi được: \(error.localizedDescription)"
            appLog("⚠️ LaunchAtLogin: \(error.localizedDescription)")
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
