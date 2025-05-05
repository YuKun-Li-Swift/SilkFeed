import SwiftUI

struct URLCacheUsageView: View {
    @State private var memoryUsageMB: Double = 0.0
    @State private var diskUsageMB: Double = 0.0
    
    var body: some View {
        
            List {
                Section(header: Text("URL Cache 使用情况")) {
                    HStack {
                        Text("内存缓存使用")
                        Spacer()
                        Text(String(format: "%.2f MB", memoryUsageMB))
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("磁盘缓存使用")
                        Spacer()
                        Text(String(format: "%.2f MB", diskUsageMB))
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: refreshCacheUsage) {
                    Text("刷新缓存信息")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.blue)
            }
            .navigationTitle("缓存使用")
            .onAppear {
                refreshCacheUsage()
            }
        
    }
    
    private func refreshCacheUsage() {
        let urlCache = URLCache.shared
        memoryUsageMB = Double(urlCache.currentMemoryUsage) / (1024.0 * 1024.0)
        diskUsageMB = Double(urlCache.currentDiskUsage) / (1024.0 * 1024.0)
    }
}
