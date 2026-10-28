import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - 画面下部バナー広告コンテナ（Pro版アップデート時は自動的に非表示）
struct AdBannerContainerView: View {
    @ObservedObject var storeManager = StoreManager.shared
    var onTapUpgrade: (() -> Void)? = nil
    @State private var isAdMobLoaded: Bool = false
    
    var body: some View {
        if !storeManager.isPro {
            ZStack {
                // AdMob広告がロード完了するまでの間（またはオフライン時）は内蔵Pro案内バナーを表示し、空白を作らない
                if !isAdMobLoaded {
                    FallbackBannerView(onTapUpgrade: onTapUpgrade)
                        .frame(height: 50)
                }
                
                #if canImport(GoogleMobileAds)
                AdMobBannerRepresentable(isAdLoaded: $isAdMobLoaded)
                    .frame(height: 50)
                    .opacity(isAdMobLoaded ? 1.0 : 0.0)
                #endif
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(white: 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
            )
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.85), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - GoogleMobileAds (AdMob) SDK 導入時のネイティブバナーView
#if canImport(GoogleMobileAds)
struct AdMobBannerRepresentable: UIViewRepresentable {
    @Binding var isAdLoaded: Bool
    
    // DEBUGビルド（開発・シミュレータ）ではポリシー違反防止＆即時表示のためGoogle公式テストIDを使用し、
    // Releaseビルド（本番アーカイブ）では Info.plist の本番広告ユニットID (ca-app-pub-1148610655574304/3245126264) を使用する
    private var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        if let plistID = Bundle.main.object(forInfoDictionaryKey: "GADBannerAdUnitID") as? String,
           !plistID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "ca-app-pub-1148610655574304/3245126264"
        #endif
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.backgroundColor = .clear
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
        }
        
        // Guideline 5.1.3(ii) ヘルスケアデータのプライバシー保護準拠：非パーソナライズド広告リクエスト (npa=1)
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        
        banner.load(request)
        return banner
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
    
    final class Coordinator: NSObject, GADBannerViewDelegate {
        var parent: AdMobBannerRepresentable
        
        init(_ parent: AdMobBannerRepresentable) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.parent.isAdLoaded = true
                }
            }
        }
        
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("ℹ️ AdMob バナー取得待機中（フォールバックバナー表示継続）: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isAdLoaded = false
            }
        }
    }
}
#endif

// MARK: - 内蔵バナー（AdMobロード完了前・オフライン時でも空白を作らずPro版へ誘導する50ptバナー）
struct FallbackBannerView: View {
    var onTapUpgrade: (() -> Void)?
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            onTapUpgrade?()
        }) {
            HStack(spacing: 10) {
                Text("AD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.75))
                    .cornerRadius(3)
                
                VStack(alignment: .leading, spacing: 1.5) {
                    Text("DISCIPLINE PRO — 広告なし・完全集中モード")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("設定画面から ¥500（買い切り）でバナー広告を永久に非表示にできます")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.55))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 3) {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white)
                .cornerRadius(5)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
