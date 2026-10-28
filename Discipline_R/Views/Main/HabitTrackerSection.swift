import SwiftUI

struct HabitTrackerSection: View {
    @ObservedObject var habitManager = HabitManager.shared
    @State private var showingAddHabit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY HABITS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                    Text("本日のターゲット習慣（タップで完了・上下矢印で並び替え）")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.35))
                }
                Spacer()
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    showingAddHabit = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("ADD")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(6)
                }
            }
            
            if habitManager.habits.isEmpty {
                Text("登録されている習慣がありません。右上の「ADD」から習慣を追加してください。")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.4))
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(habitManager.habits.enumerated()), id: \.element.id) { index, habit in
                        HabitImageCardView(
                            habit: habit,
                            isFirst: index == 0,
                            isLast: index == habitManager.habits.count - 1,
                            onToggle: {
                                habitManager.toggleCompletion(for: habit.id)
                            },
                            onMoveUp: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    habitManager.moveHabitUp(id: habit.id)
                                }
                            },
                            onMoveDown: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    habitManager.moveHabitDown(id: habit.id)
                                }
                            },
                            onDelete: {
                                habitManager.deleteHabit(id: habit.id)
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitSheet()
        }
    }
}

// MARK: - 21:9 背景画像付き習慣カード（完了時グレースケール＆暗転アニメーション・上下並び替えボタン付き）
struct HabitImageCardView: View {
    let habit: HabitItem
    let isFirst: Bool
    let isLast: Bool
    let onToggle: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        let completed = habit.isCompletedToday
        
        ZStack(alignment: .leading) {
            // 背景画像レイヤー
            GeometryReader { geo in
                if UIImage(named: habit.imageName) != nil {
                    Image(habit.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .saturation(completed ? 0.0 : 0.85)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(completed ? 0.86 : 0.72),
                                    Color.black.opacity(completed ? 0.78 : 0.38)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    // 画像未配置時のフォールバック（漆黒グラデーション）
                    LinearGradient(
                        colors: [Color(white: 0.12), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            
            // 前面テキスト＆チェックマークレイヤー
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(completed ? Color.white : Color(white: 0.6), lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                            
                            if completed {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 26, height: 26)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(completed ? Color(white: 0.45) : .white)
                                .strikethrough(completed, color: Color(white: 0.45))
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                Label(String(format: "%02d:%02d", habit.targetHour, habit.targetMinute), systemImage: "clock")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(white: 0.65))
                                
                                if let before = habit.notifyBeforeMinutes {
                                    Text(before == 0 ? "定刻通知" : "\(before)分前通知")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color(white: 0.75))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // 右端：上下並び替えボタン
                VStack(spacing: 6) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isFirst ? Color(white: 0.25) : .white)
                            .frame(width: 28, height: 26)
                            .background(Color.black.opacity(0.45))
                            .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isFirst)
                    
                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isLast ? Color(white: 0.25) : .white)
                            .frame(width: 28, height: 26)
                            .background(Color.black.opacity(0.45))
                            .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLast)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 84)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(completed ? Color.white.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 1)
        )
        .contextMenu {
            Button {
                onMoveUp()
            } label: {
                Label("1つ上へ移動", systemImage: "arrow.up")
            }
            Button {
                onMoveDown()
            } label: {
                Label("1つ下へ移動", systemImage: "arrow.down")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("この習慣を削除", systemImage: "trash")
            }
        }
    }
}

// MARK: - 習慣新規追加モーダル（3ステップ・ウィザード形式：1.背景画像 ➔ 2.タイトル ➔ 3.曜日・時間・通知）
struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var habitManager = HabitManager.shared
    
    @State private var currentStep: Int = 1 // 1: 画像選択, 2: タイトル入力, 3: 曜日・時間・通知設定
    @State private var title: String = ""
    @State private var selectedImage: String = "Gemini_Generated_Image_1e3dfw1e3dfw1e3d"
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var targetTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notifyOption: Int = 10 // -1: OFF, 0: 定刻, 5: 5分前, 10: 10分前, 30: 30分前
    
    let weekdays = [
        (1, "日"), (2, "月"), (3, "火"), (4, "水"), (5, "木"), (6, "金"), (7, "土")
    ]
    
    let quickTitles = [
        "朝のコップ1杯の水",
        "バランスの良い朝食",
        "20分以上のウォーキング",
        "筋トレ・ワークアウト",
        "23時までの就寝・睡眠確保"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 上部プログレスインジケーター (STEP 1 / 2 / 3)
                stepHeaderView()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                Divider().background(Color(white: 0.15))
                
                // 各ステップのメインコンテンツ
                Group {
                    if currentStep == 1 {
                        step1ImageSelectionView()
                    } else if currentStep == 2 {
                        step2TitleInputView()
                    } else {
                        step3ScheduleView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider().background(Color(white: 0.15))
                
                // 下部ナビゲーションボタン（戻る / 次へ / 保存）
                bottomActionBar()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.04))
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("NEW HABIT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - ステップヘッダー
    private func stepHeaderView() -> some View {
        HStack(spacing: 8) {
            stepBadge(step: 1, label: "1. 背景画像")
            Rectangle().fill(Color(white: 0.2)).frame(height: 1)
            stepBadge(step: 2, label: "2. 習慣名")
            Rectangle().fill(Color(white: 0.2)).frame(height: 1)
            stepBadge(step: 3, label: "3. 時間・通知")
        }
    }
    
    private func stepBadge(step: Int, label: String) -> some View {
        let isActive = (currentStep == step)
        let isDone = (currentStep > step)
        return HStack(spacing: 4) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .black : (isDone ? .white : Color(white: 0.45)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.white : Color(white: 0.1))
        .cornerRadius(6)
    }
    
    // MARK: - STEP 1: 背景画像の選択（全30枚を大きなカードで一覧表示）
    private func step1ImageSelectionView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("SELECT CARD VISUAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
                Text("習慣カードの背景に設定するビジュアルを選択してください。")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
                
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(habitManager.presetImages, id: \.name) { item in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedImage = item.name
                        }) {
                            ZStack(alignment: .bottomLeading) {
                                GeometryReader { geo in
                                    if UIImage(named: item.name) != nil {
                                        Image(item.name)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.height)
                                            .clipped()
                                    } else {
                                        Color(white: 0.12)
                                    }
                                }
                                
                                LinearGradient(
                                    colors: [.clear, Color.black.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                HStack {
                                    Text(item.label)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedImage == item.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(8)
                            }
                            .frame(height: 82)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedImage == item.name ? Color.white : Color.white.opacity(0.12), lineWidth: selectedImage == item.name ? 2.5 : 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }
    
    // MARK: - STEP 2: 習慣タイトルの入力（選択した背景画像のライブプレビュー付き）
    private func step2TitleInputView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 選択中のカードプレビュー
                VStack(alignment: .leading, spacing: 8) {
                    Text("CARD PREVIEW")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                    
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            if UIImage(named: selectedImage) != nil {
                                Image(selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .overlay(Color.black.opacity(0.55))
                            } else {
                                Color(white: 0.1)
                            }
                        }
                        Text(title.isEmpty ? "習慣タイトルを入力..." : title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(title.isEmpty ? Color(white: 0.5) : .white)
                            .padding(.horizontal, 18)
                    }
                    .frame(height: 84)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // タイトル入力欄
                VStack(alignment: .leading, spacing: 8) {
                    Text("HABIT TITLE (習慣タイトル)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                    
                    TextField("例: 朝のストレッチ, 瞑想, 読書", text: $title)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color(white: 0.08))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
                
                // クイック候補チップ
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK PRESETS (タップで自動入力)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(white: 0.45))
                    
                    ForEach(quickTitles, id: \.self) { preset in
                        Button(action: {
                            HapticManager.shared.selection()
                            title = preset
                        }) {
                            HStack {
                                Text(preset)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.07))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - STEP 3: 曜日・実行時間・リマインド通知の設定
    private func step3ScheduleView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 曜日選択
                VStack(alignment: .leading, spacing: 10) {
                    Text("TARGET DAYS (実行する曜日)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                    
                    HStack(spacing: 8) {
                        ForEach(weekdays, id: \.0) { day, label in
                            let isSelected = selectedDays.contains(day)
                            Button(action: {
                                HapticManager.shared.selection()
                                if isSelected {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }) {
                                Text(label)
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .background(isSelected ? Color.white : Color(white: 0.1))
                                    .foregroundColor(isSelected ? .black : Color(white: 0.5))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 実行時刻
                VStack(alignment: .leading, spacing: 10) {
                    Text("SCHEDULE & REMINDER (実行時刻と通知)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                    
                    VStack(spacing: 14) {
                        DatePicker("実行時刻", selection: $targetTime, displayedComponents: .hourAndMinute)
                            .foregroundColor(.white)
                        
                        Divider().background(Color(white: 0.15))
                        
                        HStack {
                            Text("リマインド通知")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("リマインド通知", selection: $notifyOption) {
                                Text("通知オフ").tag(-1)
                                Text("定刻 (0分前)").tag(0)
                                Text("5分前").tag(5)
                                Text("10分前").tag(10)
                                Text("30分前").tag(30)
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.07))
                    .cornerRadius(12)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 下部アクションバー
    private func bottomActionBar() -> some View {
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button(action: {
                    HapticManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep -= 1
                    }
                }) {
                    Text("戻る")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 90)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.14))
                        .cornerRadius(10)
                }
            }
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                if currentStep < 3 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep += 1
                    }
                } else {
                    saveNewHabit()
                }
            }) {
                Text(currentStep < 3 ? "次へ進む" : "この習慣を保存する")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canProceed ? Color.white : Color(white: 0.25))
                    .cornerRadius(10)
            }
            .disabled(!canProceed)
        }
    }
    
    private var canProceed: Bool {
        if currentStep == 1 { return !selectedImage.isEmpty }
        if currentStep == 2 { return !title.trimmingCharacters(in: .whitespaces).isEmpty }
        return !selectedDays.isEmpty
    }
    
    private func saveNewHabit() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: targetTime)
        let newHabit = HabitItem(
            title: title.trimmingCharacters(in: .whitespaces),
            imageName: selectedImage,
            targetDaysOfWeek: Array(selectedDays).sorted(),
            notifyBeforeMinutes: notifyOption == -1 ? nil : notifyOption,
            targetHour: components.hour ?? 8,
            targetMinute: components.minute ?? 0
        )
        habitManager.addHabit(newHabit)
        dismiss()
    }
}

