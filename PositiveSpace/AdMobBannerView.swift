import SwiftUI
import GoogleMobileAds

struct AdMobBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        // GADAdSizeBanner -> AdSizeBanner に変更
        let banner = BannerView(adSize: AdSizeBanner)
        
        // ★ テスト用広告ユニット ID（本番リリース時はご自身のIDに変更してください）
//        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
//        本番 
        banner.adUnitID = "ca-app-pub-1511850082670293/4083686320"
        
        // 現在のウィンドウシーンからルートビューコントローラーを取得して設定
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootViewController
        }
        
        // GADRequest -> Request に変更
        banner.load(Request())
        return banner
    }
    
    // GADBannerView -> BannerView に変更
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    
}

// ▼ ここから下をファイルのトップレベル（一番外側）に配置する
struct AdMobBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                AdMobBannerView()
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
            }
    }
}

extension View {
    func withAdMobBanner() -> some View {
        self.modifier(AdMobBannerModifier())
    }
}
