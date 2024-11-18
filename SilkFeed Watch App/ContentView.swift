//
//  ContentView.swift
//  SilkFeed Watch App
//
//  Created by Yukun Li on 2024/11/3.
//

import SwiftUI
import SwiftData
import SwiftSoup
import os

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                GetSourceHolder { sourceHolder in
                    SourceView(sourceHolder:sourceHolder)
                }
                
            }
            .navigationTitle("Silk Feed")
        }
    }
}

struct GetSourceHolder<V:View>: View {
    @ViewBuilder
    let content:(RSSSourceHolder) -> (V)
    //数据库中只应该存在一个SourceHolder
    @Query(FetchDescriptor<RSSSourceHolder>.init(predicate: #Predicate<RSSSourceHolder> { _ in
        true
    }), animation: .smooth)
    private var sourceHolders:[RSSSourceHolder]
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var error0:ErrorShip? = nil
    var body: some View {
        Group {
            if let holder = sourceHolders.first {
                content(holder)
            } else {
                ProgressView()
                    .task {
                        do {
                            error0 = nil
                            let newHolder = RSSSourceHolder()
                            modelContext.insert(newHolder)
                            try modelContext.save()
                        } catch {
                            error0 = .init(error: error)
                        }
                    }
            }
        }
            .modifier(ErrorSupport(error: $error0))
    }
}

struct SourceView: View {
    var sourceHolder:RSSSourceHolder
    private var sources:[RSSSource] {
        sourceHolder.sources
    }
    var body: some View {
        if sources.isEmpty {
            AddSourceView(applyStyle: true, sourceHolder: sourceHolder)
        } else {
            RSSSourcesView(sourceHolder: sourceHolder)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        AddSourceView(applyStyle: false, sourceHolder: sourceHolder)
                    }
                }
        }
    }
}

struct ErrorShip:Identifiable {
    let id = UUID()
    let error:Error
}

struct AddSourceView: View {
    var applyStyle:Bool
    @Environment(\.modelContext)
    private var modelContext
    var sourceHolder:RSSSourceHolder
    private var sources:[RSSSource] {
        sourceHolder.sources
    }
    @State
    private var error0:ErrorShip? = nil
    var body: some View {
        SystemDesginTextField(prompt: Text("请输入资讯源链接"), label: {
            Label("添加资讯源", systemImage: "plus")
        }, onSubmit: { content in
            handleUserInput(content: content)
        }, applyStyle: applyStyle)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.join)
        .modifier(ErrorSupport(error: $error0))
    }
    func handleUserInput(content:String) {
        do {
            self.error0 = nil
            guard content.hasPrefix("http://") || content.hasPrefix("https://") else {
                throw InvalidInput.notAURL
            }
            guard let url = URL(string: content) else {
                throw InvalidInput.notAURL
            }
            let newObj = RSSSource(name: sources.generateNewItemName(url: url), url: url)
            sourceHolder.sources.insert(newObj, at: 0)
            try modelContext.save()
        } catch  {
            print("发生错误")
            self.error0 = .init(error: error)
        }
    }
    enum InvalidInput:Error,LocalizedError {
        case notAURL
        var errorDescription: String? {
            switch self {
            case .notAURL:
                "请输入一个链接（以https://开头）"
            }
        }
    }
}

struct RSSSourcesView: View {

    var sourceHolder:RSSSourceHolder
    
    private var sources:[RSSSource] {
        sourceHolder.sources
    }
    
    @Environment(\.modelContext)
    private var modelContext
    
    @State
    private var renamingSource:RSSSource? = nil
    
    @State
    private var error0:ErrorShip? = nil
    
    @State
    private var selectedSource:RSSSource? = nil
    var body: some View {
        List {
            ForEach(sources) { source in
                RSSSourceCell(source: source, onTap: {
                    selectedSource = source
                })
                .swipeActions(edge: .leading, allowsFullSwipe: false, content: {
                    Button(action: {
                        self.renamingSource = source
                    }, label: {
                        Label("重命名", systemImage: "pencil")
                    })
                    .tint(.yellow)
                })
            }
            .onDelete { indexSet in
                swipeDelete(indexSet:indexSet)
            }
            .onMove { indexSet, int in
                sourceHolder.sources.move(fromOffsets: indexSet, toOffset: int)
            }
        }
        .navigationDestination(item: $selectedSource, destination: { source in
            RSSSourceCacheView(rssSource: source)
        })
        .sheet(item: $renamingSource, content: { renamingSource in
            RSSSourceRenameView(rssSource: renamingSource,closeMe: {self.renamingSource = nil})
        })
        .modifier(ErrorSupport(error: $error0))
    }
    func swipeDelete(indexSet:IndexSet) {
        do {
            self.error0 = nil
            sourceHolder.sources.remove(atOffsets: indexSet)
            try modelContext.save()
        } catch {
            
                print("发生错误")
                self.error0 = .init(error: error)
        }
    }
}

struct RSSSourceCacheView: View {
    @State
    var rssSource:RSSSource
    
    @State
    private var showAlert0 = false
    
    @State
    private var newCacheViewID = UUID()
    @State
    private var pushNewCacheView = false
    @State
    private var selectedEntry:RSSCacheEntry? = nil
    var body: some View {
        VStack {
            TabView {
                List {
                    Section("资讯源链接", content: {
                        Button {
                            showAlert0 = true
                        } label: {
                            Text(rssSource.url)
                                .font(.footnote)
                        }
                        .listRowBackground(EmptyView())
                    })
                    Section(content: { }, header: {
                        Label("创建于"+rssSource.creatDate.format(with: .long), systemImage: "deskclock.fill")
                    })
                }
                .navigationTitle(rssSource.name)
                .alert(isPresented: $showAlert0, content: alert0)
                VStack {
                    if rssSource.cacheEntries.isEmpty {
                        ContentUnavailableView("还没有缓存", systemImage: "square.stack.3d.up.slash.fill")
                        createNewCacheButton()
                    } else {
                        CacheList(cacheEntries: rssSource.cacheEntries,createNewCacheButton:{
                            createNewCacheButton()
                        },deleteAction:{ entry in
                            for i in entry {
                                if let targetIndex = rssSource.cacheEntries.firstIndex(of: i) {
                                    rssSource.cacheEntries.remove(at: targetIndex)
                                }
                            }
                        }, selectedEntry: $selectedEntry)
                    }
                }
                .navigationTitle("缓存列表")
            }
            .tabViewStyle(.verticalPage)
            .navigationDestination(isPresented: $pushNewCacheView, destination: {
                NewCacheView(rssSource:rssSource, closeMe: {
                    pushNewCacheView = false
                })
                    .id(newCacheViewID)
            }).navigationDestination(item: $selectedEntry, destination: { entry in
                EntryReadingPage(source: rssSource, entry: entry)
            })
        }
    }
    @ViewBuilder
    func createNewCacheButton() -> some View {
        SystemDesginButton(label: {
            Label("创建新的缓存", systemImage: "icloud.and.arrow.down.fill")
        }, action: {
            //避免残留上一次下载到一半的任务
            newCacheViewID = UUID()
            pushNewCacheView = true
        })
    }
}

func alert0() -> Alert {
    .init(title: Text("如需更改链接，请直接添加一个新的资讯源，然后把旧的删掉"))
}

struct NewsItem:Identifiable,Hashable {
    let id = UUID()
    let title:String
    let xmlContent:String
}

// 已有的结构和枚举
enum Row: Identifiable {
    var id: UUID {
        switch self {
        case .text(let textRow):
            return textRow.id
        case .image(let imageRow):
            return imageRow.id
        }
    }
    
    case text(TextRow)
    case image(ImageRow)
}

struct TextRow: Identifiable {
    let id = UUID()
    let textContent: String
}

struct ImageRow: Identifiable {
    let id = UUID()
    let imageData: Data
}

actor RSSParser {
    // 将 HTML `xmlContent` 解析为 [Row]
    func parseToRow(xmlContent:String,getImageDataByURL:(URL) async ->(Data?)) async throws -> [Row] {
        print(xmlContent)
        // 解码 HTML 实体
        let decodedDescription = try Entities.unescape(xmlContent)
        // 解析 HTML 内容
        let document = try SwiftSoup.parseBodyFragment(decodedDescription)
        // 查找所有段落和图片标签
        let elements = try document.select("p, img")
        
        var rows: [Row] = []
        
        for element in elements {
            if element.tagName() == "p" {
                // 处理文本内容
                let textContent = try element.text()
                let textRow = TextRow(textContent: textContent)
                rows.append(.text(textRow))
            } else if element.tagName() == "img" {
                // 处理图片链接，并从本地缓存获取图片
                if let src = try? element.attr("src"), let url = URL(string: src), let imageData = await getImageDataByURL(url) {
                    let imageRow = ImageRow(imageData: imageData)
                    rows.append(.image(imageRow))
                }
            }
        }
        return rows
    }
    func getNewsItems(xmlContent:String) throws -> [NewsItem] {
        // 解析 XML 数据
        let document = try SwiftSoup.parse(xmlContent)
        
        // 获取所有 `<item>` 元素
        let items = try document.select("item")
        var newsItems:[NewsItem] = []
        for item in items {
            // 提取 `<title>` 和 `<description>` 文本
            let title = try item.select("title").text()
            let encodedDescription = try item.select("description").text()
            
            // 解码转义的 `<description>` 内容
            let description = try Entities.unescape(encodedDescription)
            
            // 输出 `[title: description]` 格式
//            print("[\(title): \(description)]")
            newsItems.append(.init(title: title, xmlContent: description))
        }
        return newsItems
    }
    func parseRSSForImages(content:String) async throws -> [URL] {
        let exampleContent = """
        <rss version="2.0">
        <channel>
        <item>
        <title>郭明錤：低价版苹果 Vision Pro 量产时间已被推迟到 2027 年以后</title>
        <description>
        <p data-vmark="246f">IT之家 11 月 3 日消息，分析师郭明錤今日发文称，就其所知，低价版 Vision Pro 的量产时间被递延到 2027 年之后已有一段时间。</p>
        <p data-vmark="09eb" style="text-align: center;">
        <img src="https://img.ithome.com/newsuploadfiles/2024/11/fefdffc3-5dbf-4b98-90d2-771385f83a77.jpg?x-bce-process=image/format,f_auto" w="657" h="381" data-weibo="0" class="no-alt-img">
        </p>
        </description>
        </item>
        <item>
        <title>广东首支无人机消防救援专业队在松山湖成立</title>
        <description>
        <p data-vmark="9ca0">IT之家 11 月 3 日消息...</p>
        <p style="text-align: center;" data-vmark="45dc">
        <img src="https://img.ithome.com/newsuploadfiles/2024/11/6d095bed-66c3-45bf-ae45-3b08e0dcc298.png?x-bce-process=image/format,f_auto" w="1117" h="1114" data-weibo="0" class="no-alt-img">
        </p>
        </description>
        </item>
        </channel>
        </rss>
        """
        var imageUrls = [String]()
        // 解析 XML 数据
        let fullRss = try SwiftSoup.parse(content)
        var shouldOutput = true
        let channels = try fullRss.select("channel")
        for channel in channels {
            let items = try channel.select("item")
            for item in items {
                let descriptions = try item.select("description")
                for encodedDescription in descriptions {
                    // 解码转义字符
                    let decodedDescription = try Entities.unescape(try encodedDescription.outerHtml())
                    if shouldOutput {
                        shouldOutput = false
                        print(decodedDescription)
                    }
                    let description = try SwiftSoup.parse(decodedDescription)
                    let imgs = try description.select("img")
                    for imgTag in imgs {
                                    if let src = try? imgTag.attr("src") {
                                        imageUrls.append(src)
                                    }
                    }
                }
            }
        }
        // 打印所有图片链接
        for url in imageUrls {
            os_log("\(url)")
        }
        return imageUrls.compactMap { urlString in
            guard let toURL = URL(string: urlString) else {
                print("无法转换为URL")
                print(urlString)
                return nil
            }
            return toURL
        }
    }
}


struct ErrorSupport: ViewModifier {
    @Binding
    var error:ErrorShip?
    var showError0Alert:Binding<Bool> {
        Binding {
            error != nil
        } set: { isAlert in
            if isAlert {
                //do nothing
            } else {
                error = nil
            }
        }
    }
    var errorDescription:String {
        error?.error.localizedDescription ?? "未知错误"
    }
    
    func body(content: Content) -> some View {
        content
            .alert(errorDescription, isPresented: showError0Alert, actions: {})
    }
}

struct InlineErrorView: View {
    let text:String
    let error:ErrorShip
    @State
    private var showDetail = false
    var body: some View {
        Button {
            showDetail = true
        } label: {
            Text(text)
        }
        .alert(error.error.localizedDescription, isPresented: $showDetail, actions: {})
    }
}

struct SystemDesginButton<L:View>: View {
    @ViewBuilder
    let label:L
    let action:()->()
    var body: some View {
            Button {
                action()
            } label: {
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    label
                        .padding(.vertical,14)
                    Spacer()
                }
                    .background(Color.accentColor.gradient.secondary)
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonBorderShape(.capsule)
            .buttonStyle(.plain)
            .scenePadding(.horizontal)
    }
}


struct SystemDesginTextField<L:View>: View {
    let prompt:Text
    @ViewBuilder
    let label:L
    let onSubmit:(String) -> Void
    var applyStyle:Bool
    var body: some View {
        if applyStyle {
            TextFieldLink(prompt: prompt, label: {
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    label
                        .padding(.vertical,14)
                    Spacer()
                }
                .background(Color.accentColor.gradient.secondary)
                .clipShape(Capsule(style: .continuous))
            }, onSubmit: onSubmit)
            .buttonBorderShape(.capsule)
            .buttonStyle(.plain)
            .scenePadding(.horizontal)
        } else {
            TextFieldLink(prompt: prompt, label: {
                label
            }, onSubmit: onSubmit)
        }
    }
}




#Preview {
    ContentView()
        .modelContainer(for: [RSSSource.self,RSSCacheEntry.self,RSSCachedIamge.self])
}
