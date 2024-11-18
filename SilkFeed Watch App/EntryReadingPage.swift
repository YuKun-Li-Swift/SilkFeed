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
                        InsertScrollOffsetYMarker(coordinateSpaceName: "NewsContentScrollView") {
                            VStack(alignment: .leading, spacing: 6) {
                               
                                ForEach(rows, content: { row in
                                    NewsReadingPageRowView(row: row, fullScreenMod: fullScreenImageMod)
                                })
                            }
                        } onOffsetYChanged: { newValue in
                            vm.currentOffsetY = newValue
                        }
                    }
                    .scrollPosition($vm.scrollPosition, anchor: .center)
                    .coordinateSpace(.named("NewsContentScrollView"))
                } focusToContent: {
                    vm.scrollDownOnePixel()
                }
            }
            .navigationTitle("详情")
            .transition(.opacity/*涉及安全区*/.animation(.smooth))
        } else {
            if let error0 = vm.error0 {
                //Step2
                InlineErrorView(text: "解析资讯详情失败", error: error0)
                    .transition(.blurReplace.animation(.smooth))
            } else {
                Group {
                    ProgressView()
                        .controlSize(.extraLarge)
                    
                    Text("正在解析资讯详情")
                }
                .task {
                    await vm.loadNews(xmlDescriptionField: xmlDescriptionField, getImageDataByURL: getImageDataByURL)
                }
                .transition(.blurReplace.animation(.smooth))
            }
        }
    }
}

//在可滚动内容的顶部插入一个标记视图，读取它的位置，来测量ScrollView的偏移
struct InsertScrollOffsetYMarker<V:View>: View {
    let coordinateSpaceName:String
    @ViewBuilder
    let content:()->(V)
    let onOffsetYChanged:(Double)->()
    var body: some View {
        VStack(alignment: .center, spacing: 0, content: {
            GeometryReader { proxy in
                Rectangle()
                    .fill(.clear)
                    .frame(width: 1, height: 1, alignment: .center)
                //用来测量可滚动内容相对于ScrollView的偏移
                    .onChange(of: proxy.frame(in: .named(coordinateSpaceName)), initial: true) { oldValue, newValue in
                        onOffsetYChanged(newValue.minY)
                    }
            }
            content()
        })
        .scrollTargetLayout()
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
    //用于往下滚动一个像素，来夺取焦点
    var scrollPosition = ScrollPosition()
    var currentOffsetY = 0.0
    func scrollDownOnePixel() {
        //往下滚动了多少，currentOffsetY就是负多少
        withAnimation(.easeInOut) {
            scrollPosition.scrollTo(y: -currentOffsetY + 1/*微小滚动一点，但至少是1，不然触发不了滚动条，没有获取焦点的效果*/)
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
                //这个是为了和Rectangle().transition(.blurReplace.animation(.smooth))相呼应，不关DelayReAppearImageView的事
                .transition(.blurReplace.animation(.smooth))
            } else {
                //在图片是不支持的格式的时候，可能出现这个
                Rectangle()
                    .fill(Color.black.gradient)
                    .aspectRatio(1, contentMode: .fit)//默认以正方形占位
                    .overlay(alignment: .center, content: {
                        Image(systemName: "photo")
                            .imageScale(.large)
                            .bold()
                    })
                    .accessibilityLabel(Text("图片"))
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
                .accessibilityLabel(Text("图片"))
        }
        .accessibilityRemoveTraits(.isButton)//查看大图对于视障人士来讲也没有意义
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
    var focusToContent:()->()
    @Namespace
    private var nameSpace
    @State
    private var mod:FullScreenImageModel? = nil
    @FocusState
    private var focusToNewsContent
    var body: some View {
        ZStack {
            if let mod {
                GeometryReader(content: { proxy in
                    content(mod)
                        .allowsHitTesting(mod.presentedImage == nil)//在查看大图的时候，点击不应该穿透到这里
                        .zIndex(0)
                    if let presentedImage = mod.presentedImage {
                        Color.black
                            .ignoresSafeArea()
                            .transition(.opacity.animation(.smooth))
                            .zIndex(1)//不要露出背景
                        FullScreenOverlayImage(presentedImage: presentedImage, onTap: {
                                mod.presentedImage = nil
                        },nameSpace:nameSpace, scaleValue: ImageLayoutToolKit.imageScaleToWidthFit(uiImage: presentedImage, availableScale: proxy.size))
                        .onDisappear {
                            //把表冠焦点还回去
                            focusToContent()
                        }
                        .transition(.asymmetric(insertion: .identity, removal: .opacity.animation(.linear(duration: .leastNormalMagnitude/*不能直接写0，不然动画就丢失了*/).delay(0.3)/*让我多显示0.3秒，以确保退出大图的时候，也正常有动画*/)))
                        .zIndex(2)//确保图片总是在文字上面（光是ZStack还保证不了这一点）
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
        //因为虽然digitalCrownRotation限制了MinValue和MaxValue，但是在做回弹效果的时候，值还是会超出。
        //我们不希望小于等于0的frame（大一点没事），所以需要截断最小值到Double.leastNormalMagnitude，而不限制最大值。
        scaleValue.clamped(min: Double.leastNormalMagnitude)
    }
    private let sensitivityScale:Double = 1.0//用来调节表冠交互的灵敏度——通过改变表冠交互的行程
    var body: some View {
        scrollView()
        .focusable()
        //最大放大一倍，因为图片原来的尺寸已经对于手表的屏幕来讲很大了
        .modifier(AdjustableDigitalCrownRotation(rotateValue:$scaleValue,minValue: 0.1, maxValue: 1))
        .scrollIndicators(.never)/*避免ScrollView的滚动条和digitalCrownRotation的滚动条打架*/
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
        //使用表冠来缩放的时候，以中心为锚点（默认是左上角为锚点）
        .defaultScrollAnchor(.center, for: .sizeChanges)
    }
}



///在不改变外部取值范围的情况下，调节灵敏度
struct AdjustableDigitalCrownRotation: ViewModifier {
    @Binding
    var rotateValue:Double
    let minValue:Double
    let maxValue:Double
    @State
    private var innerRotateValue:Double = -1//一出现就会被.task赋值的
    @State
    private var ignoreFirstInnerRotateValueChange = true
    private let sensitivityScale:Double = 3.2//用来调节表冠交互的灵敏度——通过改变表冠交互的行程，值越大，则需要旋转越多才能达到相同的变化。如果范围是0.1-1，并且sensitivityScale是2，则扩展到0.2-2。
    func body(content: Content) -> some View {
        content
            .digitalCrownRotation($innerRotateValue, from: minValue*sensitivityScale, through: maxValue*sensitivityScale, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true, onChange: { _ in }, onIdle: {})
            .task {
                //刚打开的时候更新初始的innerRotateValue
                innerRotateValue = rotateValue * sensitivityScale
            }
            .onChange(of: innerRotateValue, initial: false) { oldValue, innerRotateValue in
                if ignoreFirstInnerRotateValueChange {
                    ignoreFirstInnerRotateValueChange = false
                    return
                }
                //开始让外部的旋转值与内部同步
                rotateValue = innerRotateValue / sensitivityScale
            }
    }
}


extension Double {
    func clamped(min minValue: Double? = nil, max maxValue: Double? = nil) -> Double {
        if let minValue = minValue, self < minValue {
            return minValue
        }
        if let maxValue = maxValue, self > maxValue {
            return maxValue
        }
        return self
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
