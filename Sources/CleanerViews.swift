import SwiftUI
import AppKit

// MARK: - TAB 3: Cleaner (Dọn rác, Gỡ app, File lớn)

struct CleanerTabView: View {
    @ObservedObject var cleaner: CleanerManager = CleanerManager.shared

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                sectionButton(index: 0, title: "Rác hệ thống", icon: "sparkles")
                sectionButton(index: 1, title: "Gỡ ứng dụng", icon: "trash.square")
                sectionButton(index: 2, title: "File lớn", icon: "doc.badge.ellipsis")
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            .padding(.horizontal, 12)
            .padding(.top, 4)

            if let message = cleaner.resultMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.system(size: 8.5))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Mở Thùng rác") { cleaner.openTrash() }
                        .font(.system(size: 8.5, weight: .semibold))
                        .controlSize(.mini)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
                .padding(.horizontal, 12)
            }

            Group {
                switch cleaner.selectedSection {
                case 1: AppUninstallerSection(cleaner: cleaner)
                case 2: LargeFilesSection(cleaner: cleaner)
                default: JunkSection(cleaner: cleaner)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sectionButton(index: Int, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                cleaner.selectedSection = index
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 8.5, weight: cleaner.selectedSection == index ? .bold : .medium))
            }
            .padding(.vertical, 4.5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(cleaner.selectedSection == index ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(cleaner.selectedSection == index ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Pieces

private struct CleanerCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.035)))
    }
}

private struct CheckRow: View {
    let item: CleanupItem
    var showReveal: Bool = true
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 10))
                    .foregroundStyle(item.isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let note = item.note {
                    Text(note)
                        .font(.system(size: 7.5))
                        .foregroundStyle(note == "Đang chạy" ? Color.orange : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer(minLength: 4)

            Text(CleanerManager.format(item.size))
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            if showReveal {
                Button {
                    CleanerManager.shared.reveal(item.url)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hiện trong Finder")
            }
        }
    }
}

private struct ActionBar: View {
    let title: String
    let detail: String
    let isBusy: Bool
    let isDisabled: Bool
    let confirmMessage: String
    let action: () -> Void

    @State private var isConfirming = false

    var body: some View {
        HStack(spacing: 8) {
            Text(detail)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if isBusy {
                ProgressView().controlSize(.small)
            }
            Button(title) { isConfirming = true }
                .font(.system(size: 9.5, weight: .bold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isDisabled || isBusy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .alert("Chuyển vào Thùng rác?", isPresented: $isConfirming) {
            Button("Huỷ", role: .cancel) {}
            Button(title, role: .destructive, action: action)
        } message: {
            Text(confirmMessage)
        }
    }
}

private struct ScanPrompt: View {
    let icon: String
    let title: String
    let detail: String
    let isScanning: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Text(detail)
                .font(.system(size: 8.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            if isScanning {
                ProgressView().controlSize(.small).padding(.top, 4)
            } else {
                Button(buttonTitle, action: action)
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Junk Section

private struct JunkSection: View {
    @ObservedObject var cleaner: CleanerManager

    var body: some View {
        if !cleaner.hasScannedJunk {
            ScanPrompt(
                icon: "sparkles",
                title: "Quét rác hệ thống",
                detail: "Tìm bộ nhớ đệm, nhật ký, cache Xcode và công cụ lập trình. Không đụng file hệ thống hay dữ liệu của Apple.",
                isScanning: cleaner.isScanningJunk,
                buttonTitle: "Quét ngay",
                action: cleaner.scanJunk
            )
        } else {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        if cleaner.junkCategories.isEmpty {
                            Text("Không tìm thấy rác đáng kể 🎉")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.top, 30)
                        }
                        ForEach(cleaner.junkCategories) { category in
                            categoryCard(category)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }

                Divider().padding(.horizontal, 10)

                ActionBar(
                    title: "Dọn dẹp",
                    detail: "Đã chọn \(CleanerManager.format(cleaner.junkSelectedSize))",
                    isBusy: cleaner.isTrashing || cleaner.isScanningJunk,
                    isDisabled: cleaner.junkSelectedSize == 0,
                    confirmMessage: "\(CleanerManager.format(cleaner.junkSelectedSize)) sẽ được chuyển vào Thùng rác. Bạn vẫn khôi phục được cho tới khi dọn sạch Thùng rác.",
                    action: cleaner.cleanSelectedJunk
                )
            }
        }
    }

    private func categoryCard(_ category: JunkCategory) -> some View {
        let allSelected = category.items.allSatisfy(\.isSelected)
        return CleanerCard {
            HStack(spacing: 8) {
                Button {
                    cleaner.setCategorySelected(category.id, !allSelected)
                } label: {
                    Image(systemName: allSelected ? "checkmark.square.fill" : (category.selectedSize > 0 ? "minus.square.fill" : "square"))
                        .font(.system(size: 11))
                        .foregroundStyle(category.selectedSize > 0 ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.system(size: 10, weight: .semibold))
                    Text(category.detail)
                        .font(.system(size: 7.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(CleanerManager.format(category.totalSize))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        cleaner.toggleCategoryExpanded(category.id)
                    }
                } label: {
                    Image(systemName: category.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if category.isExpanded {
                Divider().opacity(0.4)
                ForEach(category.items) { item in
                    CheckRow(item: item) {
                        cleaner.toggleJunkItem(categoryID: category.id, itemID: item.id)
                    }
                }
            }
        }
    }
}

// MARK: - App Uninstaller Section

private struct AppUninstallerSection: View {
    @ObservedObject var cleaner: CleanerManager

    var body: some View {
        Group {
            if let app = cleaner.selectedApp {
                appDetail(app)
            } else {
                appList
            }
        }
        .onAppear {
            if cleaner.apps.isEmpty { cleaner.loadApps() }
        }
    }

    private var appList: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                TextField("Tìm ứng dụng…", text: $cleaner.appSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                if cleaner.isLoadingApps {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
            .padding(.horizontal, 12)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(cleaner.filteredApps) { app in
                        Button {
                            cleaner.selectApp(app)
                        } label: {
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(app.name)
                                        .font(.system(size: 10, weight: .medium))
                                    Text(app.bundleID)
                                        .font(.system(size: 7.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private func appDetail(_ app: InstalledApp) -> some View {
        let leftoverSize = cleaner.appLeftovers.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.size }
        let total = cleaner.appBundleSize + leftoverSize

        return VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    CleanerCard {
                        HStack(spacing: 8) {
                            Button {
                                cleaner.selectApp(nil)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.plain)

                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                .resizable()
                                .frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                    .font(.system(size: 11, weight: .bold))
                                Text(app.url.path)
                                    .font(.system(size: 7.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(CleanerManager.format(cleaner.appBundleSize))
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        if cleaner.isSelectedAppRunning {
                            Label("Ứng dụng đang chạy — hãy thoát trước khi gỡ", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 8.5))
                                .foregroundStyle(.orange)
                        }
                    }

                    CleanerCard {
                        HStack {
                            Text("FILE CÒN SÓT LẠI")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if cleaner.isScanningLeftovers {
                                ProgressView().controlSize(.mini)
                            }
                        }
                        if !cleaner.isScanningLeftovers && cleaner.appLeftovers.isEmpty {
                            Text("Không tìm thấy dữ liệu sót lại trong ~/Library.")
                                .font(.system(size: 8.5))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(cleaner.appLeftovers) { item in
                            CheckRow(item: item) { cleaner.toggleLeftover(item.id) }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider().padding(.horizontal, 10)

            ActionBar(
                title: "Gỡ cài đặt",
                detail: "Tổng \(CleanerManager.format(total))",
                isBusy: cleaner.isTrashing || cleaner.isScanningLeftovers,
                isDisabled: cleaner.isSelectedAppRunning,
                confirmMessage: "\(app.name) và \(cleaner.appLeftovers.filter(\.isSelected).count) mục dữ liệu (\(CleanerManager.format(total))) sẽ được chuyển vào Thùng rác.",
                action: cleaner.uninstallSelectedApp
            )
        }
    }
}

// MARK: - Large Files Section

private struct LargeFilesSection: View {
    @ObservedObject var cleaner: CleanerManager

    private let thresholds = [100, 500, 1000, 5000]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Text("Lớn hơn:")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(thresholds, id: \.self) { mb in
                    Button {
                        cleaner.largeFileThresholdMB = mb
                        if cleaner.hasScannedLarge { cleaner.scanLargeFiles() }
                    } label: {
                        Text(mb >= 1000 ? "\(mb / 1000) GB" : "\(mb) MB")
                            .font(.system(size: 8.5, weight: cleaner.largeFileThresholdMB == mb ? .bold : .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(cleaner.largeFileThresholdMB == mb ? Color.accentColor : Color.primary.opacity(0.06)))
                            .foregroundStyle(cleaner.largeFileThresholdMB == mb ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if cleaner.hasScannedLarge {
                    Button {
                        cleaner.scanLargeFiles()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(cleaner.isScanningLarge)
                    .help("Quét lại")
                }
            }
            .padding(.horizontal, 12)

            if !cleaner.hasScannedLarge {
                ScanPrompt(
                    icon: "doc.badge.ellipsis",
                    title: "Tìm file lớn trong thư mục người dùng",
                    detail: "Dùng chỉ mục Spotlight nên quét gần như tức thì. Không có file nào được chọn sẵn — bạn tự quyết định.",
                    isScanning: cleaner.isScanningLarge,
                    buttonTitle: "Tìm file",
                    action: cleaner.scanLargeFiles
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        if cleaner.isScanningLarge {
                            ProgressView().controlSize(.small).padding(.top, 20)
                        } else if cleaner.largeFiles.isEmpty {
                            Text("Không có file nào vượt ngưỡng.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.top, 30)
                        }
                        ForEach(cleaner.largeFiles) { item in
                            CleanerCard {
                                CheckRow(item: item) { cleaner.toggleLargeFile(item.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }

                Divider().padding(.horizontal, 10)

                ActionBar(
                    title: "Chuyển vào Thùng rác",
                    detail: "Đã chọn \(CleanerManager.format(cleaner.largeSelectedSize))",
                    isBusy: cleaner.isTrashing,
                    isDisabled: cleaner.largeSelectedSize == 0,
                    confirmMessage: "\(cleaner.largeFiles.filter(\.isSelected).count) file (\(CleanerManager.format(cleaner.largeSelectedSize))) sẽ được chuyển vào Thùng rác.",
                    action: cleaner.trashSelectedLargeFiles
                )
            }
        }
    }
}
