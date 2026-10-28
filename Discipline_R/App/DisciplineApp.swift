import SwiftUI

@main
struct DisciplineApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @AppStorage("discipline_has_accepted_medical_disclaimer") private var hasAcceptedDisclaimer: Bool = false
    
    init() {
        // Dark Mode 強制 & TabBar のすりガラス設定
        UITabBar.appearance().isHidden = true
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(healthKitManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    // 起動時にHealthKit認可リクエスト＆データ同期
                    healthKitManager.requestAuthorization()
                    
                    // 当日のデータを即座にWidgetへ反映させる
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        WidgetDataSharer.shared.pushCurrentStateToWidget(
                            healthKit: healthKitManager,
                            habitManager: HabitManager.shared
                        )
                    }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { !hasAcceptedDisclaimer },
                    set: { if !$0 { hasAcceptedDisclaimer = true } }
                )) {
                    MedicalDisclaimerModalView {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasAcceptedDisclaimer = true
                        }
                    }
                }
        }
    }
}

// MARK: - 初回起動時 医療免責事項モーダル (Guideline 1.4.1 対応)
struct MedicalDisclaimerModalView: View {
    let onAccept: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 28) {
                Spacer()
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.white)
                        Text("MEDICAL DISCLAIMER")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(3)
                            .foregroundColor(.white)
                    }
                    
                    Text("ご利用前の重要なお知らせ（免責事項）")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("本アプリおよびAIアドバイザー機能は、医師や医療従事者による医学的診断・助言・治療を提供するものではありません。日々の生活習慣および栄養管理のセルフチェックを目的としています。体調に異変がある場合は必ず医師にご相談ください。")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(white: 0.88))
                        .lineSpacing(7)
                    
                    Divider()
                        .background(Color.white.opacity(0.15))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.6))
                                .padding(.top, 2)
                            Text("栄養目標およびPFCバランス指標は、厚生労働省「日本人の食事摂取基準」およびWHO等の一般的な栄養ガイドラインに基づくセルフモニタリング指標です。")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.6))
                                .lineSpacing(4)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.6))
                                .padding(.top, 2)
                            Text("Apple ヘルスケア（HealthKit）から取得したデータは端末内での表示・集計およびご自身で設定されたAIアドバイザー機能での振り返りにのみ使用されます。")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.6))
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(22)
                .background(Color(white: 0.07))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                
                Spacer()
                
                Button(action: onAccept) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                        Text("同意してはじめる")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @Namespace private var tabAnimation
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            Group {
                switch selectedTab {
                case 0:
                    MainDashboardView()
                case 1:
                    HabitTabView()
                case 2:
                    CalendarView()
                case 3:
                    AICoachView()
                case 4:
                    SettingsView()
                default:
                    MainDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 60) // TabBar Space
            
            // カスタム Liquid Glass TabBar (ドラッグ＆タップ両対応・拡大縮小エフェクト付き)
            GeometryReader { geo in
                let tabCount: CGFloat = 5
                let barWidth = geo.size.width
                let tabWidth = barWidth / tabCount
                
                ZStack(alignment: .leading) {
                    // スライドする水滴（リキッドカプセル）
                    let currentBaseX = CGFloat(selectedTab) * tabWidth
                    // ドラッグ中であればオフセットを加算（画面端を超えないようクランプ）
                    let rawX = currentBaseX + dragOffset
                    let clampedX = min(max(rawX, 0), barWidth - tabWidth)
                    
                    let isDragging = dragOffset != 0
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isDragging ? 0.35 : 0.22),
                                    Color.white.opacity(isDragging ? 0.15 : 0.06),
                                    Color.white.opacity(isDragging ? 0.25 : 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isDragging ? 0.9 : 0.6),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(isDragging ? 0.7 : 0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isDragging ? 1.5 : 1.0
                                )
                        )
                        .shadow(color: Color.white.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 15 : 8, x: 0, y: 0)
                        .frame(width: tabWidth - 16, height: 50)
                        // ドラッグ中は水滴がぷるんと大きく膨らむ
                        .scaleEffect(isDragging ? 1.18 : 1.0)
                        .offset(x: clampedX + 8)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.65, blendDuration: 0.2), value: dragOffset)
                        .animation(.spring(response: 0.45, dampingFraction: 0.68, blendDuration: 0.2), value: selectedTab)
                    
                    // アイコン並置レイヤー
                    HStack(spacing: 0) {
                        tabButton(icon: "flame", title: "DASHBOARD", index: 0, width: tabWidth, isDragging: isDragging, currentCapsuleX: clampedX)
                        tabButton(icon: "checkmark.circle", title: "HABITS", index: 1, width: tabWidth, isDragging: isDragging, currentCapsuleX: clampedX)
                        tabButton(icon: "calendar", title: "CALENDAR", index: 2, width: tabWidth, isDragging: isDragging, currentCapsuleX: clampedX)
                        tabButton(icon: "sparkles", title: "AI ADVISOR", index: 3, width: tabWidth, isDragging: isDragging, currentCapsuleX: clampedX)
                        tabButton(icon: "slider.horizontal.3", title: "SETTINGS", index: 4, width: tabWidth, isDragging: isDragging, currentCapsuleX: clampedX)
                    }
                }
                .frame(height: 64)
                .background(.ultraThinMaterial)
                .background(Color.black.opacity(0.65))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.05), Color.white.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.9), radius: 20, x: 0, y: 10)
                // ジェスチャー判定（カプセルを引っ張って移動できるようにする）
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let predictedEndX = (CGFloat(selectedTab) * tabWidth) + value.predictedEndTranslation.width
                            let targetIndex = Int(round(predictedEndX / tabWidth))
                            let finalIndex = min(max(targetIndex, 0), Int(tabCount) - 1)
                            
                            if finalIndex != selectedTab {
                                HapticManager.shared.selection()
                                selectedTab = finalIndex
                            }
                        }
                )
            }
            .frame(height: 64)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    private func tabButton(icon: String, title: String, index: Int, width: CGFloat, isDragging: Bool, currentCapsuleX: CGFloat) -> some View {
        // 現在カプセルがどのタブの上を通過しているかによって、文字やアイコンをハイライトさせる
        let tabCenterX = (CGFloat(index) * width) + (width / 2)
        let capsuleCenterX = currentCapsuleX + (width / 2)
        let distance = abs(tabCenterX - capsuleCenterX)
        // カプセルが近くにあるほど 1.0 に近づく
        let proximity = max(0, 1.0 - (distance / width))
        let isHoveredOrSelected = proximity > 0.5
        
        return Button(action: {
            if selectedTab != index {
                HapticManager.shared.selection()
                selectedTab = index
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isHoveredOrSelected ? .semibold : .light))
                    // カプセル通過時にアイコンも少し浮き上がる
                    .scaleEffect(isHoveredOrSelected ? (isDragging ? 1.25 : 1.1) : 0.95)
                Text(title)
                    .font(.system(size: 8, weight: isHoveredOrSelected ? .bold : .regular))
                    .tracking(1)
            }
            .foregroundColor(Color.white.opacity(0.35 + (0.65 * Double(proximity))))
            .frame(width: width, height: 50)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: isHoveredOrSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

