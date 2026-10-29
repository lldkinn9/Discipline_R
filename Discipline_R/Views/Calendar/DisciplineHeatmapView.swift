import SwiftUI

// MARK: - 習慣達成度ヒートマップ（GitHub Contributions風の濃淡タイル表示）
struct DisciplineHeatmapView: View {
    @ObservedObject var habitManager = HabitManager.shared
    
    // 過去35日分（5週間 × 7日）の日付配列を生成
    private var last35Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<35).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DISCIPLINE HEATMAP (LAST 5 WEEKS)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                HStack(spacing: 4) {
                    Text("LESS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(white: 0.4))
                    ForEach([0.08, 0.3, 0.6, 1.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(level))
                            .frame(width: 8, height: 8)
                    }
                    Text("MORE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(last35Days, id: \.self) { date in
                    let ratio = completionRatio(for: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tileColor(for: ratio))
                            .frame(height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isToday ? Color.white : Color.white.opacity(0.08), lineWidth: isToday ? 1.5 : 0.5)
                            )
                            .overlay(
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 9, weight: ratio > 0.5 ? .bold : .regular, design: .monospaced))
                                    .foregroundColor(ratio > 0.5 ? .black : Color(white: 0.55))
                            )
                    }
                }
            }
            .padding(14)
            .background(Color(white: 0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // 指定日の習慣達成率 (0.0 〜 1.0)
    private func completionRatio(for date: Date) -> Double {
        return habitManager.completionRatio(on: date)
    }
    
    private func tileColor(for ratio: Double) -> Color {
        if ratio <= 0 {
            return Color(white: 0.1)
        } else if ratio < 0.4 {
            return Color.white.opacity(0.3)
        } else if ratio < 0.8 {
            return Color.white.opacity(0.65)
        } else {
            return Color.white
        }
    }
}

