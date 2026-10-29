import SwiftUI
import UIKit

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
                                    Text("Analyzing multi-day trends with \(geminiClient.currentActiveModel)...")
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
        .onAppear {
            healthKit.fetchAllTodayData()
            healthKit.fetchHistoricalDailySummaries(days: 60)
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
            
            HStack(spacing: 8) {
                if !messages.isEmpty && !geminiClient.isGenerating {
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            messages.removeAll()
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color(white: 0.14))
                            .cornerRadius(6)
                    }
                }
                
                Text(geminiClient.currentActiveModel)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.12))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private func initialPromptCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COMPREHENSIVE REVIEW & ADVICE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)
            
            Text("本日のリアルタイム進捗（現在時刻ペース）に加え、過去7日〜30日間のカロリー収支・PFC栄養推移・運動（ワークアウト種目・歩数・移動距離）・睡眠時間・体組成（体重・体脂肪率・安静時心拍数）および習慣の定着率を総合的に分析し、今のあなたに最適な食事・運動・休養の工夫をアドバイスします。")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.65))
                .lineSpacing(4)
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                runDiagnosis(customPrompt: nil)
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("過去データも含めて総合的に振り返る")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(8)
            }
            
            Text("※本機能は一般的な生活習慣・栄養・運動管理のセルフチェックを目的としており、医師による医学的助言ではありません。実行時はご自身のAPIキーを用いて当日および過去期間のヘルスケア・習慣集計サマリーが Google Gemini API へ送信されます。")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.45))
                .lineSpacing(3)
            
            // 栄養基準の公式出典リンク（Guideline 1.4.1 対策）
            HStack(spacing: 12) {
                if let mhlwURL = URL(string: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/eiyou/syokuji_kijyun.html") {
                    Link(destination: mhlwURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 9))
                            Text("出典: 厚生労働省「日本人の食事摂取基準」")
                                .font(.system(size: 9, weight: .medium))
                                .underline()
                        }
                        .foregroundColor(Color(white: 0.55))
                    }
                }
                if let whoURL = URL(string: "https://www.who.int/news-room/fact-sheets/detail/healthy-diet") {
                    Link(destination: whoURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 9))
                            Text("WHO Healthy Diet")
                                .font(.system(size: 9, weight: .medium))
                                .underline()
                        }
                        .foregroundColor(Color(white: 0.55))
                    }
                }
            }
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
            TextField("食事・運動・睡眠や週間トレンドについて相談する...", text: $userQuestion)
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
            
            Text("AIアドバイザーは、お手持ちの Gemini API キーを入力して利用できるオプショナル機能です。\n\n画面右下の「SETTINGS」タブ内の「AI ADVISOR API KEY」欄にご自身のAPIキーを設定すると、当日・過去日のヘルスケア推移や運動・睡眠・習慣データに基づいた総合分析と個別相談が有効になります。\n（習慣管理・カレンダー・ヘルスケア収支・ウィジェット等の主機能はAPIキーなしでそのままご利用いただけます）")
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
    
    // MARK: - 総合診断・相談の実行（当日＋直近7日間日別ログ＋30日トレンド＋運動・睡眠・習慣＋会話履歴）
    private func runDiagnosis(customPrompt: String?) {
        let isFullReview = (customPrompt == nil)
        let displayUserText = customPrompt ?? "過去日の推移も含めて、現在の規律・栄養・運動・睡眠バランスを総合的に振り返ってください。"
        
        // 今回の発言を追加する前の直近会話履歴を取得（マルチターン文脈用）
        let priorHistory = messages.map { (isUser: $0.isUser, text: $0.text) }
        messages.append(ChatMessage(isUser: true, text: displayUserText, timestamp: Date()))
        
        let contextText = buildComprehensiveContext(requestText: displayUserText)
        let systemPrompt = isFullReview
            ? KnowledgeBase.dailyReviewSystemPrompt
            : KnowledgeBase.directQuestionSystemPrompt
        
        Task {
            do {
                let reply = try await geminiClient.generateCoachingAdvice(
                    systemPrompt: systemPrompt,
                    userContext: contextText,
                    conversationHistory: priorHistory
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
    
    // MARK: - 当日＋過去7日＋過去30日トレンド＋ワークアウト＋睡眠＋習慣の総合コンテキスト生成
    private func buildComprehensiveContext(requestText: String) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 現在時刻・時間帯
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "yyyy-MM-dd (E) HH:mm"
        let currentDateTimeStr = timeFormatter.string(from: now)
        let currentHour = calendar.component(.hour, from: now)
        let timePeriodNote: String
        switch currentHour {
        case 4..<11:
            timePeriodNote = "朝の段階（まだ朝食〜午前中の途中経過）"
        case 11..<16:
            timePeriodNote = "昼〜午後の段階（まだ1日の食事・活動の途中経過であり、これから夕食等が残っている時間帯）"
        case 16..<21:
            timePeriodNote = "夕方〜夜の段階（夕食前後または1日の仕上げの時間帯）"
        default:
            timePeriodNote = "夜〜1日の締めくくりの段階"
        }
        
        // 2. 本日のリアルタイム状況
        let intake = healthKit.todayIntakeCalories
        let activeBurned = healthKit.todayActiveCalories
        let basalBurned = healthKit.todayBasalCalories
        let burned = healthKit.todayTotalBurnedCalories
        let p = healthKit.todayProtein
        let f = healthKit.todayFat
        let c = healthKit.todayCarbs
        let macroKcal = p * 4.0 + f * 9.0 + c * 4.0
        let todayPFCRatioStr: String = {
            guard macroKcal > 0 else { return "PFC未記録" }
            let pPct = Int((p * 4.0 / macroKcal * 100.0).rounded())
            let fPct = Int((f * 9.0 / macroKcal * 100.0).rounded())
            let cPct = max(0, 100 - pPct - fPct)
            return "P:\(pPct)% / F:\(fPct)% / C:\(cPct)%"
        }()
        
        let sleepTodayStr = healthKit.lastNightSleepHours > 0 ? String(format: "%.1f 時間", healthKit.lastNightSleepHours) : "未記録"
        let weightStr = healthKit.latestWeight > 0 ? String(format: "%.1f kg", healthKit.latestWeight) : "未記録"
        let bodyFatStr = healthKit.latestBodyFat > 0 ? String(format: "%.1f %%", healthKit.latestBodyFat) : "未記録"
        let restingHRStr = healthKit.latestRestingHeartRate > 0 ? "\(Int(healthKit.latestRestingHeartRate.rounded())) bpm" : "未記録"
        let distanceTodayStr = healthKit.todayDistanceKm > 0 ? String(format: "%.2f km", healthKit.todayDistanceKm) : "0 km"
        let exerciseTodayStr = healthKit.todayExerciseMinutes > 0 ? "\(Int(healthKit.todayExerciseMinutes.rounded())) 分" : "0 分"
        
        let completedHabits = habitManager.habits.filter { $0.isCompletedToday }.map { $0.title }
        let uncompletedHabits = habitManager.habits.filter { $0.isTargetToday && !$0.isCompletedToday }.map { $0.title }
        
        // 3. 直近7日間（昨日〜7日前）の日別詳細ログ
        let shortDayFormatter = DateFormatter()
        shortDayFormatter.locale = Locale(identifier: "ja_JP")
        shortDayFormatter.dateFormat = "M/d(E)"
        
        var past7Lines: [String] = []
        for offset in 1...7 {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let s = healthKit.summary(for: d)
            let dayLabel = shortDayFormatter.string(from: d)
            
            let intakePart = s.intakeCalories > 0 ? "摂取\(Int(s.intakeCalories))kcal" : "摂取:未記録"
            let burnedPart = s.totalBurned > 0 ? "消費\(Int(s.totalBurned))kcal" : "消費:未記録"
            let netPart = (s.intakeCalories > 0 && s.totalBurned > 0)
                ? "収支\(s.netBalance > 0 ? "+" : "")\(Int(s.netBalance))kcal"
                : "収支:未確定"
            let pfcPart = (s.protein + s.fat + s.carbs) > 0
                ? "P:\(Int(s.protein))g F:\(Int(s.fat))g C:\(Int(s.carbs))g"
                : "PFC:未記録"
            let movePart = s.steps > 0
                ? "\(s.steps)歩(\(String(format: "%.1f", s.distanceKm))km/運動\(Int(s.exerciseMinutes))分)"
                : "歩数:未記録"
            let sleepPart = s.sleepHours > 0 ? String(format: "睡眠%.1fh", s.sleepHours) : "睡眠:未記録"
            let weightPart = s.weight > 0 ? String(format: "体重%.1fkg", s.weight) : ""
            let habitPart = habitManager.habits.isEmpty ? "" : "習慣\(Int((habitManager.completionRatio(on: d) * 100).rounded()))%"
            
            let extras = [weightPart, habitPart].filter { !$0.isEmpty }.joined(separator: " | ")
            let line = "- \(dayLabel): \(intakePart) / \(burnedPart) (\(netPart)) | \(pfcPart) | \(movePart) | \(sleepPart)\(extras.isEmpty ? "" : " | " + extras)"
            past7Lines.append(line)
        }
        
        // 4. 直近14日間のワークアウト（運動種目・時間・消費エネルギー）履歴
        let cutoff14DaysStr: String = {
            if let d14 = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now)) {
                return healthKit.dateKey(for: d14)
            }
            return ""
        }()
        let recent14Workouts = healthKit.recentWorkouts
            .filter { $0.dateString >= cutoff14DaysStr }
            .prefix(10)
        let workoutSectionText: String
        if recent14Workouts.isEmpty {
            workoutSectionText = "- 直近14日間の個別ワークアウト記録なし（日常の歩数・アクティブ消費カロリーを参照）"
        } else {
            workoutSectionText = recent14Workouts.map { w in
                let kcalText = w.energyBurnedKcal > 0 ? " / \(w.energyBurnedKcal) kcal" : ""
                return "- \(w.dateString) \(w.startTimeString): \(w.activityName)（\(w.durationMinutes)分\(kcalText)）"
            }.joined(separator: "\n")
        }
        
        // 5. 過去30日間の中長期トレンド集計（昨日〜30日前）
        let past30Summaries: [DailyHealthSummary] = (1...30).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return healthKit.summary(for: d)
        }
        
        let intakeDays = past30Summaries.filter { $0.intakeCalories > 0 }
        let burnedDays = past30Summaries.filter { $0.totalBurned > 0 }
        let pairedCalDays = past30Summaries.filter { $0.intakeCalories > 0 && $0.totalBurned > 0 }
        let macroDays = past30Summaries.filter { ($0.protein + $0.fat + $0.carbs) > 0 }
        let stepDays = past30Summaries.filter { $0.steps > 0 }
        let sleepDays = past30Summaries.filter { $0.sleepHours > 0 }
        let hrDays = past30Summaries.filter { $0.restingHeartRate > 0 }
        let weightDaysChronological = past30Summaries.reversed().filter { $0.weight > 0 }
        let fatDaysChronological = past30Summaries.reversed().filter { $0.bodyFatPercentage > 0 }
        
        var trendLines: [String] = []
        if !intakeDays.isEmpty {
            let avgIntake = Int(intakeDays.map { $0.intakeCalories }.reduce(0, +) / Double(intakeDays.count))
            trendLines.append("- 平均摂取カロリー（記録あり\(intakeDays.count)日平均）: \(avgIntake) kcal/日")
        } else {
            trendLines.append("- 過去30日間の摂取カロリー記録: なし")
        }
        
        if !burnedDays.isEmpty {
            let avgBurned = Int(burnedDays.map { $0.totalBurned }.reduce(0, +) / Double(burnedDays.count))
            trendLines.append("- 平均消費カロリー（記録あり\(burnedDays.count)日平均）: \(avgBurned) kcal/日")
        }
        
        if !pairedCalDays.isEmpty {
            let avgNet = Int(pairedCalDays.map { $0.netBalance }.reduce(0, +) / Double(pairedCalDays.count))
            let underCount = pairedCalDays.filter { $0.netBalance <= 0 }.count
            trendLines.append("- 平均カロリー収支（両方記録あり\(pairedCalDays.count)日平均）: \(avgNet > 0 ? "+" : "")\(avgNet) kcal/日（消費≧摂取の日数: \(underCount)/\(pairedCalDays.count)日）")
        }
        
        if !macroDays.isEmpty {
            let avgP = macroDays.map { $0.protein }.reduce(0, +) / Double(macroDays.count)
            let avgF = macroDays.map { $0.fat }.reduce(0, +) / Double(macroDays.count)
            let avgC = macroDays.map { $0.carbs }.reduce(0, +) / Double(macroDays.count)
            let totalK = avgP * 4.0 + avgF * 9.0 + avgC * 4.0
            if totalK > 0 {
                let pPct = Int((avgP * 4.0 / totalK * 100.0).rounded())
                let fPct = Int((avgF * 9.0 / totalK * 100.0).rounded())
                let cPct = max(0, 100 - pPct - fPct)
                trendLines.append(String(format: "- 平均PFCバランス（%d日平均）: P %.1fg (%d%%) / F %.1fg (%d%%) / C %.1fg (%d%%)", macroDays.count, avgP, pPct, avgF, fPct, avgC, cPct))
            }
        }
        
        if !stepDays.isEmpty {
            let avgSteps = stepDays.map { $0.steps }.reduce(0, +) / stepDays.count
            let over8000 = stepDays.filter { $0.steps >= 8000 }.count
            trendLines.append("- 平均歩数（\(stepDays.count)日平均）: \(avgSteps) 歩/日（8,000歩以上達成: \(over8000)日）")
        }
        
        if !sleepDays.isEmpty {
            let avgSleep = sleepDays.map { $0.sleepHours }.reduce(0, +) / Double(sleepDays.count)
            trendLines.append(String(format: "- 平均睡眠時間（%d日平均）: %.1f 時間/日", sleepDays.count, avgSleep))
        } else {
            trendLines.append("- 過去30日間の睡眠記録: 未記録")
        }
        
        if !hrDays.isEmpty {
            let avgHR = Int((hrDays.map { $0.restingHeartRate }.reduce(0, +) / Double(hrDays.count)).rounded())
            trendLines.append("- 平均安静時心拍数（\(hrDays.count)日平均）: \(avgHR) bpm")
        }
        
        if let firstW = weightDaysChronological.first, let lastW = weightDaysChronological.last {
            let endVal = healthKit.latestWeight > 0 ? healthKit.latestWeight : lastW.weight
            let diff = endVal - firstW.weight
            let sign = diff > 0 ? "+" : ""
            trendLines.append(String(format: "- 体重推移（過去30日内 %@ ➔ 最新）: %.1f kg ➔ %.1f kg (%@%.1f kg)", firstW.dateString, firstW.weight, endVal, sign, diff))
        }
        
        if let firstBF = fatDaysChronological.first, let lastBF = fatDaysChronological.last {
            let endBF = healthKit.latestBodyFat > 0 ? healthKit.latestBodyFat : lastBF.bodyFatPercentage
            let diff = endBF - firstBF.bodyFatPercentage
            let sign = diff > 0 ? "+" : ""
            trendLines.append(String(format: "- 体脂肪率推移（過去30日内 %@ ➔ 最新）: %.1f%% ➔ %.1f%% (%@%.1f%%)", firstBF.dateString, firstBF.bodyFatPercentage, endBF, sign, diff))
        }
        
        // 6. 登録習慣の過去28日間定着率＆連続達成ストリーク
        let last28DateKeys: Set<String> = Set((0..<28).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return healthKit.dateKey(for: d)
        })
        
        let habitHistoryText: String
        if habitManager.habits.isEmpty {
            habitHistoryText = "- 登録されている習慣はまだありません"
        } else {
            habitHistoryText = habitManager.habits.map { habit in
                let count28 = habit.completedDates.filter { last28DateKeys.contains($0) }.count
                let pct = Int((Double(count28) / 28.0 * 100.0).rounded())
                let streak = currentStreak(for: habit)
                let todayStatus = habit.isCompletedToday ? "本日達成済" : (habit.isTargetToday ? "本日未達成" : "本日対象外曜日")
                return "- 「\(habit.title)」: 過去28日で \(count28)/28日 (\(pct)%) 達成 | 現在の連続記録 \(streak)日 | \(todayStatus)"
            }.joined(separator: "\n")
        }
        
        return """
        【1. 現在日時・時間帯】
        - 現在日時: \(currentDateTimeStr)（\(timePeriodNote)）

        【2. 本日（当日）のリアルタイム記録（Apple HealthKit & 習慣）】
        - 現在の摂取カロリー: \(intake > 0 ? "\(Int(intake)) kcal" : "0 kcal（未記録または食事前）")
        - 現在の消費カロリー合計: \(Int(burned)) kcal（活動 \(Int(activeBurned)) kcal + 基礎代謝 \(Int(basalBurned)) kcal / 現時点収支: \(Int(intake - burned)) kcal）
        - 本日のPFC実量・比率: タンパク質 \(String(format: "%.1f", p))g / 脂質 \(String(format: "%.1f", f))g / 炭水化物 \(String(format: "%.1f", c))g（\(todayPFCRatioStr)）
        - 本日の歩数・距離・運動時間: \(healthKit.todaySteps) 歩 / 移動距離 \(distanceTodayStr) / エクササイズ \(exerciseTodayStr)
        - 昨夜〜今朝の睡眠時間: \(sleepTodayStr)
        - 最新の体組成・コンディション: 体重 \(weightStr) / 体脂肪率 \(bodyFatStr) / 安静時心拍数 \(restingHRStr)
        - 本日達成済みの習慣: \(completedHabits.isEmpty ? "まだなし" : completedHabits.joined(separator: ", "))
        - 本日未達成の習慣: \(uncompletedHabits.isEmpty ? "なし（すべて達成または未登録）" : uncompletedHabits.joined(separator: ", "))

        【3. 直近7日間（昨日〜7日前）の日別推移ログ】
        \(past7Lines.joined(separator: "\n"))

        【4. 直近14日間のワークアウト（運動種目）履歴】
        \(workoutSectionText)

        【5. 過去30日間の中長期トレンド集計】
        \(trendLines.joined(separator: "\n"))

        【6. 各習慣の過去28日間定着率・連続達成記録】
        \(habitHistoryText)

        【ユーザーからの今回のリクエスト】
        \(requestText)
        """
    }
    
    // 個別習慣の現在の連続達成日数（ストリーク）を算出
    private func currentStreak(for habit: HabitItem) -> Int {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        let startOffset = habit.isCompletedToday ? 0 : 1
        
        for offset in startOffset..<365 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let key = healthKit.dateKey(for: date)
            if habit.isCompleted(on: key) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}
