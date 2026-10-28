import SwiftUI

struct HabitTabView: View {
    @ObservedObject var habitManager = HabitManager.shared
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // ヘッダー＆本日の達成率サマリー
                headerSection()
                
                // 1. 習慣ヒートマップ（過去5週間の達成度推移）
                DisciplineHeatmapView()
                
                // 2. 本日の習慣カード一覧＆追加ボタン
                HabitTrackerSection()
                
                // 3. 習慣別・直近7日間の達成マトリクス
                weeklyHabitMatrixSection()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func headerSection() -> some View {
        let ratio = habitManager.todayCompletionRatio
        let percent = Int(ratio * 100)
        
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HABIT ARCHITECTURE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(4)
                    .foregroundColor(Color(white: 0.5))
                Text("DAILY ROUTINE & STREAKS")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.45))
                Text("\(percent)%")
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - 習慣別・直近7日間の達成マトリクス
    private func weeklyHabitMatrixSection() -> some View {
        let last7Days = getLast7Days()
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("7-DAY HABIT BREAKDOWN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(white: 0.5))
            
            VStack(spacing: 12) {
                // 曜日ヘッダー行
                HStack {
                    Text("HABIT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(last7Days, id: \.self) { date in
                        Text(shortDayLabel(for: date))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Calendar.current.isDateInToday(date) ? .white : Color(white: 0.45))
                            .frame(width: 24)
                    }
                }
                
                Divider().background(Color(white: 0.15))
                
                ForEach(habitManager.habits) { habit in
                    HStack {
                        Text(habit.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.85))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(last7Days, id: \.self) { date in
                            let done = habit.isCompleted(on: date)
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(done ? Color.white : Color(white: 0.12))
                                    .frame(width: 18, height: 18)
                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(width: 24)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func getLast7Days() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }
    
    private func shortDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
