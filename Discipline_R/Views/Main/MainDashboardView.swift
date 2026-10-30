import SwiftUI
import UIKit

struct MainDashboardView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @State private var isManualSyncing: Bool = false
    
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // 日曜始まり (SUN - SAT)
        return cal
    }()
    
    private var appVersionLabel: String {
        let shortVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return (shortVer.hasPrefix("v") || shortVer.hasPrefix("V")) ? shortVer : "v\(shortVer)"
    }
    
    // 今週（日曜〜土曜）の7日間データ配列
    private var currentWeekDays: [(date: Date, dayName: String, intake: Int, burned: Int, isToday: Bool)] {
        let dayNames = ["日 (SUN)", "月 (MON)", "火 (TUE)", "水 (WED)", "木 (THU)", "金 (FRI)", "土 (SAT)"]
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1(Sun) ... 7(Sat)
        let daysToSunday = -(weekday - 1)
        let sunday = calendar.date(byAdding: .day, value: daysToSunday, to: calendar.startOfDay(for: today)) ?? today
        
        return (0..<7).compactMap { idx in
            guard let d = calendar.date(byAdding: .day, value: idx, to: sunday) else { return nil }
            let summary = healthKit.summary(for: d)
            let isToday = calendar.isDateInToday(d)
            let intake = Int((isToday ? healthKit.todayIntakeCalories : summary.intakeCalories).rounded())
            let burned = Int((isToday ? healthKit.todayTotalBurnedCalories : summary.totalBurned).rounded())
            return (d, dayNames[idx], intake, burned, isToday)
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // 1. ヘッダー (DISCIPLINE / DAILY OPTIMIZATION & RIGOR + バージョンバッジ)
                headerSectionView()
                
                // 2. 今週のトータル収支 (WEEKLY TOTAL: SUN – SAT)
                weeklySummarySectionView()
                
                // 3. 曜日別の摂取/消費対比バー (DAILY ENERGY BREAKDOWN)
                dailyComparisonSectionView()
                
                // 4. 本日の食事ログ一覧 (TODAY'S MEAL LOG - HealthKit連携)
                mealLogSectionView()
                
                // 5. 本日のPFC比率 3カラムピル (TODAY'S PFC RATIO)
                pfcSectionView()
                
                // 6. 本日の栄養・アクティビティ詳細一覧 (NUTRITION OVERVIEW)
                nutritionOverviewSectionView()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            triggerManualSync()
        }
        .onAppear {
            healthKit.fetchAllTodayData()
            healthKit.fetchHistoricalDailySummaries(days: 60)
        }
    }
    
    private func triggerManualSync() {
        HapticManager.shared.impact(style: .rigid)
        isManualSyncing = true
        healthKit.refreshAllData {
            isManualSyncing = false
        }
    }
    
    // MARK: - 1. ヘッダー
    private func headerSectionView() -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DISCIPLINE")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(2)
                Text("DAILY OPTIMIZATION & RIGOR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(appVersionLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.top, 16)
    }
    
    // MARK: - 2. 今週のサマリー (WEEKLY TOTAL: SUN – SAT)
    private func weeklySummarySectionView() -> some View {
        let days = currentWeekDays
        let totalIntake = days.reduce(0) { $0 + $1.intake }
        let totalBurned = days.reduce(0) { $0 + $1.burned }
        let netBalance = totalIntake - totalBurned
        let syncing = healthKit.isLoading || isManualSyncing
        
        return VStack(spacing: 12) {
            HStack {
                Text("WEEKLY TOTAL (SUN – SAT)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                if syncing {
                    Text("SYNCING...")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("摂取 (INTAKE)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(formatComma(totalIntake))
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("kcal (HealthKit)")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("消費 (BURNED)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(formatComma(totalBurned))
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("kcal (HealthKit)")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Spacer(minLength: 4)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("NET BALANCE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(formatSignedBalance(netBalance))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(netBalance <= 0 ? .white : .gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("kcal")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 3. 各日の摂取/消費対比 (DAILY ENERGY BREAKDOWN)
    private func dailyComparisonSectionView() -> some View {
        let days = currentWeekDays
        
        return VStack(spacing: 12) {
            HStack {
                Text("DAILY ENERGY BREAKDOWN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text("IN: HEALTHKIT / OUT: HEALTHKIT")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                    dailyComparisonRowView(
                        dayName: item.dayName,
                        intake: item.intake,
                        burned: item.burned,
                        isToday: item.isToday
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func dailyComparisonRowView(dayName: String, intake: Int, burned: Int, isToday: Bool) -> some View {
        let progress = min(1.0, max(0.0, Double(intake) / 3000.0))
        
        return HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text(dayName)
                    .font(.system(size: 11, weight: isToday ? .heavy : .bold, design: .monospaced))
                    .foregroundColor(isToday ? .white : .white.opacity(0.8))
                if isToday {
                    Text("●")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 82, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("IN: \(formatComma(intake))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("OUT: \(formatComma(burned))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 5)
                        if progress > 0 {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(5, geo.size.width * CGFloat(progress)), height: 5)
                        }
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 4. 本日の食事ログ一覧 (TODAY'S MEAL LOG - HealthKit)
    private func mealLogSectionView() -> some View {
        let meals = healthKit.todayMeals
        let syncing = healthKit.isLoading || isManualSyncing
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S MEAL LOG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("SOURCE: APPLE HEALTH")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if syncing {
                    Text("SYNCING...")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                } else {
                    HStack(spacing: 8) {
                        Text("\(meals.count) MEALS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(3)
                        
                        Button(action: triggerManualSync) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(2)
                        }
                    }
                }
            }
            
            if meals.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("本日の食事記録はありません")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Apple「ヘルスケア」や食事管理アプリに食事を記録すると、時刻別の摂取カロリーとPFCがここに自動反映されます")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.02))
                .cornerRadius(6)
            } else {
                VStack(spacing: 10) {
                    ForEach(meals) { meal in
                        mealCardRowView(meal: meal)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func mealCardRowView(meal: HealthMealRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 上段: 時刻バッジ・メニュー名・カロリー
            HStack(alignment: .firstTextBaseline) {
                Text(meal.formattedTime)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .cornerRadius(3)
                
                Text(meal.menuName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(Int(meal.calories.rounded()))")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                Text("kcal")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            // 中段: PFCピル
            HStack(spacing: 8) {
                mealMacroChip(label: "P", grams: meal.protein)
                mealMacroChip(label: "F", grams: meal.fat)
                mealMacroChip(label: "C", grams: meal.carbs)
                Spacer()
            }
            
            // 下段: 記録元タグ
            if !meal.sourceTag.isEmpty {
                HStack(spacing: 4) {
                    Text(meal.sourceTag)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func mealMacroChip(label: String, grams: Double) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
            Text("\(Int(grams.rounded()))g")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06))
        .cornerRadius(3)
    }
    
    // MARK: - 5. PFCバランス 3カラムピル (TODAY'S PFC RATIO - 一般栄養バランス基準)
    private func pfcSectionView() -> some View {
        let p = healthKit.todayProtein
        let f = healthKit.todayFat
        let c = healthKit.todayCarbs
        let ratios = calculatePFCPercents(protein: p, fat: f, carbs: c)
        
        return VStack(spacing: 12) {
            HStack {
                Text("TODAY'S PFC RATIO (BALANCE TARGET)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text("Apple Health")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            HStack(spacing: 12) {
                pfcPillView(
                    label: "PROTEIN (P)",
                    grams: Int(p.rounded()),
                    percent: ratios.p,
                    target: "13〜20%"
                )
                pfcPillView(
                    label: "FAT (F)",
                    grams: Int(f.rounded()),
                    percent: ratios.f,
                    target: "20〜30%"
                )
                pfcPillView(
                    label: "CARBS (C)",
                    grams: Int(c.rounded()),
                    percent: ratios.c,
                    target: "50〜65%"
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func pfcPillView(label: String, grams: Int, percent: Int, target: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text("\(grams)g")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(verbatim: "\(percent)%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Text("目標: \(target)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(6)
    }
    
    // MARK: - 6. 本日の栄養・アクティビティサマリー (NUTRITION OVERVIEW)
    private func nutritionOverviewSectionView() -> some View {
        let intake = Int(healthKit.todayIntakeCalories.rounded())
        let burned = Int(healthKit.todayTotalBurnedCalories.rounded())
        let todayBalance = intake - burned
        let p = healthKit.todayProtein
        let f = healthKit.todayFat
        let c = healthKit.todayCarbs
        let ratios = calculatePFCPercents(protein: p, fat: f, carbs: c)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NUTRITION OVERVIEW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text("SOURCE: APPLE HEALTH")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(spacing: 8) {
                nutrientRow(label: "摂取カロリー (Dietary Energy)", value: "\(formatComma(intake)) kcal")
                nutrientRow(label: "消費カロリー (Burned Energy)", value: "\(formatComma(burned)) kcal")
                nutrientRow(label: "本日の収支 (Today's Balance)", value: "\(formatSignedBalance(todayBalance)) kcal")
                nutrientRow(label: "タンパク質 (Protein)", value: "\(Int(p.rounded())) g (\(ratios.p)%)")
                nutrientRow(label: "脂質 (Fat)", value: "\(Int(f.rounded())) g (\(ratios.f)%)")
                nutrientRow(label: "炭水化物 (Carbohydrates)", value: "\(Int(c.rounded())) g (\(ratios.c)%)")
                nutrientRow(label: "本日の歩数 (Steps)", value: "\(formatComma(healthKit.todaySteps)) steps")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func nutrientRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(verbatim: value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - フォーマット＆PFC比率計算ヘルパー
    private func calculatePFCPercents(protein: Double, fat: Double, carbs: Double) -> (p: Int, f: Int, c: Int) {
        let pCal = protein * 4.0
        let fCal = fat * 9.0
        let cCal = carbs * 4.0
        let total = pCal + fCal + cCal
        guard total > 0 else { return (0, 0, 0) }
        let pPct = Int((pCal / total * 100.0).rounded())
        let fPct = Int((fCal / total * 100.0).rounded())
        let cPct = max(0, 100 - pPct - fPct)
        return (pPct, fPct, cPct)
    }
    
    private func formatComma(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatSignedBalance(_ balance: Int) -> String {
        if balance > 0 {
            return "+\(balance)"
        }
        return "\(balance)"
    }
}
