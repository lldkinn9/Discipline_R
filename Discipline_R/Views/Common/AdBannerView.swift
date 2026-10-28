import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - 画面下部バナー広告コンテナ（Pro版アップデート時は自動的に非表示）
struct AdBannerContainerView: View {
    @ObservedObject var storeManager = StoreManager.shared
    var onTapUpgrade: (() -> Void)? = nil
    
    var body: some View {
        if !storeManager.isPro {
            VStack(spacing: 0) {
                #if canImport(GoogleMobileAds)
                AdMobBannerRepresentable()
                    .frame(height: 50)
                #else
                FallbackBannerView(onTapUpgrade: onTapUpgrade)
                    .frame(height: 50)
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
    // Info.plist または環境変数から本番広告ユニットIDを取得（未設定・DEBUG時はGoogle公式テストバナーIDを使用）
    private var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        if let plistID = Bundle.main.object(forInfoDictionaryKey: "GADBannerAdUnitID") as? String,
           !plistID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistID
        }
        return "ca-app-pub-3940256099942544/2435281174"
        #endif
    }
    
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
        }
        banner.load(GADRequest())
        return banner
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
#endif

// MARK: - 標準内蔵バナー枠（AdMob SDK未導入時やオフライン時でも崩れず表示される50ptバナー）
struct FallbackBannerView: View {
    var onTapUpgrade: (() -> Void)?
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            onTapUpgrade?()
        }) {
            HStack(spacing: 10) {
                // AD バッジ
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

