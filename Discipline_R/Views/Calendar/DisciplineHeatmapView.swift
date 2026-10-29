import SwiftUI

// MARK: - 習慣達成度ヒートマップ（個人版アプリ準拠：過去28日分のコンパクト4週グリッド表示）
struct DisciplineHeatmapView: View {
    @ObservedObject var habitManager = HabitManager.shared
    private let columns = Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DISCIPLINE HEATMAP (HABIT)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                HStack(spacing: 4) {
                    Text("LESS")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    levelColor(score: 0.0)
                    levelColor(score: 0.3)
                    levelColor(score: 0.7)
                    levelColor(score: 1.0)
                    Text("MORE")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            // 過去28日分のグリッド表示 (4週 × 7日・中央配置)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(last28Days(), id: \.self) { date in
                    let score = habitManager.completionRatio(on: date)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForScore(score))
                        .frame(width: 14, height: 14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .padding(12)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 1.0 {
            return Color.white // 100% 達成 (純白)
        } else if score >= 0.5 {
            return Color(white: 0.65) // 50% 以上達成
        } else if score > 0.0 {
            return Color(white: 0.3) // 一部達成
        } else {
            return Color(white: 0.12) // 未達成 (濃灰)
        }
    }
    
    private func levelColor(score: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(colorForScore(score))
            .frame(width: 10, height: 10)
    }
    
    private func last28Days() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<28).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }
}

