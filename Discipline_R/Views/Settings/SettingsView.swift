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
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            apiKeyInput = geminiClient.apiKey
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
                        showSavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showSavedToast = false
                        }
                    }) {
                        Text(showSavedToast ? "SAVED ✓" : "SAVE API KEY")
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
                            apiKeyInput = ""
                            geminiClient.apiKey = ""
                        }) {
                            Text("CLEAR")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.15))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Text("使用モデル: \(geminiClient.primaryModel) (自動フォールバック対応)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
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
}

