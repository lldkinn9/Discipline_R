import Foundation

struct ActivityRecord: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    var steps: Int
    var caloriesBurned: Double
    var caloriesIntake: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var workoutMinutes: Int
    var isCompleted: Bool // 1日の規律目標を達成したかどうか
    
    // カロリー収支（摂取 - 消費）
    var calorieBalance: Double {
        return caloriesIntake - caloriesBurned
    }
}
