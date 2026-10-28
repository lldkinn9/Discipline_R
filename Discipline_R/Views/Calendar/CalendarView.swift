import SwiftUI
import UIKit

struct CalendarView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @ObservedObject var habitManager = HabitManager.shared
    
    @AppStorage("targetSteps") private var targetSteps: Int = 8000
    @AppStorage("targetWeight") private var targetWeight: Double = 68.0
    @AppStorage("targetBodyFat") private var targetBodyFat: Double = 15.0
    
    @State private var currentMonthOffset: Int = 0
    @State private var selectedDate: Date = Date()
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                headerSection()
                
                // 6つの規律スタンプ凡例バー
                stampLegendBar()
                
                // 月間カレンダーグリッド（各日に6種類の達成アイコンを表示）
                calendarGridCard()
                
                // 選択日の詳細カード（カロリー収支・歩数・体重・体脂肪・習慣チェック）
                selectedDayDetailCard()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            healthKit.fetchHistoricalDailySummaries(days: 60)
        }
    }
    
    // MARK: - 1. ヘッダー＆月間達成サマリー
    private func headerSection() -> some View {
        let daysInMonth = generateDaysInMonth().compactMap { $0 }
        let perfectDays = daysInMonth.filter { date in
            date <= Date() && achievedStampsCount(for: date) >= 3
        }.count
        
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DISCIPLINE ARCHIVE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(4)
                    .foregroundColor(Color(white: 0.5))
                Text(monthTitle())
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            
            // 月移動ボタン & GOOD DAYS カウント
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DISCIPLINED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color(white: 0.45))
                    Text("\(perfectDays) DAYS")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 6) {
                    Button(action: {
                        HapticManager.shared.selection()
                        currentMonthOffset -= 1
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(white: 0.12))
                            .cornerRadius(6)
                    }
                    Button(action: {
                        HapticManager.shared.selection()
                        if currentMonthOffset < 0 { currentMonthOffset += 1 }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(currentMonthOffset < 0 ? .white : Color(white: 0.3))
                            .frame(width: 30, height: 30)
                            .background(Color(white: 0.12))
                            .cornerRadius(6)
                    }
                    .disabled(currentMonthOffset >= 0)
                }
            }
        }
    }
    
    // MARK: - 2. 6つの規律スタンプ凡例
    private func stampLegendBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                legendChip(icon: "checkmark.seal.fill", label: "習慣100%")
                legendChip(icon: "flame.fill", label: "摂取<消費")
                legendChip(icon: "figure.walk", label: "目標歩数")
                legendChip(icon: "fork.knife", label: "栄養記録")
                legendChip(icon: "scalemass.fill", label: "目標体重")
                legendChip(icon: "percent", label: "目標体脂肪")
            }
        }
    }
    
    private func legendChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(white: 0.65))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(white: 0.08))
        .cornerRadius(6)
    }
    
    // MARK: - 3. カレンダーグリッド（各セルに最大6個のミニスタンプ表示）
    private func calendarGridCard() -> some View {
        let days = generateDaysInMonth()
        
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, dateOpt in
                    if let date = dateOpt {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Date()
        let stamps = evaluateStamps(for: date)
        let stampCount = stamps.filter { $0.achieved }.count
        
        return Button(action: {
            HapticManager.shared.selection()
            selectedDate = date
        }) {
            VStack(spacing: 4) {
                // 日付数字
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 12, weight: (isSelected || isToday) ? .bold : .medium, design: .monospaced))
                    .foregroundColor(isSelected ? .black : (isFuture ? Color(white: 0.25) : .white))
                
                // 6つのミニスタンプアイコン (3列 × 2段)
                if !isFuture {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { idx in
                                Image(systemName: stamps[idx].icon)
                                    .font(.system(size: 6.5, weight: .bold))
                                    .foregroundColor(
                                        stamps[idx].achieved
                                        ? (isSelected ? .black : .white)
                                        : (isSelected ? Color.black.opacity(0.18) : Color(white: 0.2))
                                    )
                            }
                        }
                        HStack(spacing: 3) {
                            ForEach(3..<6, id: \.self) { idx in
                                Image(systemName: stamps[idx].icon)
                                    .font(.system(size: 6.5, weight: .bold))
                                    .foregroundColor(
                                        stamps[idx].achieved
                                        ? (isSelected ? .black : .white)
                                        : (isSelected ? Color.black.opacity(0.18) : Color(white: 0.2))
                                    )
                            }
                        }
                    }
                } else {
                    Spacer().frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : (stampCount >= 4 ? Color(white: 0.15) : Color(white: 0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday && !isSelected ? Color.white.opacity(0.7) : Color.clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 4. 選択日の詳細カード（6大指標バッジ＋数値内訳＋習慣チェック）
    private func selectedDayDetailCard() -> some View {
        let summary = healthKit.summary(for: selectedDate)
        let intake = summary.intakeCalories
        let burned = summary.totalBurned
        let balance = intake - burned
        let stamps = evaluateStamps(for: selectedDate)
        let targetHabits = habitManager.habits.filter { $0.isTargetOn(date: selectedDate) }
        let hasAnyHealthRecord = intake > 0 || burned > 0 || summary.steps > 0 || summary.weight > 0 || summary.bodyFatPercentage > 0
        
        return VStack(alignment: .leading, spacing: 18) {
            // 日付タイトル
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELECTED DAY REPORT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.45))
                    Text(formattedFullDate(selectedDate))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                let achievedCount = stamps.filter { $0.achieved }.count
                Text("\(achievedCount) / 6 STAMPS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .cornerRadius(6)
            }
            
            // 6つの規律スタンプ達成ステータス一覧（2列×3段）
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(stamps, id: \.title) { stamp in
                    HStack(spacing: 8) {
                        Image(systemName: stamp.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(stamp.achieved ? .black : Color(white: 0.4))
                            .frame(width: 24, height: 24)
                            .background(stamp.achieved ? Color.white : Color(white: 0.12))
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stamp.title)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(stamp.achieved ? .white : Color(white: 0.45))
                            Text(stamp.detail)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(white: 0.55))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(Color(white: 0.09))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(stamp.achieved ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
                }
            }
            
            Divider().background(Color(white: 0.15))
            
            // カロリー収支（摂取 vs 消費）
            VStack(alignment: .leading, spacing: 10) {
                Text("CALORIE & BODY METRICS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.45))
                
                if !hasAnyHealthRecord {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                        Text("この日のヘルスケアの記録がまだありません")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.55))
                    }
                    .padding(.bottom, 4)
                }
                
                HStack(spacing: 0) {
                    detailMetricBox(label: "INTAKE (摂取)", value: "\(Int(intake))", unit: "kcal")
                    Spacer()
                    detailMetricBox(label: "BURNED (消費)", value: "\(Int(burned))", unit: "kcal")
                    Spacer()
                    detailMetricBox(label: "NET (収支)", value: balance > 0 ? "+\(Int(balance))" : "\(Int(balance))", unit: "kcal")
                }
            }
            
            // その日の習慣チェックリスト（過去日でもタップでON/OFF切り替え可能）
            if !targetHabits.isEmpty {
                Divider().background(Color(white: 0.15))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("HABITS ON THIS DAY (タップで記録修正)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(white: 0.45))
                    
                    ForEach(targetHabits) { habit in
                        let done = habit.isCompleted(on: selectedDate)
                        Button(action: {
                            habitManager.toggleCompletion(for: habit.id, on: selectedDate)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15))
                                    .foregroundColor(done ? .white : Color(white: 0.4))
                                Text(habit.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(done ? .white : Color(white: 0.6))
                                Spacer()
                                Text(done ? "DONE" : "INCOMPLETE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(done ? .white : Color(white: 0.35))
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(18)
        .background(Color(white: 0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func detailMetricBox(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 0.45))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.45))
            }
        }
    }
    
    // MARK: - 6大規律スタンプの評価ロジック
    struct StampResult {
        let icon: String
        let title: String
        let detail: String
        let achieved: Bool
    }
    
    private func evaluateStamps(for date: Date) -> [StampResult] {
        let summary = healthKit.summary(for: date)
        let intake = summary.intakeCalories
        let burned = summary.totalBurned
        
        // 1. 習慣100%達成
        let habitRatio = habitManager.completionRatio(on: date)
        let habitDone = habitRatio >= 0.99
        
        // 2. カロリーアンダー（摂取 > 0 かつ 摂取 <= 消費）
        let calUnder = (intake > 0 && burned > 0 && intake <= burned)
        
        // 3. 目標歩数クリア
        let stepsDone = summary.steps >= targetSteps
        
        // 4. 栄養・食事記録あり（HealthKit摂取カロリーまたはPFCの記録あり）
        let mealLogged = intake > 0 || (summary.protein + summary.fat + summary.carbs) > 0
        
        // 5. 目標体重クリア（記録があり目標体重以下）
        let weightDone = (summary.weight > 0 && summary.weight <= targetWeight)
        
        // 6. 目標体脂肪率クリア（記録があり目標体脂肪率以下）
        let fatDone = (summary.bodyFatPercentage > 0 && summary.bodyFatPercentage <= targetBodyFat)
        
        return [
            StampResult(icon: "checkmark.seal.fill", title: "習慣100%", detail: "\(Int(habitRatio * 100))% 達成", achieved: habitDone),
            StampResult(icon: "flame.fill", title: "摂取<消費", detail: intake > 0 ? "\(Int(intake - burned)) kcal" : "未記録", achieved: calUnder),
            StampResult(icon: "figure.walk", title: "目標歩数", detail: "\(summary.steps) / \(targetSteps)", achieved: stepsDone),
            StampResult(icon: "fork.knife", title: "栄養記録", detail: mealLogged ? "\(Int(intake)) kcal" : "0 kcal", achieved: mealLogged),
            StampResult(icon: "scalemass.fill", title: "目標体重", detail: summary.weight > 0 ? String(format: "%.1f kg", summary.weight) : "未計測", achieved: weightDone),
            StampResult(icon: "percent", title: "目標体脂肪", detail: summary.bodyFatPercentage > 0 ? String(format: "%.1f %%", summary.bodyFatPercentage) : "未計測", achieved: fatDone)
        ]
    }
    
    private func achievedStampsCount(for date: Date) -> Int {
        return evaluateStamps(for: date).filter { $0.achieved }.count
    }
    
    // MARK: - カレンダー日付生成ヘルパー
    private func targetMonthDate() -> Date {
        Calendar.current.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
    }
    
    private func generateDaysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let targetDate = targetMonthDate()
        guard let range = calendar.range(of: .day, in: .month, for: targetDate),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetDate)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1(Sun)〜7(Sat)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(d)
            }
        }
        return days
    }
    
    private func monthTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: targetMonthDate()).uppercased()
    }
    
    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 (E)"
        return formatter.string(from: date)
    }
}

