import Foundation
import AppKit

// MARK: - Cleaner Models

public struct CleanupItem: Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let size: Int64
    public var isSelected: Bool
    /// Ghi chú hiển thị cạnh mục (ví dụ "Đang chạy").
    public var note: String? = nil
    public var modified: Date? = nil
}

public struct JunkCategory: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let detail: String
    public var items: [CleanupItem]
    public var isExpanded: Bool = false

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    public var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
}

public struct InstalledApp: Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let bundleID: String
}

// MARK: - Cleaner Manager (CleanMyMac-style, chỉ quyền user)

/// Dọn rác, gỡ app sạch, tìm file lớn.
/// Nguyên tắc an toàn: mọi thao tác xóa đều CHUYỂN VÀO THÙNG RÁC (khôi phục được),
/// không dùng root, không đụng file hệ thống hay dữ liệu của Apple (com.apple.*).
@MainActor
public class CleanerManager: ObservableObject {
    public static let shared = CleanerManager()

    @Published public var selectedSection: Int = 0

    // Rác hệ thống
    @Published public var junkCategories: [JunkCategory] = []
    @Published public var isScanningJunk: Bool = false
    @Published public var hasScannedJunk: Bool = false

    // Gỡ ứng dụng
    @Published public var apps: [InstalledApp] = []
    @Published public var isLoadingApps: Bool = false
    @Published public var selectedApp: InstalledApp? = nil
    @Published public var appBundleSize: Int64 = 0
    @Published public var appLeftovers: [CleanupItem] = []
    @Published public var isScanningLeftovers: Bool = false
    @Published public var appSearchText: String = ""

    // File lớn
    @Published public var largeFiles: [CleanupItem] = []
    @Published public var isScanningLarge: Bool = false
    @Published public var hasScannedLarge: Bool = false
    @Published public var largeFileThresholdMB: Int = 500 {
        didSet { UserDefaults.standard.set(largeFileThresholdMB, forKey: "cleaner_large_threshold_mb") }
    }

    // Trạng thái chung
    @Published public var isTrashing: Bool = false
    @Published public var resultMessage: String? = nil

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var library: URL { home.appendingPathComponent("Library") }

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "cleaner_large_threshold_mb")
        if saved > 0 { largeFileThresholdMB = saved }
    }

    // MARK: - Junk Scan

    public var junkSelectedSize: Int64 { junkCategories.reduce(0) { $0 + $1.selectedSize } }

    public func scanJunk() {
        guard !isScanningJunk else { return }
        isScanningJunk = true
        resultMessage = nil

        let home = self.home
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))

        Task.detached(priority: .userInitiated) {
            let categories = Self.buildJunkCategories(home: home, runningBundleIDs: running)
            await MainActor.run {
                self.junkCategories = categories
                self.isScanningJunk = false
                self.hasScannedJunk = true
            }
        }
    }

    nonisolated private static func buildJunkCategories(home: URL, runningBundleIDs: Set<String>) -> [JunkCategory] {
        let library = home.appendingPathComponent("Library")
        let ownBundleID = Bundle.main.bundleIdentifier ?? "com.opensource.hypermac"

        func children(of dir: URL, selected: Bool = true, skip: (String) -> Bool = { _ in false }) -> [CleanupItem] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            return names.compactMap { name in
                guard !name.hasPrefix("."), !skip(name) else { return nil }
                let url = dir.appendingPathComponent(name)
                let isRunning = runningBundleIDs.contains(name)
                return makeItem(url, selected: selected && !isRunning, note: isRunning ? "Đang chạy" : nil)
            }
        }

        func single(_ url: URL, name: String? = nil, selected: Bool = true) -> [CleanupItem] {
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            return [makeItem(url, name: name, selected: selected)].compactMap { $0 }
        }

        // Cache của dịch vụ hệ thống Apple không mang tiền tố com.apple. — để yên.
        let appleSystemCaches: Set<String> = [
            "CloudKit", "GeoServices", "FamilyCircle", "PassKit", "SiriTTS", "Metadata",
            "akd", "storeassetd", "ColorSync", "AMSDataMigratorTool", "icloudmailagent",
        ]
        let isAppleOrSelf: (String) -> Bool = {
            $0.hasPrefix("com.apple.") || $0 == ownBundleID || appleSystemCaches.contains($0)
        }

        var categories: [JunkCategory] = [
            JunkCategory(
                id: "caches", title: "Bộ nhớ đệm ứng dụng", icon: "internaldrive",
                detail: "~/Library/Caches — app tự tạo lại khi cần",
                items: children(of: library.appendingPathComponent("Caches"), skip: isAppleOrSelf)
            ),
            JunkCategory(
                id: "logs", title: "Nhật ký & báo cáo lỗi", icon: "doc.text",
                detail: "~/Library/Logs",
                items: children(of: library.appendingPathComponent("Logs"), skip: isAppleOrSelf)
            ),
            JunkCategory(
                id: "xcode", title: "Xcode & Simulator", icon: "hammer",
                detail: "DerivedData, cache Simulator, iOS DeviceSupport — Xcode tự tạo lại",
                items: children(of: library.appendingPathComponent("Developer/Xcode/DerivedData"))
                    + single(library.appendingPathComponent("Developer/CoreSimulator/Caches"), name: "CoreSimulator Caches")
                    + children(of: library.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"))
            ),
            JunkCategory(
                id: "devtools", title: "Cache công cụ lập trình", icon: "terminal",
                detail: "npm, Gradle, ~/.cache (có thể chứa model AI — tải lại sẽ lâu)",
                items: single(home.appendingPathComponent(".npm/_cacache"), name: "npm cache")
                    + single(home.appendingPathComponent(".gradle/caches"), name: "Gradle caches")
                    + children(of: home.appendingPathComponent(".cache"), selected: false)
            ),
        ]

        // Bỏ mục < 1 MB cho gọn, sắp xếp theo dung lượng.
        for i in categories.indices {
            categories[i].items = categories[i].items
                .filter { $0.size >= 1_000_000 }
                .sorted { $0.size > $1.size }
        }
        return categories.filter { !$0.items.isEmpty }
    }

    public func toggleJunkItem(categoryID: String, itemID: URL) {
        guard let c = junkCategories.firstIndex(where: { $0.id == categoryID }),
              let i = junkCategories[c].items.firstIndex(where: { $0.id == itemID }) else { return }
        junkCategories[c].items[i].isSelected.toggle()
    }

    public func setCategorySelected(_ categoryID: String, _ selected: Bool) {
        guard let c = junkCategories.firstIndex(where: { $0.id == categoryID }) else { return }
        for i in junkCategories[c].items.indices {
            junkCategories[c].items[i].isSelected = selected
        }
    }

    public func toggleCategoryExpanded(_ categoryID: String) {
        guard let c = junkCategories.firstIndex(where: { $0.id == categoryID }) else { return }
        junkCategories[c].isExpanded.toggle()
    }

    public func cleanSelectedJunk() {
        let items = junkCategories.flatMap(\.items).filter(\.isSelected)
        moveToTrash(items) { [weak self] in self?.scanJunk() }
    }

    // MARK: - App Uninstaller

    public var filteredApps: [InstalledApp] {
        let query = appSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.lowercased().contains(query) }
    }

    public func loadApps() {
        guard !isLoadingApps else { return }
        isLoadingApps = true
        let home = self.home

        Task.detached(priority: .userInitiated) {
            let ownBundleID = Bundle.main.bundleIdentifier ?? "com.opensource.hypermac"
            let roots = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
            var found: [InstalledApp] = []

            func collect(in dir: URL, depth: Int) {
                let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
                for name in names where !name.hasPrefix(".") {
                    let url = dir.appendingPathComponent(name)
                    if name.hasSuffix(".app") {
                        guard let bundle = Bundle(url: url), let bid = bundle.bundleIdentifier,
                              !bid.hasPrefix("com.apple."), bid != ownBundleID else { continue }
                        let display = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                            ?? (name as NSString).deletingPathExtension
                        found.append(InstalledApp(url: url, name: display, bundleID: bid))
                    } else if depth > 0 {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            collect(in: url, depth: depth - 1)
                        }
                    }
                }
            }
            roots.forEach { collect(in: $0, depth: 1) }
            let sorted = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            await MainActor.run {
                self.apps = sorted
                self.isLoadingApps = false
            }
        }
    }

    public func selectApp(_ app: InstalledApp?) {
        selectedApp = app
        appLeftovers = []
        appBundleSize = 0
        resultMessage = nil
        guard let app else { return }

        isScanningLeftovers = true
        let library = self.library

        Task.detached(priority: .userInitiated) {
            let bundleSize = Self.allocatedSize(of: app.url)
            let leftovers = Self.findLeftovers(for: app, library: library)
            await MainActor.run {
                guard self.selectedApp?.id == app.id else { return }
                self.appBundleSize = bundleSize
                self.appLeftovers = leftovers
                self.isScanningLeftovers = false
            }
        }
    }

    /// Chỉ khớp CHÍNH XÁC theo bundle ID hoặc tên app để tránh xóa nhầm dữ liệu của app khác.
    nonisolated static func findLeftovers(for app: InstalledApp, library: URL) -> [CleanupItem] {
        let bid = app.bundleID
        let appName = (app.url.lastPathComponent as NSString).deletingPathExtension
        var paths = [
            "Application Support/\(bid)",
            "Caches/\(bid)",
            "Preferences/\(bid).plist",
            "Containers/\(bid)",
            "Application Scripts/\(bid)",
            "Saved Application State/\(bid).savedState",
            "Logs/\(bid)",
            "HTTPStorages/\(bid)",
            "HTTPStorages/\(bid).binarycookies",
            "WebKit/\(bid)",
            "Cookies/\(bid).binarycookies",
        ]
        // Tên quá ngắn dễ trùng thư mục của app khác.
        if appName.count >= 4 {
            paths += ["Application Support/\(appName)", "Caches/\(appName)", "Logs/\(appName)"]
        }

        var urls = paths.map { library.appendingPathComponent($0) }

        func matching(in dir: String, _ predicate: (String) -> Bool) -> [URL] {
            let base = library.appendingPathComponent(dir)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
            return names.filter(predicate).map { base.appendingPathComponent($0) }
        }
        urls += matching(in: "Preferences/ByHost") { $0.hasPrefix(bid + ".") }
        urls += matching(in: "LaunchAgents") { $0 == bid + ".plist" || $0.hasPrefix(bid + ".") }
        urls += matching(in: "Group Containers") { $0.hasSuffix("." + bid) }

        var seen = Set<String>()
        return urls.compactMap { url in
            guard FileManager.default.fileExists(atPath: url.path),
                  seen.insert(url.standardizedFileURL.path).inserted else { return nil }
            return makeItem(url, name: url.path.replacingOccurrences(of: library.path + "/", with: ""), selected: true)
        }
        .sorted { $0.size > $1.size }
    }

    public func toggleLeftover(_ itemID: URL) {
        guard let i = appLeftovers.firstIndex(where: { $0.id == itemID }) else { return }
        appLeftovers[i].isSelected.toggle()
    }

    public var isSelectedAppRunning: Bool {
        guard let app = selectedApp else { return false }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == app.bundleID }
    }

    public func uninstallSelectedApp() {
        guard let app = selectedApp else { return }
        guard !isSelectedAppRunning else {
            resultMessage = "Hãy thoát \(app.name) trước khi gỡ."
            return
        }
        let appItem = CleanupItem(url: app.url, name: app.name, size: appBundleSize, isSelected: true)
        moveToTrash([appItem] + appLeftovers.filter(\.isSelected)) { [weak self] in
            guard let self else { return }
            if !FileManager.default.fileExists(atPath: app.url.path) {
                self.apps.removeAll { $0.id == app.id }
                self.selectedApp = nil
                self.appLeftovers = []
            } else {
                self.selectApp(app)
            }
        }
    }

    // MARK: - Large Files

    public func scanLargeFiles() {
        guard !isScanningLarge else { return }
        isScanningLarge = true
        resultMessage = nil
        let home = self.home
        let minBytes = Int64(largeFileThresholdMB) * 1_000_000

        Task.detached(priority: .userInitiated) {
            let files = Self.findLargeFiles(home: home, minBytes: minBytes)
            await MainActor.run {
                self.largeFiles = files
                self.isScanningLarge = false
                self.hasScannedLarge = true
            }
        }
    }

    /// Dùng chỉ mục Spotlight (mdfind) nên gần như tức thì. Bỏ qua ~/Library và thư mục ẩn
    /// (dữ liệu nội bộ của app/hệ thống) cùng file nằm trong gói (thư viện Ảnh, app,
    /// project Final Cut...) vì xóa lẻ sẽ làm hỏng cả gói.
    nonisolated static func findLargeFiles(home: URL, minBytes: Int64) -> [CleanupItem] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", home.path, "kMDItemFSSize >= \(minBytes)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let packageExtensions: Set<String> = [
            "app", "photoslibrary", "musiclibrary", "tvlibrary", "imovielibrary",
            "fcpbundle", "logicx", "band", "xcarchive", "photolibrary", "aplibrary",
            "framework", "xcframework",
        ]
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)

        let homePrefix = home.path + "/"

        let items: [CleanupItem] = lines.compactMap { path in
            guard path.hasPrefix(homePrefix) else { return nil }
            let relative = path.dropFirst(homePrefix.count).split(separator: "/").map(String.init)
            guard relative.first != "Library", !relative.dropLast().contains(where: { $0.hasPrefix(".") }) else { return nil }

            let url = URL(fileURLWithPath: path)
            let insidePackage = relative.dropLast().contains {
                packageExtensions.contains(($0 as NSString).pathExtension.lowercased())
            }
            guard !insidePackage,
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                                                                 .totalFileAllocatedSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
            let size = Int64(values.totalFileAllocatedSize ?? 0)
            guard size >= minBytes else { return nil }
            return CleanupItem(url: url, name: url.lastPathComponent, size: size, isSelected: false,
                               note: url.deletingLastPathComponent().path.replacingOccurrences(of: home.path, with: "~"),
                               modified: values.contentModificationDate)
        }
        return Array(items.sorted { $0.size > $1.size }.prefix(200))
    }

    public func toggleLargeFile(_ itemID: URL) {
        guard let i = largeFiles.firstIndex(where: { $0.id == itemID }) else { return }
        largeFiles[i].isSelected.toggle()
    }

    public var largeSelectedSize: Int64 { largeFiles.filter(\.isSelected).reduce(0) { $0 + $1.size } }

    public func trashSelectedLargeFiles() {
        let items = largeFiles.filter(\.isSelected)
        moveToTrash(items) { [weak self] in
            self?.largeFiles.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        }
    }

    public func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Trash

    /// Chuyển vào Thùng rác qua NSWorkspace (như Finder): hỏi mật khẩu khi file thuộc root,
    /// người dùng có thể khôi phục bằng "Đưa trở lại".
    private func moveToTrash(_ items: [CleanupItem], completion: @escaping () -> Void) {
        guard !items.isEmpty, !isTrashing else { return }
        isTrashing = true
        resultMessage = nil

        NSWorkspace.shared.recycle(items.map(\.url)) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let moved = items.filter { !FileManager.default.fileExists(atPath: $0.url.path) }
                let failed = items.count - moved.count
                let freed = moved.reduce(Int64(0)) { $0 + $1.size }
                var message = "Đã chuyển \(moved.count) mục (\(Self.format(freed))) vào Thùng rác."
                if failed > 0 {
                    message += " \(failed) mục không chuyển được (không có quyền hoặc đang được dùng)."
                }
                if !moved.isEmpty {
                    message += " Dọn sạch Thùng rác để giải phóng dung lượng thật."
                }
                self.resultMessage = message
                self.isTrashing = false
                appLog("🧹 Cleaner: trashed \(moved.count)/\(items.count) items, \(freed) bytes")
                completion()
            }
        }
    }

    public func openTrash() {
        NSWorkspace.shared.open(home.appendingPathComponent(".Trash"))
    }

    // MARK: - Helpers

    nonisolated static func makeItem(_ url: URL, name: String? = nil, selected: Bool, note: String? = nil) -> CleanupItem? {
        let size = allocatedSize(of: url)
        return CleanupItem(url: url, name: name ?? url.lastPathComponent, size: size, isSelected: selected, note: note)
    }

    /// Dung lượng thực chiếm trên ổ (gồm cả file ẩn). Không theo symlink.
    nonisolated static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isRegularFile == true { return Int64(values.totalFileAllocatedSize ?? 0) }

        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let v = try? child.resourceValues(forKeys: keys), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    nonisolated public static func format(_ bytes: Int64) -> String {
        bytes == 0 ? "0 KB" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
