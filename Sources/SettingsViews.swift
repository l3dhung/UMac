import AppKit
import SwiftUI

// MARK: - General Settings (Mở cùng máy, Thông báo)

struct GeneralSettingsCard: View {
    @ObservedObject var launchAtLogin: LaunchAtLogin = .shared
    @ObservedObject var notifier: UMacNotifier = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mở cùng máy")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("Tự chạy UMac khi đăng nhập macOS")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            if launchAtLogin.needsApproval {
                notice(icon: "exclamationmark.circle.fill", color: .orange,
                       text: "macOS đang chặn UMac trong Mục đăng nhập.",
                       button: "Mở Cài đặt") { launchAtLogin.openLoginItemsSettings() }
            }
            if let error = launchAtLogin.errorMessage {
                notice(icon: "xmark.octagon.fill", color: .red, text: error, button: nil) {}
            }

            Divider().opacity(0.4)

            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Thông báo")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(notifier.isAuthorized
                         ? "Hiện với tên UMac. Tin thường không phát âm thanh."
                         : "Chưa được phép: chỉ cảnh báo quan trọng hiện ở góc màn hình.")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !notifier.isAuthorized {
                    Button("Cho phép") { openNotificationSettings() }
                        .font(.system(size: 8.5, weight: .semibold))
                        .controlSize(.mini)
                }
                Button("Gửi thử") {
                    postUserNotification(title: "UMac", body: "Thông báo đang hoạt động bình thường.", level: .warning)
                }
                .font(.system(size: 8.5, weight: .semibold))
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .onAppear { launchAtLogin.refresh() }
    }

    private func notice(icon: String, color: Color, text: String, button: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let button {
                Button(button, action: action)
                    .font(.system(size: 8, weight: .semibold))
                    .controlSize(.mini)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.08)))
    }

    private func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? "com.l3dhung.umac"
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - AltTab trigger

struct AltTabTriggerPicker: View {
    @ObservedObject var store: ShortcutStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Phím mở:")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
                ForEach(AltTabTrigger.allCases) { trigger in
                    let selected = store.altTabTrigger == trigger
                    Button {
                        store.altTabTrigger = trigger
                    } label: {
                        Text(trigger.title)
                            .font(.system(size: 8.5, weight: selected ? .bold : .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.06)))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            Text(store.altTabTrigger.hint + " Trong bảng: \(store.altTabTrigger.primaryModifierSymbol)~ lùi lại, W đóng cửa sổ, Q thoát app.")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Shortcut grids

struct WindowShortcutsGrid: View {
    private let actions = ShortcutAction.allCases.filter(\.isWindowAction)

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 5) {
            ForEach(actions) { action in
                ShortcutRecorderView(action: action)
            }
        }
    }
}

struct ShortcutsFooter: View {
    @ObservedObject var store: ShortcutStore = .shared

    var body: some View {
        HStack(spacing: 6) {
            if let message = store.message {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accentColor)
                Text(message)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Bấm ô phím tắt rồi nhấn tổ hợp mới")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
                    .help("Esc để huỷ, Delete để xoá phím tắt")
            }
            Spacer()
            Button("Khôi phục mặc định") { store.resetToDefaults() }
                .font(.system(size: 8.5, weight: .semibold))
                .controlSize(.mini)
        }
        .padding(.horizontal, 4)
    }
}
