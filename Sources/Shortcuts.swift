import AppKit
import CoreGraphics
import SwiftUI

// MARK: - Key Combo

/// Một tổ hợp phím: mã phím vật lý + các phím bổ trợ ⌃⌥⇧⌘.
struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt64

    static let modifierMask: UInt64 = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
        | CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue

    init(keyCode: UInt16, modifiers: UInt64) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.modifierMask
    }

    init(keyCode: UInt16, _ flags: CGEventFlags) {
        self.init(keyCode: keyCode, modifiers: flags.rawValue)
    }

    /// Khoá tra cứu nhanh trong event tap.
    var lookupKey: UInt64 { UInt64(keyCode) << 32 | modifiers }

    var hasCommandLikeModifier: Bool {
        modifiers & (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskControl.rawValue) != 0
    }

    /// Hiển thị theo thứ tự chuẩn của Apple: ⌃⌥⇧⌘ + phím.
    var displayString: String {
        var text = ""
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { text += "⌃" }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { text += "⌥" }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { text += "⇧" }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { text += "⌘" }
        return text + KeyCombo.keyName(keyCode)
    }

    static func keyName(_ code: UInt16) -> String {
        if let name = specialKeys[code] { return name }
        if let char = ansiKeys[code] { return char }
        return "#\(code)"
    }

    private static let specialKeys: [UInt16: String] = [
        123: "←", 124: "→", 125: "↓", 126: "↑", 36: "↩", 76: "⌤", 48: "⇥", 49: "Space",
        51: "⌫", 117: "⌦", 53: "⎋", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// Vị trí phím ANSI (US) — đúng cho các bố cục Latin phổ biến, kể cả gõ tiếng Việt.
    private static let ansiKeys: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K",
        37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
        9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`",
    ]

    static let functionKeyCodes: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
}

// MARK: - Actions

enum ShortcutAction: String, CaseIterable, Identifiable {
    case snapLeft, snapRight, snapTop, snapBottom, maximize, center
    case nextDisplay, previousDisplay
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snapLeft: return "Nửa trái"
        case .snapRight: return "Nửa phải"
        case .snapTop: return "Nửa trên"
        case .snapBottom: return "Nửa dưới"
        case .maximize: return "Toàn màn hình"
        case .center: return "Căn giữa"
        case .nextDisplay: return "Màn hình kế"
        case .previousDisplay: return "Màn hình trước"
        case .clipboard: return "Mở lịch sử Clipboard"
        }
    }

    var isWindowAction: Bool { self != .clipboard }

    var defaultCombo: KeyCombo? {
        let ctrlOpt = CGEventFlags([.maskControl, .maskAlternate])
        let ctrlOptCmd = CGEventFlags([.maskControl, .maskAlternate, .maskCommand])
        switch self {
        case .snapLeft: return KeyCombo(keyCode: 123, ctrlOpt)
        case .snapRight: return KeyCombo(keyCode: 124, ctrlOpt)
        case .maximize: return KeyCombo(keyCode: 126, ctrlOpt)
        case .center: return KeyCombo(keyCode: 125, ctrlOpt)
        case .snapTop, .snapBottom: return nil
        // ⌃⌥⌘ như Rectangle: ⌥⌘←/→ là phím chuyển tab của Safari/Chrome.
        case .nextDisplay: return KeyCombo(keyCode: 124, ctrlOptCmd)
        case .previousDisplay: return KeyCombo(keyCode: 123, ctrlOptCmd)
        // ⌘⇧C như Maccy; ⌘⇧V để dành cho "Dán và khớp kiểu" của macOS.
        case .clipboard: return KeyCombo(keyCode: 8, [.maskCommand, .maskShift])
        }
    }

    @MainActor
    func perform() {
        switch self {
        case .snapLeft: WindowSnapManager.shared.snapActiveWindow(.leftHalf)
        case .snapRight: WindowSnapManager.shared.snapActiveWindow(.rightHalf)
        case .snapTop: WindowSnapManager.shared.snapActiveWindow(.topHalf)
        case .snapBottom: WindowSnapManager.shared.snapActiveWindow(.bottomHalf)
        case .maximize: WindowSnapManager.shared.snapActiveWindow(.maximize)
        case .center: WindowSnapManager.shared.snapActiveWindow(.center)
        case .nextDisplay: WindowSnapManager.shared.moveActiveWindowToDisplay(isNext: true)
        case .previousDisplay: WindowSnapManager.shared.moveActiveWindowToDisplay(isNext: false)
        case .clipboard: ClipboardManager.shared.toggleHUD()
        }
    }
}

/// Phím mở bảng chuyển cửa sổ.
enum AltTabTrigger: String, CaseIterable, Identifiable {
    case commandAndOption, optionOnly, commandOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandAndOption: return "⌘Tab + ⌥Tab"
        case .optionOnly: return "Chỉ ⌥Tab"
        case .commandOnly: return "Chỉ ⌘Tab"
        }
    }

    var hint: String {
        switch self {
        case .commandAndOption: return "Thay hẳn bộ chuyển app của macOS."
        case .optionOnly: return "Giữ nguyên ⌘Tab của macOS, dùng ⌥Tab cho UMac."
        case .commandOnly: return "Chỉ thay ⌘Tab."
        }
    }

    var primaryModifierSymbol: String { self == .optionOnly ? "⌥" : "⌘" }
}

// MARK: - Event tap globals (chỉ đọc/ghi trên main thread — tap chạy trên main run loop)

/// lookupKey → action. Được ShortcutStore cập nhật mỗi khi người dùng đổi phím.
var gShortcutTable: [UInt64: ShortcutAction] = [:]
var gIsSnapEnabled: Bool = true
var gAltTabTrigger: AltTabTrigger = .commandAndOption
/// Đang ghi phím tắt: event tap chuyển phím bấm cho ShortcutStore thay vì xử lý.
var gIsRecordingShortcut: Bool = false

// MARK: - Store

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published private(set) var bindings: [ShortcutAction: KeyCombo] = [:]
    @Published private(set) var recordingAction: ShortcutAction?
    @Published var message: String?
    @Published var altTabTrigger: AltTabTrigger {
        didSet {
            UserDefaults.standard.set(altTabTrigger.rawValue, forKey: "alttab_trigger")
            gAltTabTrigger = altTabTrigger
        }
    }

    private static let defaultsPrefix = "shortcut_"

    private init() {
        altTabTrigger = AltTabTrigger(rawValue: UserDefaults.standard.string(forKey: "alttab_trigger") ?? "") ?? .commandAndOption
        gAltTabTrigger = altTabTrigger
        for action in ShortcutAction.allCases {
            let key = Self.defaultsPrefix + action.rawValue
            if let data = UserDefaults.standard.data(forKey: key) {
                // Dữ liệu rỗng = người dùng đã chủ động xoá phím tắt này.
                if let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
                    bindings[action] = combo
                }
            } else if let combo = action.defaultCombo {
                bindings[action] = combo
            }
        }
        publishTable()
    }

    func combo(for action: ShortcutAction) -> KeyCombo? { bindings[action] }

    // MARK: Recording

    func beginRecording(_ action: ShortcutAction) {
        message = nil
        recordingAction = action
        gIsRecordingShortcut = true
    }

    func cancelRecording() {
        recordingAction = nil
        gIsRecordingShortcut = false
    }

    /// Event tap gọi khi đang ghi phím.
    func handleRecorded(keyCode: UInt16, flags: CGEventFlags) {
        guard let action = recordingAction else { return }
        let combo = KeyCombo(keyCode: keyCode, flags)

        if combo.modifiers == 0 && keyCode == 53 { // Esc
            cancelRecording()
            return
        }
        if combo.modifiers == 0 && (keyCode == 51 || keyCode == 117) { // ⌫ / ⌦: xoá
            set(nil, for: action)
            cancelRecording()
            return
        }
        guard combo.hasCommandLikeModifier || KeyCombo.functionKeyCodes.contains(keyCode) else {
            message = "Cần có ít nhất một phím ⌘, ⌥ hoặc ⌃ (hoặc dùng phím F1–F12)."
            return
        }

        if let other = bindings.first(where: { $0.key != action && $0.value == combo })?.key {
            set(nil, for: other)
            message = "Đã gỡ \(combo.displayString) khỏi “\(other.title)”."
        }
        set(combo, for: action)
        cancelRecording()
    }

    // MARK: Editing

    func resetToDefaults() {
        for action in ShortcutAction.allCases {
            UserDefaults.standard.removeObject(forKey: Self.defaultsPrefix + action.rawValue)
            bindings[action] = action.defaultCombo
        }
        altTabTrigger = .commandAndOption
        message = "Đã khôi phục phím tắt mặc định."
        publishTable()
    }

    private func set(_ combo: KeyCombo?, for action: ShortcutAction) {
        bindings[action] = combo
        let data = combo.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        UserDefaults.standard.set(data, forKey: Self.defaultsPrefix + action.rawValue)
        publishTable()
    }

    private func publishTable() {
        var table: [UInt64: ShortcutAction] = [:]
        for (action, combo) in bindings {
            table[combo.lookupKey] = action
        }
        gShortcutTable = table
    }
}

// MARK: - Recorder View

/// Ô hiển thị/ghi phím tắt: bấm để ghi, ⎋ huỷ, ⌫ xoá.
struct ShortcutRecorderView: View {
    let action: ShortcutAction
    @ObservedObject var store: ShortcutStore = .shared

    private var isRecording: Bool { store.recordingAction == action }

    var body: some View {
        HStack(spacing: 6) {
            Text(action.title)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Button {
                isRecording ? store.cancelRecording() : store.beginRecording(action)
            } label: {
                Text(label)
                    .font(.system(size: 9.5, weight: .bold, design: store.combo(for: action) == nil || isRecording ? .default : .monospaced))
                    .foregroundStyle(isRecording ? Color.accentColor : (store.combo(for: action) == nil ? Color.secondary : Color.primary))
                    .lineLimit(1)
                    .frame(minWidth: 58)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isRecording ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Bấm rồi nhấn tổ hợp phím mới. ⎋ để huỷ, ⌫ để xoá.")
        }
    }

    private var label: String {
        if isRecording { return "Nhấn phím…" }
        return store.combo(for: action)?.displayString ?? "Chưa gán"
    }
}
