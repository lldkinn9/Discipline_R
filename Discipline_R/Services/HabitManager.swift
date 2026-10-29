import Foundation
import UIKit
import UserNotifications
import Combine

final class HabitManager: ObservableObject {
    static let shared = HabitManager()
    
    @Published var habits: [HabitItem] = []
    private let storageKey = "discipline_saved_habits_v1"
    
    var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // 重複ビジュアルを厳密に排除した全26種類の固有背景画像リスト
    // （既存保存データの後方互換維持のため Assets.xcassets 側のファイル自体は保持）
    let presetImages: [String] = [
        "Gemini_Generated_Image_1e3dfw1e3dfw1e3d", // サッカー
        "Gemini_Generated_Image_21f13g21f13g21f1", // テニス
        "Gemini_Generated_Image_41i4ij41i4ij41i4", // シャワー
        "Gemini_Generated_Image_42qcr42qcr42qcr4", // 瞑想・座禅
        "Gemini_Generated_Image_5p1d955p1d955p1d", // 朝のベランダ・日光
        "Gemini_Generated_Image_5y6ovv5y6ovv5y6o", // ガーデニング・植物
        "Gemini_Generated_Image_63gec163gec163ge", // デスクでの筆記・ジャーナリング
        "Gemini_Generated_Image_6fopdc6fopdc6fop", // 読書
        "Gemini_Generated_Image_8v62de8v62de8v62", // キッチン・部屋の掃除
        "Gemini_Generated_Image_9i4lfb9i4lfb9i4l", // ジム・ダンベルベンチプレス
        "Gemini_Generated_Image_ab8z45ab8z45ab8z", // 夜のPC作業・ワーク
        "Gemini_Generated_Image_aoffrxaoffrxaoff", // 朝食プレート・コーヒー
        "Gemini_Generated_Image_c5v6zrc5v6zrc5v6", // 高タンパク食事（ステーキ＆目玉焼き）
        "Gemini_Generated_Image_d64v00d64v00d64v", // 夜のディナープレート
        "Gemini_Generated_Image_e1r6bee1r6bee1r6", // ランニングシューズの靴紐結び
        "Gemini_Generated_Image_o4w06to4w06to4w0", // 起床・就寝（ベッドサイド）
        "Gemini_Generated_Image_ssh1i3ssh1i3ssh1", // 海沿いのランニング
        "Gemini_Generated_Image_u5m3ju5m3ju5m3ju", // バスケットボール
        "Gemini_Generated_Image_vge26cvge26cvge2", // ボクシング・サンドバッグ
        "Gemini_Generated_Image_w2024pw2024pw202", // 湖畔での縄跳び
        "Gemini_Generated_Image_w9297cw9297cw929", // サプリメント・水分補給
        "Gemini_Generated_Image_w9nf20w9nf20w9nf", // 入浴・湯船リカバリー
        "Gemini_Generated_Image_x0n88x0n88x0n88x", // ピアノ・楽器練習
        "Gemini_Generated_Image_x3y7r3x3y7r3x3y7", // ジムミラー・ボディチェック
        "Gemini_Generated_Image_xcvlr6xcvlr6xcvl", // 屋外ヨガ・ストレッチ
        "Gemini_Generated_Image_y0s24xy0s24xy0s2"  // 室内エアロバイク
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
    
    // 編集モード完了時の一括反映（削除された習慣のローカル通知解除＆並び順更新）
    func updateAllHabits(_ newHabits: [HabitItem]) {
        let newIDs = Set(newHabits.map { $0.id })
        for oldHabit in habits where !newIDs.contains(oldHabit.id) {
            removeHabitNotifications(for: oldHabit.id)
        }
        self.habits = newHabits
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
        guard let beforeMinutes = habit.notifyBeforeMinutes,
              let targetHour = habit.targetHour,
              let targetMinute = habit.targetMinute else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            
            // 指定時刻から beforeMinutes 分を引いた時刻を計算
            var totalMinutes = targetHour * 60 + targetMinute - beforeMinutes
            if totalMinutes < 0 { totalMinutes += 24 * 60 }
            let notifyHour = (totalMinutes / 60) % 24
            let notifyMinute = totalMinutes % 60
            
            let makeContent: () -> UNMutableNotificationContent = {
                let content = UNMutableNotificationContent()
                content.title = "DISCIPLINE / 習慣リマインド"
                if beforeMinutes == 0 {
                    content.body = "「\(habit.title)」の時間です。規律を実行しましょう。"
                } else {
                    content.body = "まもなく（\(beforeMinutes)分後）「\(habit.title)」の時間です。"
                }
                content.sound = .default
                return content
            }
            
            if habit.targetDaysOfWeek.isEmpty {
                // 曜日未指定の場合は毎日指定時刻に通知
                var dateComponents = DateComponents()
                dateComponents.hour = notifyHour
                dateComponents.minute = notifyMinute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let identifier = "habit_\(habit.id.uuidString)_daily"
                let request = UNNotificationRequest(identifier: identifier, content: makeContent(), trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            } else {
                for weekday in habit.targetDaysOfWeek {
                    var dateComponents = DateComponents()
                    dateComponents.weekday = weekday
                    dateComponents.hour = notifyHour
                    dateComponents.minute = notifyMinute
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                    let identifier = "habit_\(habit.id.uuidString)_day\(weekday)"
                    let request = UNNotificationRequest(identifier: identifier, content: makeContent(), trigger: trigger)
                    UNUserNotificationCenter.current().add(request)
                }
            }
        }
    }
    
    private func removeHabitNotifications(for id: UUID) {
        var ids = (1...7).map { "habit_\(id.uuidString)_day\($0)" }
        ids.append("habit_\(id.uuidString)_daily")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

