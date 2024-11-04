//
//  DataModel.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/3.
//

import SwiftUI
import SwiftData

@MainActor
@Model
class RSSSource:Identifiable {
    var id = UUID()
    var name:String
    var creatDate:Date = Date()
    var lastReadingDate:Date? = nil
    var cacheEntries:[RSSCacheEntry] = []
    var url:String
    init(name: String, url: URL) {
        self.name = name
        self.url = url.absoluteString
    }
    func readingOnce() {
        lastReadingDate = .now
    }
    
}

extension Array where Element:RSSSource {
    func generateNewItemName(url:URL) -> String {
        //比如传入https://rsshub.com/36kr/home，得到rsshub-36kr
        guard url.pathComponents.count >= 2 else {
            return "资讯源"+String(self.count+1)
        }
        let component = url.pathComponents[1]
        guard let domain = extractDomainComponent(from: url) else {
            return component
        }
        return domain+"-"+component
    }
}

func extractDomainComponent(from url: URL) -> String? {
    // Create a URL instance from the string
    guard let host = url.host else {
        return nil
    }
    
    // Split the host by "." (e.g., ["www", "ithome", "com"])
    let hostComponents = host.split(separator: ".")
    
    // Typically, the second-to-last part is the main domain
    // Check if the host has enough components and extract the main domain part
    if hostComponents.count >= 2 {
        return String(hostComponents[hostComponents.count - 2])
    } else {
        return nil
    }
}

func handleDelete<T:PersistentModel>(indexSet:IndexSet,items:[T],modelContext:ModelContext) throws {
    // 使用 indexSet 的索引获取元素
    let slice = indexSet.compactMap { items.indices.contains($0) ? items[$0] : nil }
    for source in slice {
        modelContext.delete(source)
    }
    try modelContext.save()
}
@MainActor
@Model
class RSSCacheEntry: Identifiable {
    var id = UUID()
    var cachedDate:Date = Date()
    var cachedXMLString:String
    var cachedImages:[RSSCachedIamge]
    init(cachedXMLString: String) {
        self.cachedXMLString = cachedXMLString
        self.cachedImages = []
    }
}

@MainActor
@Model
class RSSCachedIamge: Identifiable {
    var id = UUID()
    var cachedDate:Date = Date()
    var imageURL:String
    var imageData:Data
    init(imageURL: URL, imageData: Data) {
        self.imageURL = imageURL.absoluteString
        self.imageData = imageData
    }
}
