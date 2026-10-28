import Foundation
import StoreKit
import Combine

// MARK: - StoreKit 2 課金管理マネージャー（Pro版: 広告非表示 ¥500 買い切り）
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // App Store Connect に登録する非消耗型（買い切り）課金アイテムの製品ID
    let proProductID = "com.lldkinn9.DisciplineR.pro"
    private let proStorageKey = "discipline_is_pro_purchased_v1"
    
    @Published var isPro: Bool = false {
        didSet {
            UserDefaults.standard.set(isPro, forKey: proStorageKey)
        }
    }
    @Published var proProduct: Product? = nil
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String? = nil
    @Published var statusMessage: String? = nil
    
    // DEBUG環境でApp Store Connect未登録時のシミュレータ検証用ダイアログフラグ
    @Published var showDebugPurchaseSheet: Bool = false
    
    private var updateListenerTask: Task<Void, Never>? = nil
    
    private init() {
        self.isPro = UserDefaults.standard.bool(forKey: proStorageKey)
        self.updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 表示用価格文字列（StoreKit製品情報が取得できていればその価格、未取得時は "¥500"）
    var displayPrice: String {
        return proProduct?.displayPrice ?? "¥500"
    }
    
    // MARK: - 1. 製品情報の取得
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [proProductID])
            self.proProduct = storeProducts.first
        } catch {
            print("⚠️ StoreKit 製品情報の取得失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 2. Pro版の購入処理（¥500 買い切り）
    func purchasePro() async {
        errorMessage = nil
        statusMessage = nil
        
        // 製品情報がまだ読み込まれていない場合は再取得を試行
        if proProduct == nil {
            await loadProducts()
        }
        
        guard let product = proProduct else {
            #if DEBUG
            // シミュレータ・開発環境で StoreKit Configuration 未選択時でも即座に動作検証できるようにする
            showDebugPurchaseSheet = true
            return
            #else
            errorMessage = "現在App Storeから製品情報を取得できません。通信環境をご確認の上、再度お試しください。"
            return
            #endif
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateCustomerProductStatus()
                await transaction.finish()
                HapticManager.shared.notification(type: .success)
                statusMessage = "Discipline Pro へのアップデートが完了しました！"
            case .userCancelled:
                break
            case .pending:
                statusMessage = "購入承認待ちです。承認後に自動的にPro版が有効になります。"
            @unknown default:
                break
            }
        } catch {
            HapticManager.shared.notification(type: .error)
            errorMessage = "購入処理中にエラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 3. 購入の復元（App Store 審査 Guideline 3.1.1 必須要件）
    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        statusMessage = nil
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
            if isPro {
                HapticManager.shared.notification(type: .success)
                statusMessage = "購入履歴を復元し、Discipline Pro を有効化しました。"
            } else {
                statusMessage = "復元可能な購入履歴が見つかりませんでした。"
            }
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 4. 現在の購入権利（Entitlements）の確認
    func updateCustomerProductStatus() async {
        var hasProEntitlement = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == proProductID && transaction.revocationDate == nil {
                    hasProEntitlement = true
                }
            } catch {
                continue
            }
        }
        if hasProEntitlement {
            self.isPro = true
        }
    }
    
    // MARK: - 5. バックグラウンドでのトランザクション更新監視
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.verifyTransactionStatic(result)
                    await MainActor.run {
                        if transaction.productID == "com.lldkinn9.DisciplineR.pro" && transaction.revocationDate == nil {
                            StoreManager.shared.isPro = true
                        }
                    }
                    await transaction.finish()
                } catch {
                    continue
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "トランザクションの署名検証に失敗しました。"])
        case .verified(let safe):
            return safe
        }
    }
    
    nonisolated private static func verifyTransactionStatic<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "トランザクションの署名検証に失敗しました。"])
        case .verified(let safe):
            return safe
        }
    }
    
    #if DEBUG
    // 開発・シミュレータ検証用：ワンタップでPro状態を切り替えるヘルパー
    func completeSimulatedDebugPurchase() {
        HapticManager.shared.notification(type: .success)
        isPro = true
        statusMessage = "[DEBUG] Discipline Pro (¥500) が有効化され、バナー広告が非表示になりました。"
    }
    
    func resetDebugProStatus() {
        isPro = false
        statusMessage = nil
        errorMessage = nil
    }
    #endif
}
