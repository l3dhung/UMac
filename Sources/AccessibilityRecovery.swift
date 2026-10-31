import Foundation
import ApplicationServices
import Security

/// Tự khôi phục quyền Accessibility sau khi app được cập nhật.
///
/// Vì sao cần: bản phát hành ký ad-hoc có Designated Requirement chỉ là `cdhash`,
/// nên mỗi lần update macOS coi là app khác và vô hiệu hoá quyền đã cấp. Entry cũ
/// vẫn nằm trong System Settings (trông như đang bật) nhưng không có tác dụng;
/// người dùng thường phải xoá app khỏi danh sách rồi thêm lại mới được.
///
/// Cách xử lý: khi chưa có quyền, reset entry TCC cũ (nếu có) **một lần cho mỗi
/// bản build** (phiên bản + cdhash) rồi gọi prompt hệ thống. Người dùng chỉ cần bật
/// switch, không phải xoá/thêm thủ công. Dùng cdhash thay vì chỉ số phiên bản vì
/// đổi chữ ký mà giữ nguyên phiên bản (ad-hoc → chứng chỉ cố định) cũng làm entry cũ mất tác dụng.
@MainActor
enum AccessibilityRecovery {
    private static let lastResetVersionKey = "ax_recovery_version"

    static func handleLaunch() {
        if AXIsProcessTrusted() { return }

        let defaults = UserDefaults.standard
        let version = UpdateManager.currentVersion + "+" + (codeHash() ?? "unsigned")
        guard defaults.string(forKey: lastResetVersionKey) != version else { return }

        resetAccessibilityPermission()
        defaults.set(version, forKey: lastResetVersionKey)

        // Đợi TCC xoá xong rồi mới hỏi lại, tránh prompt bị nuốt.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    /// cdhash của binary đang chạy — đổi mỗi khi build/ký lại.
    private static func codeHash() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, [], &info) == errSecSuccess,
              let hash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { return nil }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func resetAccessibilityPermission() {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            appLog("🔐 AccessibilityRecovery: reset quyền Accessibility cho \(bundleID) (mã \(process.terminationStatus))")
        } catch {
            appLog("⚠️ AccessibilityRecovery: không reset được quyền: \(error.localizedDescription)")
        }
    }
}
