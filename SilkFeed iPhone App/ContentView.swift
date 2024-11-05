//
//  ContentView.swift
//  SilkFeed iPhone App
//
//  Created by Yukun Li on 2024/11/5.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "arrow.down.applewatch")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("请在Apple Watch上打开配套App以使用完整功能")
                .bold()
                .padding(.vertical)
            Text("支持watchOS 11.0及以上系统的Apple Watch")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .scenePadding(.horizontal)
        .modifier(MakeNetworkingPermission())
    }
}

//在watchOS 11.1，仅Apple Watch端app，在通过TestFlight安装的时候，仍然会遇到无法正常联网的情况。因此需要在配套的手机端app做联网请求。
struct MakeNetworkingPermission: ViewModifier {
    func body(content: Content) -> some View {
        content
            .task {
                do {
                    try await URLSession.shared.data(from: URL(string: "https://www.baidu.com/")!)
                } catch {
                    print("网络请求失败，应该已经向用户弹出了联网权限弹窗")
                }
            }
    }
}

#Preview {
    ContentView()
}
