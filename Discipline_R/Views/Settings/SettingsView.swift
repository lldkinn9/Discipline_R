import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var geminiClient = GeminiClient.shared
    @ObservedObject var storeManager = StoreManager.shared
    @ObservedObject var healthKit = HealthKitManager.shared
    
    @State private var apiKeyInput: String = ""
    @State private var showSavedToast: Bool = false
    @State private var isSyncingHealth: Bool = false
    @State private var showHealthSyncedToast: Bool = false
    @State private var showingPrivacyPolicySheet: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var showResetDoneToast: Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerView()
                
                // 0. Discipline Pro アップデート（広告非表示・¥500 買い切り）
                proUpgradeSection()
                
                // 1. Gemini API Key (BYOK 設定セクション)
                apiKeySection()
                
                // 2. iOS ヘルスケア連携 (Apple HealthKit ステータス・リアルタイムプレビュー・手動更新・権限確認)
                appleHealthSection()
                
                // 3. 医療免責事項 (Guideline 1.4.1 対応)
                medicalDisclaimerSection()
                
                // 4. プライバシーポリシー & サポート (Guideline 5.1.1 & 5.1.3 対応)
                privacyAndSupportSection()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            apiKeyInput = geminiClient.apiKey
            if geminiClient.hasValidKey && geminiClient.lastDiagnostics == nil {
                Task {
                    _ = try? await geminiClient.fetchAndSelectDynamicModels()
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicySheet) {
            PrivacyPolicySheetView()
        }
    }
    
    private func headerView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CONFIGURATION")
                .font(.system(size: 11, weight: .bold))
                .tracking(4)
                .foregroundColor(Color(white: 0.5))
            Text("SETTINGS")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - 0. Discipline Pro アップデート（¥500 買い切り・広告非表示 / Guideline 3.1.1 準拠）
    private func proUpgradeSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Text("DISCIPLINE PRO (AD-FREE UPGRADE)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Text(storeManager.isPro ? "PRO ACTIVE ✓" : "\(storeManager.displayPrice) / 買い切り")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(storeManager.isPro ? .black : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(storeManager.isPro ? Color.white : Color(white: 0.18))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                if storeManager.isPro {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Discipline Pro アップデート適用済み")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("画面下部のバナー広告はすべて非表示になっています。ご購入ありがとうございます。")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.6))
                        }
                    }
                    
                    #if DEBUG
                    Button(action: {
                        HapticManager.shared.selection()
                        storeManager.resetDebugProStatus()
                    }) {
                        Text("[DEBUG検証用] 無料版（バナー広告表示）の状態に戻す")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .underline()
                    }
                    .padding(.top, 2)
                    #endif
                } else {
                    Text("画面下部のバナー広告を永久に非表示にし、より広い画面でストイックに規律管理へ集中できる Pro版 へアップデートできます（\(storeManager.displayPrice) 買い切り・月額課金なし）。")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.7))
                        .lineSpacing(4)
                    
                    HStack(spacing: 10) {
                        // ¥500 購入ボタン
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            Task {
                                await storeManager.purchasePro()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if storeManager.isPurchasing {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                        .tint(.black)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Text("\(storeManager.displayPrice) で Pro版にアップデート")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        .disabled(storeManager.isPurchasing)
                        
                        // 購入を復元ボタン（App Store 審査 Guideline 3.1.1 必須）
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            Task {
                                await storeManager.restorePurchases()
                            }
                        }) {
                            Text("購入を復元")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(Color(white: 0.16))
                                .cornerRadius(8)
                        }
                        .disabled(storeManager.isPurchasing)
                    }
                }
                
                if let statusMsg = storeManager.statusMessage {
                    Text(statusMsg)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                
                if let errMsg = storeManager.errorMessage {
                    Text(errMsg)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.75))
                }
            }
            .padding(18)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(storeManager.isPro ? Color.white.opacity(0.35) : Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        #if DEBUG
        .alert("Discipline Pro（テスト購入確認）", isPresented: $storeManager.showDebugPurchaseSheet) {
            Button("キャンセル", role: .cancel) {}
            Button("購入する (¥500)") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    storeManager.completeSimulatedDebugPurchase()
                }
            }
        } message: {
            Text("【DEBUG / シミュレータ検証モード】\nDiscipline Pro（広告非表示アップデート: ¥500 買い切り）の購入完了をシミュレートし、画面下部のバナー広告を非表示にしますか？\n（※本番リリース時は Apple StoreKit の標準決済シートが表示されます）")
        }
        #endif
    }
    
    // MARK: - 1. BYOK: Gemini API キー入力セクション（外部課金・購入リンクなし）
    private func apiKeySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI ADVISOR API KEY (OPTIONAL / BYOK)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                Text(geminiClient.hasValidKey ? "ACTIVE" : "NOT SET")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(geminiClient.hasValidKey ? .black : Color(white: 0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(geminiClient.hasValidKey ? Color.white : Color(white: 0.15))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("AIアドバイザー機能（オプショナル）を利用する場合は、お持ちの Gemini API Key を入力してください。キーは端末内にのみ安全に保存されます。")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
                    .lineSpacing(3)
                
                SecureField("Gemini API Key を貼り付け...", text: $apiKeyInput)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color(white: 0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.notification(type: .success)
                        geminiClient.apiKey = apiKeyInput
                        apiKeyInput = geminiClient.apiKey
                        showSavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showSavedToast = false
                        }
                        if geminiClient.hasValidKey {
                            Task {
                                _ = try? await geminiClient.fetchAndSelectDynamicModels()
                            }
                        }
                    }) {
                        Text(showSavedToast ? "SAVED & VERIFYING ✓" : "SAVE API KEY")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    
                    if geminiClient.hasValidKey {
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            Task {
                                _ = try? await geminiClient.fetchAndSelectDynamicModels()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if geminiClient.isDiagnosing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 11))
                                }
                                Text("診断")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.18))
                            .cornerRadius(8)
                        }
                        .disabled(geminiClient.isDiagnosing)
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            apiKeyInput = ""
                            geminiClient.apiKey = ""
                        }) {
                            Text("CLEAR")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.14))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // 多重モデル冗長化チェーン ＆ models.list 動的疎通診断ステータス表示
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(Color(white: 0.15)).padding(.vertical, 2)
                    
                    HStack {
                        Text("FAILOVER CHAIN & MODEL DIAGNOSTICS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Color(white: 0.5))
                        Spacer()
                        if let diag = geminiClient.lastDiagnostics {
                            Text("HTTP \(diag.statusCode) OK (\(diag.availableGenerateModels.count) models)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("・Main: \(geminiClient.primaryModel)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.7))
                    Text("・Sub : \(geminiClient.backupModel)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                    Text("・Reserve (models.list): \(geminiClient.activeReserveModelName)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                    
                    if let diag = geminiClient.lastDiagnostics {
                        Text("疎通確認済モデル例: \(diag.availableGenerateModels.prefix(4).joined(separator: ", "))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .lineLimit(2)
                    } else if let err = geminiClient.lastDiagnosticsError {
                        Text("診断エラー: \(err)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.75))
                    } else if !geminiClient.hasValidKey {
                        Text("※APIキー未設定（AQ...形式および標準キー形式の両方に対応）")
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
            }
            .padding(18)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 2. iOS ヘルスケア連携 (Apple HealthKit)
    private func appleHealthSection() -> some View {
        let statusLabel: String = {
            if !healthKit.isHealthDataAvailable { return "非対応" }
            if healthKit.isLoading || isSyncingHealth { return "同期中..." }
            return healthKit.isAuthorized ? "連携中" : "未連携"
        }()
        let isConnected = healthKit.isHealthDataAvailable && healthKit.isAuthorized
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Text("APPLE HEALTH (iOS ヘルスケア連携)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                }
                
                Spacer()
                
                // 連携ステータスバッジ
                HStack(spacing: 5) {
                    Circle()
                        .fill(isConnected ? Color.white : Color.gray.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isConnected ? .white : Color(white: 0.55))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(white: 0.14))
                .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                // リアルタイムプレビュー
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("HEALTH METRICS (リアルタイムプレビュー)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                        Spacer()
                        if let synced = healthKit.lastSyncedAt {
                            Text("最終更新 \(formattedTime(synced))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(white: 0.45))
                        }
                    }
                    
                    HStack(spacing: 10) {
                        healthPreviewBox(
                            title: "摂取エネルギー",
                            value: "\(Int(healthKit.todayIntakeCalories)) kcal",
                            source: "HealthKit"
                        )
                        healthPreviewBox(
                            title: "消費エネルギー",
                            value: "\(Int(healthKit.todayTotalBurnedCalories)) kcal",
                            source: "HealthKit (活動+基礎)"
                        )
                    }
                    
                    HStack(spacing: 10) {
                        healthPreviewBox(
                            title: "PFC実量 (P / F / C)",
                            value: "P:\(Int(healthKit.todayProtein)) F:\(Int(healthKit.todayFat)) C:\(Int(healthKit.todayCarbs))g",
                            source: "HealthKit"
                        )
                        healthPreviewBox(
                            title: "歩数",
                            value: "\(healthKit.todaySteps) 歩",
                            source: "HealthKit"
                        )
                    }
                }
                
                // アクションボタン群
                VStack(spacing: 10) {
                    // 「最新データ更新」ボタン
                    Button(action: syncLatestHealthData) {
                        HStack(spacing: 6) {
                            if isSyncingHealth {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: showHealthSyncedToast ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text(isSyncingHealth ? "最新データ更新中..." : (showHealthSyncedToast ? "最新データ更新完了 ✓" : "最新データ更新"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    .disabled(isSyncingHealth)
                    
                    // 「iOS設定を開いてアクセス権限を確認」ボタン
                    Button(action: openIOSSettings) {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                                .font(.system(size: 12, weight: .bold))
                            Text("iOS設定を開いてアクセス権限を確認")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(white: 0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                Text("※読み取り項目の個別オン/オフは iOS「設定」＞「アプリ」＞「ヘルスケア」＞「データアクセスとデバイス」＞「Discipline」からも確認・変更できます。")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.42))
                    .lineSpacing(3)
            }
            .padding(18)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func healthPreviewBox(title: String, value: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(source)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(white: 0.09))
        .cornerRadius(8)
    }
    
    private func syncLatestHealthData() {
        HapticManager.shared.impact(style: .medium)
        isSyncingHealth = true
        healthKit.refreshAllData {
            isSyncingHealth = false
            HapticManager.shared.notification(type: .success)
            showHealthSyncedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showHealthSyncedToast = false
            }
        }
    }
    
    private func openIOSSettings() {
        HapticManager.shared.impact(style: .light)
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
    
    // MARK: - 3. 医療免責事項セクション (Guideline 1.4.1 対応)
    private func medicalDisclaimerSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                Text("MEDICAL DISCLAIMER (免責事項)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("本アプリおよびAIアドバイザー機能は、医師や医療従事者による医学的診断・助言・治療を提供するものではありません。日々の生活習慣および栄養管理のセルフチェックを目的としています。体調に異変がある場合は必ず医師にご相談ください。")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.78))
                    .lineSpacing(5)
                
                Divider().background(Color(white: 0.15))
                
                Text("栄養目標およびPFCバランス指標（タンパク質 13〜20%、脂質 20〜30%、炭水化物 50〜65%）は、厚生労働省「日本人の食事摂取基準」およびWHO等の一般的な栄養ガイドラインに基づくセルフモニタリング指標です。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                    .lineSpacing(4)
                
                // 科学的・公的根拠の公式Webリンク (Guideline 1.4.1 出典明示要件対応)
                VStack(alignment: .leading, spacing: 8) {
                    if let mhlwURL = URL(string: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/eiyou/syokuji_kijyun.html") {
                        Link(destination: mhlwURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                Text("参考基準1: 厚生労働省「日本人の食事摂取基準」")
                                    .font(.system(size: 11, weight: .medium))
                                    .underline()
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(Color(white: 0.75))
                        }
                    }
                    
                    if let whoURL = URL(string: "https://www.who.int/news-room/fact-sheets/detail/healthy-diet") {
                        Link(destination: whoURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                Text("参考基準2: WHO (世界保健機関) Healthy Diet")
                                    .font(.system(size: 11, weight: .medium))
                                    .underline()
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(Color(white: 0.75))
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 4. プライバシーポリシー & サポートセクション (Guideline 5.1.1 & 5.1.3 対応)
    private func privacyAndSupportSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                Text("PRIVACY POLICY & SUPPORT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Apple ヘルスケア（HealthKit）から取得した健康データや登録した習慣・APIキーはすべてお使いの端末内にのみ保存され、開発者のサーバーや第三者へ送信・収集・販売されることは一切ありません。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.65))
                    .lineSpacing(4)
                
                Divider().background(Color(white: 0.15))
                
                // アプリ内モーダルでプライバシーポリシー全文を確認
                Button(action: {
                    HapticManager.shared.selection()
                    showingPrivacyPolicySheet = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Text("プライバシーポリシー（アプリ内で全文を表示）")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(white: 0.4))
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider().background(Color(white: 0.15))
                
                // Web版 プライバシーポリシーURL (GitHub Pages)
                if let privacyURL = URL(string: "https://lldkinn9.github.io/Discipline_R/privacy.html") {
                    Link(destination: privacyURL) {
                        HStack {
                            Image(systemName: "safari")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            Text("プライバシーポリシー（Webページを開く）")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.4))
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                Divider().background(Color(white: 0.15))
                
                // Web版 サポートURL (GitHub Pages)
                if let supportURL = URL(string: "https://lldkinn9.github.io/Discipline_R/") {
                    Link(destination: supportURL) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            Text("サポートページ（Webページを開く）")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.4))
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                Divider().background(Color(white: 0.15))
                
                // 端末内データの全消去・リセット (Guideline 5.1.1 データ削除対応)
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.7))
                        Text(showResetDoneToast ? "端末内データをすべて初期化しました ✓" : "アプリ内の保存データ（習慣・APIキー）を初期化")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.7))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                .alert("データの初期化", isPresented: $showingResetConfirmation) {
                    Button("キャンセル", role: .cancel) {}
                    Button("すべて初期化する", role: .destructive) {
                        resetAllLocalData()
                    }
                } message: {
                    Text("アプリ内に保存されている習慣リスト・達成履歴・APIキーをすべて消去し、初期状態に戻します。（Appleヘルスケア内のデータは消去されません）")
                }
            }
            .padding(18)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func resetAllLocalData() {
        HapticManager.shared.notification(type: .success)
        apiKeyInput = ""
        geminiClient.apiKey = ""
        HabitManager.shared.updateAllHabits([])
        showResetDoneToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showResetDoneToast = false
        }
    }
}

// MARK: - アプリ内プライバシーポリシー全文表示シート (Guideline 5.1.1 & 5.1.3 完全準拠)
struct PrivacyPolicySheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    policyCard(
                        title: "1. Apple HealthKit（ヘルスケア）データの取り扱い",
                        bodyText: "本アプリは、ユーザーの明示的な許可を得た上で、Apple HealthKit から以下のデータを読み取ります：\n・歩数（Step Count）\n・アクティブエネルギーおよび安静時消費エネルギー（Active / Basal Energy Burned）\n・摂取エネルギーおよび主要栄養素（Dietary Energy, Protein, Fat, Carbohydrates）\n・体重・体脂肪率（Body Mass, Body Fat Percentage）\n\nこれらのデータは端末内でのエネルギー収支・PFCバランスの表示、ウィジェット表示、およびユーザーが任意で実行するAIアドバイザー機能での振り返りにのみ使用されます。開発者のサーバーへ収集・保存されることは一切なく、広告目的や第三者への販売・提供に使用されることも一切ありません。"
                    )
                    
                    policyCard(
                        title: "2. 習慣データおよびAPIキーの保存について",
                        bodyText: "登録された習慣データおよびユーザーが任意で設定した Gemini API Key は、お使いの iOS 端末内（UserDefaults / App Group）にのみ安全に保存されます。\n\nAIアドバイザー機能（BYOK）をご自身のAPIキーで利用される場合のみ、当日の集計数値が Google Gemini API へ暗号化通信（HTTPS）を介して送信され、アドバイス文の生成に利用されます。"
                    )
                    
                    policyCard(
                        title: "3. 広告表示および Pro版アップデート（App内課金）について",
                        bodyText: "無料版では画面下部にバナー広告が表示されます。設定画面より「Discipline Pro（¥500・買い切り）」へアップデートすることで、バナー広告を永久に非表示にすることができます。決済処理は Apple の StoreKit（App Store決済システム）を通じて安全に行われ、開発者がクレジットカード等の決済情報を直接取得・保持することはありません。"
                    )
                    
                    policyCard(
                        title: "4. 医療免責事項（Medical Disclaimer）",
                        bodyText: "本アプリおよびAIアドバイザー機能は、医師や医療従事者による医学的診断・助言・治療を提供するものではありません。日々の生活習慣および栄養管理のセルフチェックを目的としています。体調に異変がある場合は必ず医師にご相談ください。"
                    )
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("PRIVACY POLICY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func policyCard(title: String, bodyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(bodyText)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.78))
                .lineSpacing(5)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

