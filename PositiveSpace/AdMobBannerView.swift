import SwiftUI
import GoogleMobileAds

struct AdMobBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        
    
//        ★ テスト用広告ユニット ID（本番リリース時はご自身のIDに変更してください）
//        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
//        本番
        banner.adUnitID = "ca-app-pub-1511850082670293/4083686320"
        
        banner.rootViewController = currentRootViewController()
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = currentRootViewController()
        }
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
    }
    
    private func currentRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}

struct AdMobBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color(.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay {
                        AdMobBannerView()
//                            .frame(maxWidth: .infinity)
//                            .frame(height: 50)
                            .frame(width: 320, height: 50)
                    }
                    .clipped()
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//                    .padding(.horizontal, 1)
//                    .padding(.vertical, 4)
//                    .background(Color(.clear))
            }
    }
}

//struct AdMobBannerModifier: ViewModifier {
//    func body(content: Content) -> some View {
//        content
//            .safeAreaInset(edge: .bottom) {
//                AdMobBannerView()
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 50)
//                    .background(Color(.systemBackground))
//                    .clipped()
//            }
//    }
//}

extension View {
    func withAdMobBanner() -> some View {
        self.modifier(AdMobBannerModifier())
    }
}
