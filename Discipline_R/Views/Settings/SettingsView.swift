import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var geminiClient = GeminiClient.shared
    
    @AppStorage("targetCalories") private var targetCalories: Double = 2200.0
    @AppStorage("targetSteps") private var targetSteps: Int = 8000
    @AppStorage("targetWeight") private var targetWeight: Double = 68.0
    @AppStorage("targetBodyFat") private var targetBodyFat: Double = 15.0
    
    @State private var apiKeyInput: String = ""
    @State private var showSavedToast: Bool = false
    @State private var showingPrivacyPolicySheet: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var showResetDoneToast: Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerView()
                
                // 1. Gemini API Key (BYOK 設定セクション)
                apiKeySection()
                
                // 2. カレンダー6大スタンプ＆1日の規律目標設定
                targetsSection()
                
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
    
    // MARK: - 2. 規律目標値設定（カレンダーの6大スタンプ判定にも連動）
    private func targetsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAILY DISCIPLINE TARGETS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(white: 0.5))
            
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目標摂取カロリー")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(targetCalories)) kcal")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Slider(value: $targetCalories, in: 1200...3500, step: 50)
                        .tint(.white)
                }
                
                Divider().background(Color(white: 0.15))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目標歩数 (カレンダー歩数スタンプ基準)")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(targetSteps) steps")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(targetSteps) },
                            set: { targetSteps = Int($0) }
                        ),
                        in: 3000...20000,
                        step: 500
                    )
                    .tint(.white)
                }
                
                Divider().background(Color(white: 0.15))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目標体重 (カレンダー体重スタンプ基準)")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1f kg", targetWeight))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Slider(value: $targetWeight, in: 40.0...100.0, step: 0.5)
                        .tint(.white)
                }
                
                Divider().background(Color(white: 0.15))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目標体脂肪率 (カレンダー体脂肪スタンプ基準)")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1f %%", targetBodyFat))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Slider(value: $targetBodyFat, in: 8.0...35.0, step: 0.5)
                        .tint(.white)
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
                        Text(showResetDoneToast ? "端末内データをすべて初期化しました ✓" : "アプリ内の保存データ（習慣・APIキー・目標値）を初期化")
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
                    Text("アプリ内に保存されている習慣リスト・達成履歴・APIキー・目標設定値をすべて消去し、初期状態に戻します。（Appleヘルスケア内のデータは消去されません）")
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
        HabitManager.shared.habits = []
        HabitManager.shared.saveHabits()
        targetCalories = 2200.0
        targetSteps = 8000
        targetWeight = 68.0
        targetBodyFat = 15.0
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
                        bodyText: "登録された習慣データ、目標設定値、およびユーザーが任意で設定した Gemini API Key は、お使いの iOS 端末内（UserDefaults / App Group）にのみ安全に保存されます。\n\nAIアドバイザー機能（BYOK）をご自身のAPIキーで利用される場合のみ、当日の集計数値が Google Gemini API へ暗号化通信（HTTPS）を介して送信され、アドバイス文の生成に利用されます。"
                    )
                    
                    policyCard(
                        title: "3. 医療免責事項（Medical Disclaimer）",
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

