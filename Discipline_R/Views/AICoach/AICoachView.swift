import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let timestamp: Date
}

struct AICoachView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @ObservedObject var habitManager = HabitManager.shared
    @ObservedObject var geminiClient = GeminiClient.shared
    
    @AppStorage("targetCalories") private var targetCalories: Double = 2200.0
    @AppStorage("targetSteps") private var targetSteps: Int = 8000
    
    @State private var messages: [ChatMessage] = []
    @State private var userQuestion: String = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView()
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            if messages.isEmpty {
                                initialPromptCard()
                            } else {
                                ForEach(messages) { msg in
                                    messageBubble(msg)
                                        .id(msg.id)
                                }
                            }
                            
                            if geminiClient.isGenerating {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Analyzing with \(geminiClient.currentActiveModel)...")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(Color(white: 0.5))
                                }
                                .padding()
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastID = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                inputBar()
            }
            .background(Color.black.ignoresSafeArea())
            .blur(radius: geminiClient.hasValidKey ? 0 : 8)
            .disabled(!geminiClient.hasValidKey)
            
            // BYOK オーバーレイ：APIキー未設定時は説明カードを表示（外部課金・購入リンクなし）
            if !geminiClient.hasValidKey {
                apiKeyRequiredOverlay()
            }
        }
    }
    
    private func headerView() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI ADVISOR")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(4)
                    .foregroundColor(Color(white: 0.5))
                Text("LIFESTYLE & NUTRITION")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Text(geminiClient.currentActiveModel)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(white: 0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(white: 0.12))
                .cornerRadius(4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private func initialPromptCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DAILY REVIEW & ADVICE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)
            
            Text("本日のAppleヘルスケア記録（摂取カロリー・PFCバランス・消費カロリー・歩数）および習慣達成状況を現在時刻と照らし合わせ、今日の進捗ペースの振り返りと残りの食事・生活習慣の工夫をアドバイスします。")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.65))
                .lineSpacing(4)
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                runDiagnosis(customPrompt: nil)
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("今日の規律・栄養バランスを振り返る")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(8)
            }
            
            Text("※本機能は一般的な生活習慣・栄養管理のセルフチェックを目的としており、医師による医学的助言ではありません。")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.45))
        }
        .padding(20)
        .background(Color(white: 0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func messageBubble(_ msg: ChatMessage) -> some View {
        VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {
            Text(msg.isUser ? "YOU" : "ADVISOR")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(white: 0.4))
            
            Text(msg.text)
                .font(.system(size: 14))
                .foregroundColor(msg.isUser ? .black : .white)
                .lineSpacing(5)
                .padding(16)
                .background(msg.isUser ? Color.white : Color(white: 0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(msg.isUser ? 0 : 0.12), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: msg.isUser ? .trailing : .leading)
    }
    
    private func inputBar() -> some View {
        HStack(spacing: 12) {
            TextField("食事の工夫や生活習慣について質問する...", text: $userQuestion)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(12)
                .background(Color(white: 0.08))
                .cornerRadius(8)
            
            Button(action: {
                guard !userQuestion.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                HapticManager.shared.impact(style: .light)
                let q = userQuestion
                userQuestion = ""
                runDiagnosis(customPrompt: q)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(userQuestion.isEmpty ? Color(white: 0.3) : .white)
            }
            .disabled(userQuestion.isEmpty || geminiClient.isGenerating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black)
    }
    
    // MARK: - APIキー未設定時の BYOK 案内オーバーレイ（Guideline 2.1 & 3.1.1 準拠）
    private func apiKeyRequiredOverlay() -> some View {
        VStack(spacing: 18) {
            Image(systemName: "key.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.white)
                .padding(16)
                .background(Color(white: 0.12))
                .clipShape(Circle())
            
            Text("OPTIONAL BYOK FEATURE")
                .font(.system(size: 12, weight: .bold))
                .tracking(3)
                .foregroundColor(.white)
            
            Text("AIアドバイザーは、お手持ちの Gemini API キーを入力して利用できるオプショナル機能です。\n\n画面右下の「SETTINGS」タブ内の「AI ADVISOR API KEY」欄にご自身のAPIキーを設定すると、本日のデータに基づいた振り返りや個別相談が有効になります。\n（習慣管理・カレンダー・ヘルスケア収支・ウィジェット等の主機能はAPIキーなしでそのままご利用いただけます）")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 12)
        }
        .padding(28)
        .background(Color(white: 0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 28)
    }
    
    private func runDiagnosis(customPrompt: String?) {
        let intake = healthKit.todayIntakeCalories
        let burned = healthKit.todayTotalBurnedCalories
        let p = healthKit.todayProtein
        let f = healthKit.todayFat
        let c = healthKit.todayCarbs
        
        // 今日の習慣達成状況
        let completedHabits = habitManager.habits.filter { $0.isCompletedToday }.map { $0.title }
        let uncompletedHabits = habitManager.habits.filter { $0.isTargetToday && !$0.isCompletedToday }.map { $0.title }
        
        // 現在時刻を取得（時間帯に応じたペース評価用）
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "HH:mm"
        let currentTimeStr = timeFormatter.string(from: Date())
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timePeriodNote: String
        switch currentHour {
        case 4..<11:
            timePeriodNote = "朝の段階（まだ朝食〜午前中の途中経過）"
        case 11..<16:
            timePeriodNote = "昼〜午後の段階（まだ1日の食事の途中経過であり、これから夕食等が残っている時間帯）"
        case 16..<21:
            timePeriodNote = "夕方〜夜の段階（夕食前後または1日の仕上げの時間帯）"
        default:
            timePeriodNote = "夜〜1日の締めくくりの段階"
        }
        
        let isFullReview = (customPrompt == nil)
        let displayUserText = customPrompt ?? "今日の規律・栄養バランスを振り返ってください。"
        messages.append(ChatMessage(isUser: true, text: displayUserText, timestamp: Date()))
        
        let contextText = """
        【現在時刻・時間帯】
        - 現在時刻: \(currentTimeStr)（\(timePeriodNote)）

        【本日のヘルスケアデータ（Apple HealthKit）】
        - 目標摂取カロリー: \(Int(targetCalories)) kcal
        - 現在の摂取カロリー: \(Int(intake)) kcal
        - 現在の消費カロリー合計: \(Int(burned)) kcal (収支: \(Int(intake - burned)) kcal)
        - 本日の歩数: \(healthKit.todaySteps) 歩 (目標: \(targetSteps) 歩)
        - PFC実量: タンパク質 \(String(format: "%.1f", p))g / 脂質 \(String(format: "%.1f", f))g / 炭水化物 \(String(format: "%.1f", c))g
        - 達成済みの習慣: \(completedHabits.isEmpty ? "まだなし" : completedHabits.joined(separator: ", "))
        - 未達成の習慣: \(uncompletedHabits.isEmpty ? "なし（すべて達成または未登録）" : uncompletedHabits.joined(separator: ", "))
        
        【ユーザーからのリクエスト】
        \(displayUserText)
        """
        
        let systemPrompt = isFullReview
            ? KnowledgeBase.dailyReviewSystemPrompt
            : KnowledgeBase.directQuestionSystemPrompt
        
        Task {
            do {
                let reply = try await geminiClient.generateCoachingAdvice(
                    systemPrompt: systemPrompt,
                    userContext: contextText
                )
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    messages.append(ChatMessage(isUser: false, text: reply, timestamp: Date()))
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.notification(type: .error)
                    messages.append(ChatMessage(isUser: false, text: "通信エラーが発生しました: \(error.localizedDescription)", timestamp: Date()))
                }
            }
        }
    }
}

