import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @AppStorage("targetCalories") private var targetCalories: Double = 2200.0
    @AppStorage("targetSteps") private var targetSteps: Int = 8000
    
    // HealthKit一本化: 摂取カロリーとPFC実量はすべてApple HealthKitから取得
    private var currentIntakeCalories: Double {
        return healthKit.todayIntakeCalories
    }
    
    private var currentProtein: Double {
        return healthKit.todayProtein
    }
    
    private var currentFat: Double {
        return healthKit.todayFat
    }
    
    private var currentCarbs: Double {
        return healthKit.todayCarbs
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerView()
                
                // HealthKit Empty State 案内バナー（記録が0件でもレイアウトを崩さず親切に案内）
                if !healthKit.isLoading && !healthKit.hasAnyHealthDataToday {
                    emptyHealthDataBanner()
                }
                
                // 1. 摂取 vs 消費カロリー & 歩数
                energyBalanceSection()
                
                // 2. PFCバランス（厚生労働省・WHO推奨の一般バランス栄養指標）
                pfcBalanceSection()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            HapticManager.shared.impact(style: .medium)
            healthKit.fetchAllTodayData()
            healthKit.fetchHistoricalDailySummaries(days: 60)
        }
    }
    
    private func headerView() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DISCIPLINE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(4)
                    .foregroundColor(Color(white: 0.5))
                Text(formattedToday())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: {
                HapticManager.shared.impact(style: .light)
                healthKit.fetchAllTodayData()
                healthKit.fetchHistoricalDailySummaries(days: 60)
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color(white: 0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    private func emptyHealthDataBanner() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ヘルスケアの記録がまだありません")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Apple「ヘルスケア」アプリに食事（摂取カロリー・PFC）やアクティビティが記録されると、ここに本日のエネルギー収支と栄養バランスが自動的に反映されます。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.6))
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(white: 0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func energyBalanceSection() -> some View {
        let burned = healthKit.todayTotalBurnedCalories
        let intake = currentIntakeCalories
        let netBalance = intake - burned
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("ENERGY BALANCE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(Color(white: 0.5))
            
            if healthKit.isLoading {
                SkeletonView(height: 150, cornerRadius: 12)
            } else {
                VStack(spacing: 18) {
                    // 上段：カロリー収支（NET BALANCE）
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NET CALORIE BALANCE (IN - OUT)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(white: 0.5))
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(netBalance > 0 ? "+\(Int(netBalance))" : "\(Int(netBalance))")
                                    .font(.system(size: 34, weight: .light, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("kcal")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.5))
                            }
                        }
                        Spacer()
                        Text(netBalance <= 0 ? "CALORIE DEFICIT" : "CALORIE SURPLUS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    
                    Divider().background(Color(white: 0.15))
                    
                    // 下段：摂取 / 消費 / 歩数 の3カラム
                    HStack(spacing: 0) {
                        metricColumn(title: "INTAKE (摂取)", value: "\(Int(intake))", unit: "kcal")
                        Spacer()
                        metricColumn(title: "BURNED (消費)", value: "\(Int(burned))", unit: "kcal")
                        Spacer()
                        metricColumn(title: "STEPS (歩数)", value: "\(healthKit.todaySteps)", unit: "/ \(targetSteps)")
                    }
                    
                    Divider().background(Color(white: 0.15))
                    
                    // 曜日別（月〜日）摂取 vs 消費 対比バーチャート
                    weekdayCalorieComparisonCard()
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
    
    // MARK: - 今週（月〜日）の曜日別 カロリー対比チャート
    private func weekdayCalorieComparisonCard() -> some View {
        let weekDays = currentWeekDays()
        let maxCal: Double = max(
            weekDays.map { max($0.intake, $0.burned) }.max() ?? 2500.0,
            2500.0
        )
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WEEKLY INTAKE vs BURNED (MON - SUN)")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                        Text("摂取(IN)")
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.6))
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.38))
                            .frame(width: 8, height: 8)
                        Text("消費(OUT)")
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.6))
                    }
                }
            }
            
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(weekDays, id: \.label) { item in
                    VStack(spacing: 5) {
                        // 差分ラベル
                        let diff = Int(item.intake - item.burned)
                        Text(item.intake == 0 && item.burned == 0 ? "-" : (diff > 0 ? "+\(diff)" : "\(diff)"))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(item.isToday ? .white : Color(white: 0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        
                        // 2本並列バー（左：摂取=白、右：消費=グレー）
                        HStack(alignment: .bottom, spacing: 3) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 7, height: max(3, CGFloat(item.intake / maxCal) * 56))
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(white: 0.38))
                                .frame(width: 7, height: max(3, CGFloat(item.burned / maxCal) * 56))
                        }
                        .frame(height: 58, alignment: .bottom)
                        
                        Text(item.label)
                            .font(.system(size: 9, weight: item.isToday ? .bold : .regular))
                            .foregroundColor(item.isToday ? .white : Color(white: 0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(item.isToday ? Color.white.opacity(0.06) : Color.clear)
                    .cornerRadius(6)
                }
            }
        }
    }
    
    private func currentWeekDays() -> [(label: String, intake: Double, burned: Double, isToday: Bool)] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 月曜始まり
        let today = Date()
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let startOfWeek = cal.date(from: components) else { return [] }
        
        return (0..<7).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let summary = healthKit.summary(for: d)
            let isToday = cal.isDateInToday(d)
            let intake = isToday ? currentIntakeCalories : summary.intakeCalories
            let burned = isToday ? healthKit.todayTotalBurnedCalories : summary.totalBurned
            return (labels[offset], intake, burned, isToday)
        }
    }
    
    private func metricColumn(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 0.45))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.4))
            }
        }
    }
    
    private func pfcBalanceSection() -> some View {
        let p = currentProtein
        let f = currentFat
        let c = currentCarbs
        let totalGrams = max(p + f + c, 1.0)
        
        // カロリー換算比率（P: 4kcal/g, F: 9kcal/g, C: 4kcal/g）
        let pCal = p * 4.0
        let fCal = f * 9.0
        let cCal = c * 4.0
        let totalMacroCal = max(pCal + fCal + cCal, 1.0)
        let hasData = (p + f + c) > 0
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PFC BALANCE (DAILY MACROS)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                Text("SOURCE: APPLE HEALTH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(white: 0.4))
            }
            
            VStack(spacing: 14) {
                macroRow(
                    label: "PROTEIN (タンパク質)",
                    grams: p,
                    ratio: hasData ? (pCal / totalMacroCal) : (p / totalGrams),
                    targetNote: "TARGET 13〜20%"
                )
                macroRow(
                    label: "FAT (脂質)",
                    grams: f,
                    ratio: hasData ? (fCal / totalMacroCal) : (f / totalGrams),
                    targetNote: "TARGET 20〜30%"
                )
                macroRow(
                    label: "CARBS (炭水化物)",
                    grams: c,
                    ratio: hasData ? (cCal / totalMacroCal) : (c / totalGrams),
                    targetNote: "TARGET 50〜65%"
                )
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
    
    private func macroRow(label: String, grams: Double, ratio: Double, targetNote: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.8))
                Spacer()
                Text(targetNote)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(white: 0.45))
                    .padding(.trailing, 6)
                Text(String(format: "%.1fg (%.0f%%)", grams, (grams > 0 ? ratio * 100 : 0)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(grams > 0 ? min(max(ratio, 0), 1) : 0), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date()).uppercased()
    }
}
