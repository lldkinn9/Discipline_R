import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // 軽いクリック感（タブ切り替え、トグル操作など）
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // 物理的な衝突感（ボタンを押した時、カードを開いた時など）
    // style: .light, .medium, .heavy, .soft, .rigid
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // 結果の通知（習慣達成＝Success、エラー＝Errorなど）
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
