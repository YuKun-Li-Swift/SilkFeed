//
//  CleanerPage.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/25.
//

import SwiftUI
import SwiftData

struct CleanerPage: View {
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var vm = CleanerPageViewModel()
    var body: some View {
        
            GetSourceHolder { sourceHolder in
                List {
                    Button {
                        vm.confirmAlert = true
                    } label: {
                        Label("清理App占用的空间", systemImage: "trash")
                        Text("会清空已缓存的资讯，但会保留资讯源")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .alert("确认清空缓存吗？", isPresented: $vm.confirmAlert) {
                    Button(role: .destructive) {
                        vm.clean(sourceHolder: sourceHolder, modelContext: modelContext)
                    } label: {
                        Text("确认")
                    }
                    Button(role: .cancel) {
                        
                    } label: {
                        Text("取消")
                    }

                }
                .alert("缓存清理完成", isPresented: $vm.successAlert, actions: {
                    
                    Button(action:{}) {
                        Text("好")
                    }
                }, message: {
                    
                })
                .modifier(ErrorSupport(error: $vm.error0))
            }
    }
    
}


@MainActor
@Observable
class CleanerPageViewModel {
    var confirmAlert = false
    var error0:ErrorShip? = nil
    var successAlert = false
    func clean(sourceHolder:RSSSourceHolder,modelContext:ModelContext) {
        
        
        var descriptor = FetchDescriptor(predicate: #Predicate<RSSSource>{ _ in true })
        descriptor.includePendingChanges = false
       
        do {
            error0 = nil
            let aloneSourcesFromOldVersionApp = try modelContext.fetch(descriptor, batchSize: 1)
            let sourcesFromHolder:[RSSSource] = sourceHolder.sources
            let sourcesNeedToScan:[RSSSource] = sourcesFromHolder+aloneSourcesFromOldVersionApp
            for source in sourcesNeedToScan {
                for entry in source.cacheEntries {
                    //占空间的正是这RSSCachedIamge
                    for image in entry.cachedImages {
                        modelContext.delete(image)
                    }
                    //但是RSSSource可以离了RSSCacheEntry，RSSCacheEntry不能离了RSSCachedIamge，要走一起走
                    modelContext.delete(entry)
                    //delete完就立马保存，这样即使删了一会儿爆内存了，已经删了的仍然是删了的。
                    try modelContext.save()
                }
            }
            successAlert = true
        } catch {
            error0 = .init(error: error)
        }
    }
}

