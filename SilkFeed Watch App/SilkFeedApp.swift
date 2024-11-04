//
//  SilkFeedApp.swift
//  SilkFeed Watch App
//
//  Created by Yukun Li on 2024/11/3.
//

import SwiftUI
import SwiftData

@main
struct SilkFeed_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [RSSSource.self,RSSCacheEntry.self,RSSCachedIamge.self])
    }
}
