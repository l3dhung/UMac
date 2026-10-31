import Foundation

/// Hiện thông báo hệ thống qua `osascript display notification`.
///
/// Không dùng UserNotifications.framework vì app ký self-signed/ad-hoc thường không
/// được Notification Center cấp quyền ổn định. Nội dung truyền qua argv (không qua shell)
/// nên dấu nháy trong tiêu đề/nội dung không phá được lệnh.
func postUserNotification(title: String, body: String, sound: String? = nil) {
    func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    var script = "display notification \(quoted(body)) with title \(quoted(title))"
    if let sound {
        script += " sound name \(quoted(sound))"
    }

    DispatchQueue.global(qos: .utility).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
        process.waitUntilExit()
    }
}
