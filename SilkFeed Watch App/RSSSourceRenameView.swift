//
//  RSSSourceRenameView.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/3.
//

import SwiftUI

struct RSSSourceRenameView: View {
    @State
    var rssSource:RSSSource
    let closeMe:()->()
    @Environment(\.modelContext)
    private var modelContext
    
    @State
    private var error0:ErrorShip? = nil
    
    var body: some View {
        
        TextField("输入资讯源的名字", text: $rssSource.name)
            .onSubmit {
                handleRename()
            }
            .navigationTitle("重命名")
            .modifier(ErrorSupport(error: $error0))
    }
    func handleRename() {
        do {
            self.error0 = nil
            try modelContext.save()
            closeMe()
            
        } catch {
            
                print("发生错误")
                self.error0 = .init(error: error)
        }
    }
}

