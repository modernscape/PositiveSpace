import SwiftUI
import GoogleMobileAds
//
struct AdMobBannerView__: UIViewRepresentable {
    var width: CGFloat
    
    func makeUIView(context: Context) -> BannerView {
        // GADAdSizeBanner -> AdSizeBanner に変更
        let banner = BannerView(adSize: AdSizeBanner)
        
        // ★ テスト用広告ユニット ID（本番リリース時はご自身のIDに変更してください）
//        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
//        本番 
        banner.adUnitID = "ca-app-pub-1511850082670293/4083686320"
        
        // ★ 重要：バナーの固有サイズが親ビューの横幅を押し広げないようにする
        banner.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        banner.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // 現在のウィンドウシーンからルートビューコントローラーを取得して設定
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootViewController
        }
        
        // GADRequest -> Request に変更
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        let bannerWidth = max(320, width)
        let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: bannerWidth)
        
        if !CGSizeEqualToSize(uiView.adSize.size, adaptiveSize.size) {
            uiView.adSize = adaptiveSize
            uiView.frame.size = adaptiveSize.size
            uiView.load(Request())
        }
    }
    
}


struct AdMobBannerView_cur: UIViewRepresentable {
    var width: CGFloat
    
    func makeUIView(context: Context) -> BannerView {
        let bannerWidth = max(320, width)
        let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: bannerWidth)
        let banner = BannerView(adSize: adaptiveSize)
        // ★ テスト用広告ユニット ID（本番リリース時はご自身のIDに変更してください）
        //        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        //        本番
        banner.adUnitID = "ca-app-pub-1511850082670293/4083686320"
        
        banner.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        banner.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
        }
        
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        let bannerWidth = max(320, width)
        let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: bannerWidth)
        
        if !CGSizeEqualToSize(uiView.adSize.size, adaptiveSize.size) {
            uiView.adSize = adaptiveSize
            uiView.frame.size = adaptiveSize.size
            uiView.load(Request())
        }
        
        if uiView.rootViewController == nil,
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController {
            uiView.rootViewController = rootVC
        }
    }
}





// ▼ ここから下をファイルのトップレベル（一番外側）に配置する
//struct AdMobBannerModifier: ViewModifier {
//    func body(content: Content) -> some View {
//        content
//            .safeAreaInset(edge: .bottom) {
//                AdMobBannerView()
//                    .frame(height: 50)
//                    .frame(maxWidth: .infinity)
//                    .background(Color(.systemBackground))
//            }
//    }
//}
//
//extension View {
//    func withAdMobBanner() -> some View {
//        self.modifier(AdMobBannerModifier())
//    }
//}
