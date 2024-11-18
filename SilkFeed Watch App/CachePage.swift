//
//  CachePage.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/4.
//

import SwiftUI
import SwiftData

//把资讯源的XML下载下来，并且把这个XML里出现所有图片也下载下来，这样之后阅读的时候，要呈现的图片，肯定已经被下载过了。

struct CacheList<V:View>: View {
    let cacheEntries:[RSSCacheEntry]
    var sortedCacheEntries:[RSSCacheEntry] {
        cacheEntries.sorted { u, v in
            u.cachedDate > v.cachedDate
        }
    }
    @ViewBuilder
    let createNewCacheButton:()->(V)
    var deleteAction:([RSSCacheEntry])->()
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var error0:ErrorShip? = nil
    @Binding
    var selectedEntry:RSSCacheEntry?
    var body: some View {
        List {
            createNewCacheButton()
                .listRowBackground(EmptyView())
            ForEach(sortedCacheEntries, content: { cacheEntry in
                Button {
                    selectedEntry = cacheEntry
                } label: {
                    Text(dateDescription(date: cacheEntry.cachedDate)+"的缓存")
                }
            })
            .onDelete(perform: swipeDelete)
        }
        
    }
    private
    func swipeDelete(indexSet:IndexSet) {
        do {
            self.error0 = nil
            let entries:[RSSCacheEntry] = indexSet.compactMap { index in
                guard sortedCacheEntries.indices.contains(index) else { return nil }
                        return sortedCacheEntries[index]
                    }
            deleteAction(entries)
            try modelContext.save()
        } catch {
            
            print("发生错误")
            self.error0 = .init(error: error)
        }
    }
}

struct NewCacheView: View {
    @State
    var rssSource:RSSSource
    let closeMe:()->()
    @State
    private var vm = NewCacheViewModel()
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var step1Model = Step1Model()
    @State
    private var step2Model = Step2Model()
    @State
    private var step3Model = Step3Model()
    @State
    private var step4Model = Step4Model()
    @State
    private var step5Model = Step5Model()
    var body: some View {
        if let downloadedString = step1Model.downloadedString {
            
            if let images = step2Model.parsedURLs {
                
                if let downloadedImages = step3Model.downloadedImages {
                    
                    if let cachedEntry = step4Model.cacheEntry {
                        if step5Model.doneAddToDB {
                            Group {
                                Label("离线缓存成功", systemImage: "checkmark.circle")
                                Button("查看") {
                                    closeMe()
                                }
                            }
                            .transition(.blurReplace.animation(.smooth))
                        } else {
                            
                            //Step5
                            if let error4 = step5Model.error4 {
                                //Step2
                                InlineErrorView(text: "保存到数据库", error: error4)
                                    .transition(.blurReplace.animation(.smooth))
                            } else {
                                Group {
                                    ProgressView()
                                        .controlSize(.extraLarge)
                                    
                                    Text("正在保存到数据库")
                                }
                                .task {
                                    step5Model.step5Task(entry: cachedEntry, rssSurce: rssSource, modelContext: modelContext)
                                }
                                .transition(.blurReplace.animation(.smooth))
                            }
                        }
                    } else {
                        //Step4
                        if let error3 = step4Model.error3 {
                            //Step2
                            InlineErrorView(text: "创建新缓存", error: error3)
                                .transition(.blurReplace.animation(.smooth))
                        } else {
                            Group {
                                ProgressView()
                                    .controlSize(.extraLarge)
                                
                                Text("正在创建新缓存")
                            }
                            .task {
                                step4Model.step4Task(xmlContent: downloadedString, images: downloadedImages)
                            }
                            .transition(.blurReplace.animation(.smooth))
                        }
                    }
                } else {
                    //Step3
                    if let error2 = step3Model.error2 {
                        //Step2
                        InlineErrorView(text: "下载图片失败", error: error2)
                            .transition(.blurReplace.animation(.smooth))
                    } else {
                        Group {
                            DownloadingImagesView()
                        }
                        .task {
                            await step3Model.step3Task(imagesURL: images)
                        }
                        .transition(.blurReplace.animation(.smooth))
                    }
                    
                }
            } else {
                if let error1 = step2Model.error1 {
                    //Step2
                    InlineErrorView(text: "解析资讯源中的图片失败", error: error1)
                        .transition(.blurReplace.animation(.smooth))
                } else {
                    Group {
                        ProgressView()
                            .controlSize(.extraLarge)
                        Text("正在解析资讯源中的图片")
                    }
                    .task {
                        await step2Model.step2Task(rssContent:downloadedString)
                    }
                    .transition(.blurReplace.animation(.smooth))
                }
            }
        } else {
            //Step1
            if let error0 = step1Model.error0 {
                InlineErrorView(text: "加载资讯源的内容失败", error: error0)
                    .transition(.blurReplace.animation(.smooth))
            } else {
                Group {
                    ProgressView()
                        .controlSize(.extraLarge)
                    Text(.now, style: .relative)
                        .contentTransition(.numericText())
                        .animation(.smooth)
                    Text("正在获取资讯源的内容")
                }
                .task {
                    await step1Model.step1Task(url: rssSource.url)
                }
                .transition(.blurReplace.animation(.smooth))
            }
        }
    }
}

@MainActor
@Observable
class NewCacheViewModel { }


@MainActor
@Observable
class Step1Model {
    var error0:ErrorShip? = nil
    var downloadedString:String? = nil
    
    func step1Task(url:String) async {
        let vm = self
        do {
            vm.error0 = nil
            vm.downloadedString = nil
            
            let content = try await vm.startDownload(url: try vm.toURL(urlString: url))
            vm.downloadedString = content
        } catch {
            vm.error0 = .init(error: error)
        }
    }
    
    func toURL(urlString:String) throws -> URL {
        guard let url:URL = URL(string: urlString) else {
            throw ToURLError.notAValiedURL
        }
        return url
    }
    enum ToURLError:Error,LocalizedError {
        case notAValiedURL
        var errorDescription: String? {
            switch self {
            case .notAValiedURL:
                "无效的资讯源链接"
            }
        }
    }
    
    private
    func startDownload(url:URL) async throws -> String {
        //如果用户输入了错误的RSS源，我们不能一直保持等待，那样永远不会成功。
        //我们设置一个合理的请求时间（15.6s），如果是有效的RSS源，也该请求到了。
        let (urlSessionConfiguration,urlRequest) = (URLSessionToolKit.getURLSessionConfig(waitsForConnectivity: false/*这么快的请求，不考虑请求到一半黑屏的情况*/, timeout: 15.6),URLSessionToolKit.getURLRequest(url: url))
        let urlSession = URLSession(configuration: urlSessionConfiguration)
        let (data,_) = try await urlSession.data(for: urlRequest)
        guard let string = String(data:data, encoding: .utf8) else {
            throw DownloadError.dataToString
        }
        return string
    }
    enum DownloadError:Error,LocalizedError {
        case dataToString
        var errorDescription: String? {
            switch self {
            case .dataToString:
                "无法读取链接中的内容"
            }
        }
    }
}


@MainActor
@Observable
class Step2Model {
    
    var error1:ErrorShip? = nil
    var parsedURLs:[URL]? = nil
    func step2Task(rssContent:String) async {
        
        let vm = self
        do {
            vm.error1 = nil
            vm.parsedURLs = nil
            
            let images = try await parser.parseRSSForImages(content: rssContent)
            vm.parsedURLs = images
        } catch {
            vm.error1 = .init(error: error)
        }
    }
    
    private let parser = RSSParser()
    
    
}



@MainActor
@Observable
class Step3Model {
    
    var error2:ErrorShip? = nil
    var downloadedImages:[URL:Data]? = nil
    func step3Task(imagesURL:[URL]) async {
        
        let vm = self
        do {
            vm.error2 = nil
            vm.downloadedImages = nil
            
            let images = try await vm.downloadImages(imagesURL: imagesURL)
            vm.downloadedImages = images
        } catch {
            vm.error2 = .init(error: error)
        }
    }
    private
    func downloadImages(imagesURL:[URL]) async throws ->[URL:Data] {
        try await fetchData(for: imagesURL)
    }
    // 使用 TaskGroup 并行处理多个 URL，并返回 [URL: Data]
    private
    func fetchData(for urls: [URL]) async throws -> [URL: Data] {
        var result = [URL: Data]()
        
        try await withThrowingTaskGroup(of: (URL, Data).self) { group in
            let (urlSessionConfiguration) = (URLSessionToolKit.getURLSessionConfig(waitsForConnectivity: true/*下载图片很慢的，需要允许黑屏后台下载*/, timeout: 60*60/*1h*/))
            let urlSession = URLSession(configuration: urlSessionConfiguration)
            
            for url in urls {
                group.addTask {
                    let urlRequest = URLSessionToolKit.getURLRequest(url: url)
                    // 为每个 URL 启动一个异步任务
                    let (data,_) = try await urlSession.data(for: urlRequest)
                    return (url, data)
                }
            }
            
            // 收集任务的结果
            for try await (url, data) in group {
                result[url] = data
            }
        }
        
        return result
    }
    
}
@MainActor
@Observable
class Step4Model {
    
    
    var error3:ErrorShip? = nil
    var cacheEntry:RSSCacheEntry? = nil
    func step4Task(xmlContent:String,images:[URL:Data]) {
        
        let vm = self
        do {
            vm.error3 = nil
            vm.cacheEntry = nil
            
            let entry = vm.createNewCacheEntry(xmlContent: xmlContent, images: images)
            vm.cacheEntry = entry
        } catch {
            vm.error3 = .init(error: error)
        }
    }
    
    
    
    
    
    private
    func createNewCacheEntry(xmlContent:String,images:[URL:Data]) -> RSSCacheEntry {
        let newEntry:RSSCacheEntry = .init(cachedXMLString: xmlContent)
        newEntry.cachedImages = images.map({ (imageURL,imageData) in
                .init(imageURL: imageURL, imageData: imageData)
        })
        return newEntry
    }
    
}

@MainActor
@Observable
class Step5Model {
    var error4:ErrorShip? = nil
    var doneAddToDB:Bool = false
    func step5Task(entry:RSSCacheEntry,rssSurce:RSSSource,modelContext:ModelContext) {
        
        let vm = self
        do {
            vm.error4 = nil
            vm.doneAddToDB = false
            rssSurce.cacheEntries.append(entry)
            try modelContext.save()
            vm.doneAddToDB = true
        } catch {
            vm.error4 = .init(error: error)
        }
    }
}

struct DownloadingImagesView: View {
    @Environment(\.isLuminanceReduced)
    private var isLuminanceReduced
    var body: some View {
        if isLuminanceReduced {
            Color.red
                .ignoresSafeArea()
                .overlay(alignment: .center) {
                    Text("黑屏会导致下载失败")
                }
        } else {
            ProgressView()
                .controlSize(.extraLarge)
            Text(.now, style: .relative)
                .contentTransition(.numericText())
            Text("正在下载图片")
            Text("如果发现下载太慢，请将iPhone关机，然后再试一次")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
