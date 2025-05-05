import SwiftUI
import SwiftData



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
