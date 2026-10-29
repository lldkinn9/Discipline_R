import SwiftUI
import UIKit

struct HabitTabView: View {
    @ObservedObject var habitManager = HabitManager.shared
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // 1. ヘッダー（個人版アプリ準拠）
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HABIT & DISCIPLINE")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2)
                        Text("CONSISTENCY & STREAK TRACKING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.top, 16)
                
                // 2. DISCIPLINE HEATMAP (習慣継続グリッド・過去28日間)
                DisciplineHeatmapView()
                
                // 3. HABIT TRACKER (21:9 習慣カード一覧・編集モード・作成ウィザード)
                HabitTrackerSection()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            HapticManager.shared.impact(style: .rigid)
        }
    }
}

