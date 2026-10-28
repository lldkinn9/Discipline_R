import Foundation
import WidgetKit

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
        habitProgressPercent: Int
    ) {
        for groupID in appGroupIDs {
            if let sharedDefaults = UserDefaults(suiteName: groupID) {
                sharedDefaults.set(streakDays, forKey: "widget_streak_days")
                sharedDefaults.set(calorieBalance, forKey: "widget_calorie_balance")
                sharedDefaults.set(intakeCalories, forKey: "widget_intake_calories")
                sharedDefaults.set(burnedCalories, forKey: "widget_burned_calories")
                sharedDefaults.set(habitProgressPercent, forKey: "widget_habit_progress")
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
        
        // 簡易連続達成日数（習慣または規律記録がある日数）
        let streak = calculateCurrentStreak(habitManager: habitManager)
        
        updateWidgetData(
            streakDays: streak,
            calorieBalance: balance,
            intakeCalories: intake,
            burnedCalories: burned,
            habitProgressPercent: habitPercent
        )
    }
    
    private func calculateCurrentStreak(habitManager: HabitManager) -> Int {
        var streak = 0
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // すべての習慣の達成日セットを統合
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
                    // 今日まだ未達成でも昨日まで続いていればカウント継続
                    continue
                } else {
                    break
                }
            }
        }
        return streak
    }
}

