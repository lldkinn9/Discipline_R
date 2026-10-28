import Foundation
import WidgetKit

// MARK: - 週間カロリーウィジェット（日曜〜土曜）の1日分データ構造体
struct WidgetDayCalorieItem: Codable {
    let dateString: String   // "yyyy-MM-dd"
    let weekdayLabel: String // "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"
    let dayNumber: Int       // 25, 26, ...
    let intake: Int          // 摂取カロリー (kcal)
    let burned: Int          // 消費カロリー (kcal)
    let isToday: Bool
    let isFuture: Bool
}

// MARK: - 本体アプリからWidgetへ最新データを橋渡しするクラス
final class WidgetDataSharer {
    static let shared = WidgetDataSharer()
    
    // Xcodeで設定された App Group ID を最優先で使用（仕様書の識別子とも互換同期）
    private let appGroupIDs = [
        "group.com.lldkinn9.Discipline-R",
        "group.com.lldkinn9.DisciplineApp"
    ]
    
    private init() {}
    
    func updateWidgetData(
        streakDays: Int,
        calorieBalance: Int,
        intakeCalories: Int,
        burnedCalories: Int,
        habitProgressPercent: Int,
        weeklyItems: [WidgetDayCalorieItem]
    ) {
        let encodedWeekly = try? JSONEncoder().encode(weeklyItems)
        
        for groupID in appGroupIDs {
            if let sharedDefaults = UserDefaults(suiteName: groupID) {
                sharedDefaults.set(streakDays, forKey: "widget_streak_days")
                sharedDefaults.set(calorieBalance, forKey: "widget_calorie_balance")
                sharedDefaults.set(intakeCalories, forKey: "widget_intake_calories")
                sharedDefaults.set(burnedCalories, forKey: "widget_burned_calories")
                sharedDefaults.set(habitProgressPercent, forKey: "widget_habit_progress")
                if let data = encodedWeekly {
                    sharedDefaults.set(data, forKey: "widget_weekly_calories_v1")
                }
                sharedDefaults.synchronize()
            }
        }
        
        // Widgetのタイムラインを即時リロード
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // HealthKitManager と HabitManager の現在値から一括計算してWidgetを更新するヘルパー
    func pushCurrentStateToWidget(healthKit: HealthKitManager, habitManager: HabitManager) {
        let intake = Int(healthKit.todayIntakeCalories)
        let burned = Int(healthKit.todayTotalBurnedCalories)
        let balance = intake - burned
        let habitPercent = Int(habitManager.todayCompletionRatio * 100.0)
        let streak = calculateCurrentStreak(habitManager: habitManager)
        let weeklyItems = buildCurrentWeekItems(healthKit: healthKit)
        
        updateWidgetData(
            streakDays: streak,
            calorieBalance: balance,
            intakeCalories: intake,
            burnedCalories: burned,
            habitProgressPercent: habitPercent,
            weeklyItems: weeklyItems
        )
    }
    
    // 今週（日曜〜土曜）の7日間カロリーデータを生成
    private func buildCurrentWeekItems(healthKit: HealthKitManager) -> [WidgetDayCalorieItem] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // 日曜始まり (SUN - SAT)
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        
        let weekdayComponent = cal.component(.weekday, from: startOfToday) // 1: Sun ... 7: Sat
        let daysFromSunday = weekdayComponent - 1
        guard let sundayDate = cal.date(byAdding: .day, value: -daysFromSunday, to: startOfToday) else {
            return []
        }
        
        let labels = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return (0..<7).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: sundayDate) else { return nil }
            let dateStr = formatter.string(from: date)
            let dayNum = cal.component(.day, from: date)
            let isToday = cal.isDate(date, inSameDayAs: startOfToday)
            let isFuture = date > startOfToday
            
            let summary = healthKit.summary(for: date)
            let intakeVal = isFuture ? 0 : Int(round(isToday ? healthKit.todayIntakeCalories : summary.intakeCalories))
            let burnedVal = isFuture ? 0 : Int(round(isToday ? healthKit.todayTotalBurnedCalories : summary.totalBurned))
            
            return WidgetDayCalorieItem(
                dateString: dateStr,
                weekdayLabel: labels[offset],
                dayNumber: dayNum,
                intake: intakeVal,
                burned: burnedVal,
                isToday: isToday,
                isFuture: isFuture
            )
        }
    }
    
    private func calculateCurrentStreak(habitManager: HabitManager) -> Int {
        var streak = 0
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var allCompletedDates = Set<String>()
        for habit in habitManager.habits {
            allCompletedDates.formUnion(habit.completedDates)
        }
        
        for dayOffset in 0..<365 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                let dateStr = formatter.string(from: date)
                if allCompletedDates.contains(dateStr) {
                    streak += 1
                } else if dayOffset == 0 {
                    continue
                } else {
                    break
                }
            }
        }
        return streak
    }
}
