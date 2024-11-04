//
//  RSSSourceCell.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/3.
//

import DateToolsSwift
import SwiftUI

func dateDescription(date:Date) -> String {
    date.timeAgoSinceNow
}

struct RSSSourceCell: View {
    let source:RSSSource
    let onTap:()->()
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .contentTransition(.numericText())
                    .animation(.smooth.delay(0.5), value: source.name)//用户关闭键盘，回到这个页面的时候，刚好看到这个内容
                if let lastReadingDate = source.lastReadingDate {
                    Text("上次阅读："+dateDescription(date: lastReadingDate))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }

    }
}

