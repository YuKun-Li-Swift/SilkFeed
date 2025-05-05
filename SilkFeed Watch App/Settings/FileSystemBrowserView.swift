import SwiftUI

struct File: Identifiable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    let size: Int64 // 文件大小
    let path: URL
}

extension File: Hashable {}

struct FileBrowserView: View {
    let currentDirectory: URL
    let isTopLevelSandbox: Bool
    @State private var files: [File] = []
    @State private var errorMessage: String?
    @State private var totalSize: Int64 = 0
    @State private var selectedFile: File? = nil

    var body: some View {
        List(files) { file in
            Button(action: {
                selectedFile = file
            }) {
                HStack {
                    Text(file.isDirectory ? "📁" : "📄")
                    Text(file.name)
                    Spacer()
                    Text(formatFileSize(file.size))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("总大小: \(formatFileSize(totalSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Capsule(style: .continuous).fill(Material.ultraThin))
                    Spacer(minLength: 0)
                }
            }
        }
        .navigationDestination(item: $selectedFile, destination: { file in
            if file.isDirectory {
                FileBrowserView(directory: file.path)
            } else {
                FileDetailView(file: file)
            }
        })
        .onAppear {
            loadFiles()
        }
        .alert("错误", isPresented: $errorMessage.isNonNil()) {
            Button("确定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    var navigationTitle: String {
        if isTopLevelSandbox {
            "根目录"
        } else {
            currentDirectory.lastPathComponent.isEmpty ? "根目录" : currentDirectory.lastPathComponent
        }
    }

    init(directory: URL? = nil, isTopLevelSandbox: Bool = false) {
        self.currentDirectory = directory ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.deletingLastPathComponent()
        self.isTopLevelSandbox = isTopLevelSandbox
    }

    private func loadFiles() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: .skipsHiddenFiles)
            files = try fileURLs.map { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let size: Int64 = try {
                    if isDirectory {
                        return calculateFolderSize(for: url)
                    } else {
                        guard let fileSize: Int = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                            throw CalculateFileSizeError.failedToQueryFileSize
                        }
                        return Int64(fileSize)
                    }
                }()
                return File(name: url.lastPathComponent, isDirectory: isDirectory, size: size, path: url)
            }
            totalSize = files.reduce(0) { $0 + $1.size }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    enum CalculateFileSizeError: Error, LocalizedError {
        case failedToQueryFileSize
        var errorDescription: String? {
            switch self {
            case .failedToQueryFileSize:
                "获取文件大小失败"
            }
        }
    }

    private func calculateFolderSize(for folderURL: URL) -> Int64 {
        var folderSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
            for case let fileURL as URL in enumerator {
                folderSize += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0)
            }
        }
        return folderSize
    }

    private func formatFileSize(_ size: Int64) -> String {
        if size >= 1024 * 1024 {
            return String(format: "%.2f MB", Double(size) / (1024 * 1024))
        } else {
            return "\(size / 1024) KB"
        }
    }
}

struct FileDetailView: View {
    let file: File

    var body: some View {
        VStack(spacing: 20) {
            Text("文件名: \(file.name)")
            Text("文件大小: \(formatFileSize(file.size))")
            Text("路径: \(file.path.path)")
        }
        .navigationTitle("文件详情")
        .padding()
    }

    private func formatFileSize(_ size: Int64) -> String {
        if size >= 1024 * 1024 {
            return String(format: "%.2f MB", Double(size) / (1024 * 1024))
        } else {
            return "\(size / 1024) KB"
        }
    }
}

extension Binding where Value == String? {
    func isNonNil() -> Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { if !$0 { self.wrappedValue = nil } }
        )
    }
}
