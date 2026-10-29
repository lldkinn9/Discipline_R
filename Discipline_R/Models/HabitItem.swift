import Foundation

struct HabitItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var imageName: String // Assets内の画像名
    var targetDaysOfWeek: [Int] // 1: 日曜, 2: 月曜 ... 7: 土曜（空配列 [] の場合は曜日指定なし）
    var notifyBeforeMinutes: Int? = nil // nilなら通知オフ。0: 時間通り, 5: 5分前, 10: 10分前, 30: 30分前
    var targetHour: Int? = nil // nilなら実行時刻未設定。例: 8 (朝8時)
    var targetMinute: Int? = nil // nilなら実行時刻未設定。例: 0 (0分)
    var completedDates: Set<String> = [] // "yyyy-MM-dd" 形式で達成日を記録
    
    // 今日がターゲット対象かどうか判定（曜日未指定の場合は毎日対象として扱う）
    var isTargetToday: Bool {
        return isTargetOn(date: Date())
    }
    
    // 指定日がターゲット対象かどうか判定（曜日未指定の場合は毎日対象として扱う）
    func isTargetOn(date: Date) -> Bool {
        if targetDaysOfWeek.isEmpty {
            return true
        }
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
    
    // "yyyy-MM-dd" 文字列指定での達成判定（ミニヒートマップ等用）
    func isCompleted(on dateString: String) -> Bool {
        return completedDates.contains(dateString)
    }
}

