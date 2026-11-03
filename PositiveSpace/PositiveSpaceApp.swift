import SwiftUI
import SwiftData

@main
struct PositiveSpaceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ElementItem.self, HistoryItem.self])
    }
}
