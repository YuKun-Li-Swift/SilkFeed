//
//  SettingsPageSwitcher.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/12/1.
//

import SwiftUI

struct SettingsPageSwitcher: View {
    @State
    private var pushURLCachePage = false
    @State
    private var pushFileBrowserPage = false
    @State
    private var pushCleanerPage = false
    var body: some View {
        List {
            Button("文件存储空间占用") {
                pushFileBrowserPage = true
            }
            Button("清理文件存储空间") {
                pushCleanerPage = true
            }
            Button("URL缓存空间占用") {
                pushURLCachePage = true
            }
        }
        .navigationTitle("空间占用")
        .navigationDestination(isPresented: $pushURLCachePage, destination: {
            URLCacheUsageView()
        })
        .navigationDestination(isPresented: $pushFileBrowserPage, destination: {
            FileBrowserView(isTopLevelSandbox:true)
        })
        .navigationDestination(isPresented: $pushCleanerPage, destination: {
            CleanerPage()
        })
    }
}

#Preview {
    SettingsPageSwitcher()
}
