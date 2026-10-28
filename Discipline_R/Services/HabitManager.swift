import Foundation
import UIKit
import UserNotifications
import Combine

final class HabitManager: ObservableObject {
    static let shared = HabitManager()
    
    @Published var habits: [HabitItem] = []
    private let storageKey = "discipline_saved_habits_v1"
    
    // Assetsに登録されている30種類の背景画像リスト
    let presetImages: [(name: String, label: String)] = [
        ("Gemini_Generated_Image_1e3dfw1e3dfw1e3d", "Habit 01"),
        ("Gemini_Generated_Image_21f13g21f13g21f1", "Habit 02"),
        ("Gemini_Generated_Image_41i4ij41i4ij41i4", "Habit 03"),
        ("Gemini_Generated_Image_42qcr42qcr42qcr4", "Habit 04"),
        ("Gemini_Generated_Image_5p1d955p1d955p1d", "Habit 05"),
        ("Gemini_Generated_Image_5y6ovv5y6ovv5y6o", "Habit 06"),
        ("Gemini_Generated_Image_63gec163gec163ge", "Habit 07"),
        ("Gemini_Generated_Image_6fopdc6fopdc6fop", "Habit 08"),
        ("Gemini_Generated_Image_8v62de8v62de8v62", "Habit 09"),
        ("Gemini_Generated_Image_9i4lfb9i4lfb9i4l", "Habit 10"),
        ("Gemini_Generated_Image_ab8z45ab8z45ab8z", "Habit 11"),
        ("Gemini_Generated_Image_aoffrxaoffrxaoff", "Habit 12"),
        ("Gemini_Generated_Image_c5v6zrc5v6zrc5v6", "Habit 13"),
        ("Gemini_Generated_Image_d64v00d64v00d64v", "Habit 14"),
        ("Gemini_Generated_Image_e1r6bee1r6bee1r6", "Habit 15"),
        ("Gemini_Generated_Image_f0z04ff0z04ff0z0", "Habit 16"),
        ("Gemini_Generated_Image_o4w06to4w06to4w0", "Habit 17"),
        ("Gemini_Generated_Image_ssh1i3ssh1i3ssh1", "Habit 18"),
        ("Gemini_Generated_Image_trcb2ktrcb2ktrcb", "Habit 19"),
        ("Gemini_Generated_Image_u5m3ju5m3ju5m3ju", "Habit 20"),
        ("Gemini_Generated_Image_vge26cvge26cvge2", "Habit 21"),
        ("Gemini_Generated_Image_w2024pw2024pw202", "Habit 22"),
        ("Gemini_Generated_Image_w9297cw9297cw929", "Habit 23"),
        ("Gemini_Generated_Image_w9nf20w9nf20w9nf", "Habit 24"),
        ("Gemini_Generated_Image_x0n88x0n88x0n88x", "Habit 25"),
        ("Gemini_Generated_Image_x3y7r3x3y7r3x3y7", "Habit 26"),
        ("Gemini_Generated_Image_xcvlr6xcvlr6xcvl", "Habit 27"),
        ("Gemini_Generated_Image_y0s24xy0s24xy0s2", "Habit 28"),
        ("Gemini_Generated_Image_z1x4n5z1x4n5z1x4", "Habit 29"),
        ("Gemini_Generated_Image_z7x6b9z7x6b9z7x6", "Habit 30")
    ]
    
    private init() {
        loadHabits()
    }
    
    func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HabitItem].self, from: data) {
            self.habits = decoded
        } else {
            // 初回起動時は空配列（ユーザーが＋ボタンから自由に習慣を作成）
            self.habits = []
        }
    }
    
    func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        // Widget側へ最新状態を同期
        WidgetDataSharer.shared.pushCurrentStateToWidget(healthKit: HealthKitManager.shared, habitManager: self)
    }
    
    func addHabit(_ habit: HabitItem) {
        habits.append(habit)
        saveHabits()
        scheduleHabitNotification(for: habit)
    }
    
    func deleteHabit(id: UUID) {
        removeHabitNotifications(for: id)
        habits.removeAll { $0.id == id }
        saveHabits()
    }
    
    // MARK: - 順番の並び替え
    func moveHabitUp(id: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        HapticManager.shared.selection()
        habits.swapAt(idx, idx - 1)
        saveHabits()
    }
    
    func moveHabitDown(id: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == id }), idx < habits.count - 1 else { return }
        HapticManager.shared.selection()
        habits.swapAt(idx, idx + 1)
        saveHabits()
    }
    
    func toggleCompletion(for id: UUID, on date: Date = Date()) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        if habits[index].completedDates.contains(dateStr) {
            habits[index].completedDates.remove(dateStr)
            HapticManager.shared.impact(style: .light)
        } else {
            habits[index].completedDates.insert(dateStr)
            HapticManager.shared.notification(type: .success)
        }
        saveHabits()
    }
    
    // 今日の習慣達成率 (0.0 〜 1.0)
    var todayCompletionRatio: Double {
        return completionRatio(on: Date())
    }
    
    // 指定日の習慣達成率 (0.0 〜 1.0)
    func completionRatio(on date: Date) -> Double {
        let targetHabits = habits.filter { $0.isTargetOn(date: date) }
        guard !targetHabits.isEmpty else { return 0.0 }
        let completedCount = targetHabits.filter { $0.isCompleted(on: date) }.count
        return Double(completedCount) / Double(targetHabits.count)
    }
    
    // MARK: - 個別習慣の通知スケジューリング
    private func scheduleHabitNotification(for habit: HabitItem) {
        guard let beforeMinutes = habit.notifyBeforeMinutes else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            
            // 指定時刻から beforeMinutes 分を引いた時刻を計算
            var totalMinutes = habit.targetHour * 60 + habit.targetMinute - beforeMinutes
            if totalMinutes < 0 { totalMinutes += 24 * 60 }
            let notifyHour = (totalMinutes / 60) % 24
            let notifyMinute = totalMinutes % 60
            
            for weekday in habit.targetDaysOfWeek {
                let content = UNMutableNotificationContent()
                content.title = "DISCIPLINE / 習慣リマインド"
                if beforeMinutes == 0 {
                    content.body = "「\(habit.title)」の時間です。規律を実行しましょう。"
                } else {
                    content.body = "まもなく（\(beforeMinutes)分後）「\(habit.title)」の時間です。"
                }
                content.sound = .default
                
                var dateComponents = DateComponents()
                dateComponents.weekday = weekday
                dateComponents.hour = notifyHour
                dateComponents.minute = notifyMinute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let identifier = "habit_\(habit.id.uuidString)_day\(weekday)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    private func removeHabitNotifications(for id: UUID) {
        let ids = (1...7).map { "habit_\(id.uuidString)_day\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

