import Foundation

struct HabitItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var imageName: String // Assets内の画像名
    var targetDaysOfWeek: [Int] // 1: 日曜, 2: 月曜 ... 7: 土曜
    var notifyBeforeMinutes: Int? // nilなら通知オフ。0: 時間通り, 10: 10分前 など
    var targetHour: Int // 例: 8 (朝8時)
    var targetMinute: Int // 例: 0 (0分)
    var completedDates: Set<String> = [] // "yyyy-MM-dd" 形式で達成日を記録
    
    // 今日がターゲット曜日かどうか判定
    var isTargetToday: Bool {
        return isTargetOn(date: Date())
    }
    
    // 指定日がターゲット曜日かどうか判定
    func isTargetOn(date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return targetDaysOfWeek.contains(weekday)
    }
    
    // 今日達成済みかどうか
    var isCompletedToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        return completedDates.contains(todayStr)
    }
    
    // 特定の日付が達成済みかどうか
    func isCompleted(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        return completedDates.contains(dateStr)
    }
}

