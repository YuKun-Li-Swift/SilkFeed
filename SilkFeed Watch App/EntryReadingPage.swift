//
//  EntryReadingPage.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/4.
//

import SwiftUI

//传入一个Entry，用户可以阅读它
struct EntryReadingPage: View {
    @State
    var source:RSSSource
    @State
    var entry:RSSCacheEntry
    var body: some View {
        NewsListView(entry: entry)
            .task {
                source.lastReadingDate = Date()
            }
    }
}

struct NewsListView: View {
    @State
    var entry:RSSCacheEntry
    @State
    private var vm = NewsListViewModel()
    var body: some View {
        if let newsItems = vm.newsItems {
            List {
                ForEach(newsItems, content: { newsItem in
                    Button {
                        vm.selectedNews = newsItem
                    } label: {
                        Text(newsItem.title)
                    }
                })
            }
            .navigationTitle("资讯列表")
            .navigationDestination(item: $vm.selectedNews, destination: { news in
                NewsItemReadingPage(xmlDescriptionField: news.xmlContent, getImageDataByURL: { await vm.getImageDataByURL($0, entry: entry) })
            })
            .transition(.opacity/*涉及安全区*/.animation(.smooth))
        } else {
            if let error0 = vm.error0 {
                //Step2
                InlineErrorView(text: "解析资讯列表失败", error: error0)
                    .transition(.blurReplace.animation(.smooth))
            } else {
                Group {
                    ProgressView()
                        .controlSize(.extraLarge)
                    Text("正在解析资讯列表")
                }
                .task {
                    await vm.loadNews(entry: entry)
                }
                .transition(.blurReplace.animation(.smooth))
            }
        }
    }
}

@MainActor
@Observable
class NewsListViewModel {
    var newsItems:[NewsItem]? = nil
    var error0:ErrorShip? = nil
    func loadNews(entry:RSSCacheEntry) async {
        do {
            error0 = nil
            newsItems = nil
            let newItems = try await parser.getNewsItems(xmlContent: entry.cachedXMLString)
            newsItems =  newItems
        } catch {
            error0 = .init(error: error)
        }
    }
    var selectedNews:NewsItem? = nil
    func getImageDataByURL(_ imageURL:URL,entry:RSSCacheEntry) async ->(Data?) {
        
        entry.cachedImages.first { cachedImage in
            cachedImage.imageURL == imageURL.absoluteString
        }?.imageData
    }
    private let parser = RSSParser()
}

struct NewsItemReadingPage: View {
    let xmlDescriptionField:String
    let getImageDataByURL:(URL) async ->(Data?)
    @State
    private var vm = NewsItemReadingViewModel()
    var body: some View {
        if let rows = vm.rows {
            VStack {
                FullScreenImageView { fullScreenImageMod in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(rows, content: { row in
                                NewsReadingPageRowView(row: row, fullScreenMod: fullScreenImageMod)
                            })
                        }
                    }
                }
            }
            .navigationTitle("详情")
            .transition(.opacity/*涉及安全区*/.animation(.smooth))
        } else {
            if let error0 = vm.error0 {
                //Step2
                InlineErrorView(text: "解析资讯列表失败", error: error0)
                    .transition(.blurReplace.animation(.smooth))
            } else {
                Group {
                    ProgressView()
                        .controlSize(.extraLarge)
                    
                    Text("正在解析资讯列表")
                }
                .task {
                    await vm.loadNews(xmlDescriptionField: xmlDescriptionField, getImageDataByURL: getImageDataByURL)
                }
                .transition(.blurReplace.animation(.smooth))
            }
        }
    }
}

@MainActor
@Observable
class NewsItemReadingViewModel {
    var rows:[Row]? = nil
    var error0:ErrorShip? = nil
    func loadNews(xmlDescriptionField:String,getImageDataByURL:(URL) async ->(Data?)) async {
        do {
            error0 = nil
            rows = nil
            let newRows = try await parser.parseToRow(xmlContent: xmlDescriptionField, getImageDataByURL: getImageDataByURL)
            rows = newRows
        } catch {
            error0 = .init(error: error)
        }
    }
    private let parser = RSSParser()
}

struct NewsReadingPageRowView: View {
    let row:Row
    let fullScreenMod:FullScreenImageModel
    var body: some View {
        switch row {
        case .text(let textRow):
            let textContent = textRow.textContent
            Text(textContent)
                .scenePadding(.horizontal)
        case .image(let imageRow):
            let imageData = imageRow.imageData
            AsyncLocalImage(data: imageData, fullScreenMod: fullScreenMod)
        }
    }
}

//避免在从Data（紧凑的、带压缩的图片格式）转换为UIImage的时候，带来主线程的延迟
struct AsyncLocalImage: View {
    let data:Data
    let fullScreenMod:FullScreenImageModel
    @State
    private var actor = AsyncLocalImageActor()
    @State
    private var uiImage:UIImage? = nil
    var body: some View {
        VStack {
            if let uiImage {
                let isMeFullScreen = (fullScreenMod.presentedImage == uiImage)
                DelayReAppearImageView(isMeFullScreen: isMeFullScreen,uiImage: uiImage,onTap: {
                        fullScreenMod.presentedImage = uiImage
                })
                .matchedGeometryEffect(id: isMeFullScreen ?  .random(in: 0...Int.max) : uiImage.hash , in: fullScreenMod.nameSpace)//确保在nameSpace中只有一个是当前显示的图片的ID的元素，如果我正在被呈现，那我就黑掉这个，只保持尺寸占位
            } else {
                Rectangle()
                    .aspectRatio(1, contentMode: .fit)
                    .redacted(reason: .placeholder)
                    .transition(.blurReplace.animation(.smooth))
            }
        }
        .task {
            let newUIImgae = await actor.loadImage(data: data)
            uiImage = newUIImgae
        }
    }
}


actor AsyncLocalImageActor {
    func loadImage(data:Data) -> UIImage? {
        .init(data: data)
    }
}

struct DelayReAppearImageView: View {
    let isMeFullScreen:Bool
    let uiImage:UIImage
    let onTap:()->()
    @State
    private var isAppearInner = true
    var body: some View {
        Button {
            onTap()
        } label: {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .buttonStyle(.plain)
        .opacity(isAppearInner ? 0 : 1)
        .onChange(of: isMeFullScreen, initial: true) { oldValue, newValue in
            if oldValue == true && newValue == false {//关闭了全屏看图
                //延迟0.3秒再显示我
                withAnimation(.linear(duration: .leastNormalMagnitude/*不能直接写0，不然动画就丢失了*/).delay(0.3)) {
                    isAppearInner = newValue
                }
            } else {
                isAppearInner = newValue
            }
        }
    }
}


struct FullScreenImageView<V:View>: View {
    @ViewBuilder
    let content:(FullScreenImageModel)->(V)
    @Namespace
    private var nameSpace
    @State
    private var mod:FullScreenImageModel? = nil
    var body: some View {
        ZStack {
            if let mod {
                GeometryReader(content: { proxy in
                    content(mod)
                        .animation(.smooth) { v in
                            v
                                .allowsHitTesting(mod.presentedImage == nil)
                                .focusable(mod.presentedImage == nil)//表冠
                        }
                        .zIndex(0)
                    if let presentedImage = mod.presentedImage {
                        FullScreenOverlayImage(presentedImage: presentedImage, onTap: {
                                mod.presentedImage = nil
                        },nameSpace:nameSpace, scaleValue: ImageLayoutToolKit.imageScaleToWidthFit(uiImage: presentedImage, availableScale: proxy.size))
                        .transition(.asymmetric(insertion: .identity, removal: .opacity.animation(.linear(duration: .leastNormalMagnitude/*不能直接写0，不然动画就丢失了*/).delay(0.3)/*让我多显示0.3秒，以确保退出大图的时候，也正常有动画*/)))
                        .zIndex(1)//确保图片总是在文字上面（光是ZStack还保证不了这一点）
                    }
                })
                .animation(.smooth(duration: 0.3), value: mod.presentedImage)//让matchedGeometryEffect正常带上动画
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 1, height: 1, alignment: .center)
                    .accessibilityHidden(true)
            }
        }
        .task {
            mod = .init(nameSpace: self.nameSpace)
        }
    }
}

struct ImageLayoutToolKit {
    static
    func imageScaleToWidthFit(uiImage: UIImage, availableScale: CGSize) -> Double {
        let imageSize = uiImage.size
        let widthScale = availableScale.width / imageSize.width
        return widthScale
    }
}

struct FullScreenOverlayImage: View {
    let presentedImage:UIImage
    let onTap:()->()
    let nameSpace:Namespace.ID
    @State
    var scaleValue:Double//默认值应该是刚好fit的尺寸
    var clampedScaleValue:Double {
        //因为虽然digitalCrownRotation限制了MinValue和MaxValue，但是在做回弹效果的时候，值还是会超出返回，并且我们不希望小于0的frame（大一点没事），所以需要截断
        scaleValue.clamped(to: Double.leastNormalMagnitude...1)
    }
    var body: some View {
        scrollView()
        .focusable()
        //最大放大一倍，因为图片原来的尺寸已经对于手表的屏幕来讲很大了
        .digitalCrownRotation($scaleValue, from: 0.1, through: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true, onChange: { _ in }, onIdle: {})
    }
    @ViewBuilder
    func scrollView() -> some View {
        ScrollView([.horizontal,.vertical]) {
            Button(action:{
                onTap()
            }) {
                Image(uiImage: presentedImage)
                    .resizable()
                    .matchedGeometryEffect(id:presentedImage.hash, in: nameSpace)
                    //使用原尺寸渲染
                    .frame(width: presentedImage.size.width*clampedScaleValue, height: presentedImage.size.height*clampedScaleValue, alignment: .center)
            }
            .buttonStyle(.plain)
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

@MainActor
@Observable
class FullScreenImageModel {
    var nameSpace:Namespace.ID
    init(nameSpace: Namespace.ID) {
        self.nameSpace = nameSpace
    }
    var presentedImage:UIImage? = nil
}
