import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct PositiveSpaceApp: App {
    init() {
        // Google Mobile Ads SDK の初期化
        MobileAds.shared.start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ElementItem.self, HistoryItem.self])
    }
}
