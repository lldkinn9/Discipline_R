import SwiftUI
import UIKit

struct HabitTrackerSection: View {
    @ObservedObject var habitManager = HabitManager.shared
    @State private var showingAddHabit = false
    @State private var isEditing = false
    @State private var draftHabits: [HabitItem] = []
    
    private var displayedHabits: [HabitItem] {
        isEditing ? draftHabits : habitManager.habits
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // ヘッダー: HABIT TRACKER + 「＋」ボタン + 「編集 / 完了」ボタン（個人版アプリ準拠）
            HStack(alignment: .center) {
                Text(isEditing ? "HABIT TRACKER (並び替え / 削除)" : "HABIT TRACKER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isEditing ? .yellow : .gray)
                
                Spacer()
                
                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        if isEditing { cancelEditing() }
                        showingAddHabit = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                    }
                    
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if isEditing {
                                habitManager.updateAllHabits(draftHabits)
                                isEditing = false
                                draftHabits = []
                            } else {
                                draftHabits = habitManager.habits
                                isEditing = true
                            }
                        }
                    }) {
                        Text(isEditing ? "完了" : "編集")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isEditing ? .yellow : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // 習慣カード一覧 (21:9 アスペクト比)
            if displayedHabits.isEmpty {
                emptyStateView()
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(displayedHabits.enumerated()), id: \.element.id) { index, habit in
                        habitCard(habit: habit, index: index)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? Color.yellow.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 1)
        )
        .sheet(isPresented: $showingAddHabit) {
            AddHabitSheet()
        }
        .onDisappear {
            cancelEditing()
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
            draftHabits = []
        }
    }
    
    // MARK: - 21:9 習慣カード（個人版アプリ準拠：タップ完了で暗転＆左側に28日ミニヒートマップ表示、編集モードで削除＆上下移動）
    private func habitCard(habit: HabitItem, index: Int) -> some View {
        let isDone = habit.isCompletedToday
        let hasCustomDays = !habit.targetDaysOfWeek.isEmpty && habit.targetDaysOfWeek.count < 7
        let hasTime = (habit.targetHour != nil && habit.targetMinute != nil)
        
        return ZStack(alignment: .bottomTrailing) {
            GeometryReader { geo in
                ZStack {
                    if UIImage(named: habit.imageName) != nil {
                        Image(habit.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [Color(white: 0.2), Color(white: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "photo")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    
                    // 完了時暗転レイヤー
                    Color.black
                        .opacity(isDone ? 0.75 : 0.0)
                        .animation(.easeInOut(duration: 0.25), value: isDone)
                    
                    // 完了時：左側に28日ミニヒートマップ (RECORD (28D) X/28)
                    if isDone && !isEditing {
                        VStack {
                            Spacer()
                            HStack {
                                HabitMiniHeatmapView(habit: habit)
                                    .padding(.leading, 16)
                                Spacer(minLength: 0)
                            }
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                    
                    // 編集モード時の半透明オーバーレイ
                    if isEditing {
                        Color.black.opacity(0.32)
                    }
                }
            }
            .aspectRatio(21.0 / 9.0, contentMode: .fit)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    HapticManager.shared.impact(style: .rigid)
                    habitManager.toggleCompletion(for: habit.id)
                }
            }
            
            // 右下に習慣タイトル（および任意設定されている場合のみ曜日・時刻）を表示
            VStack(alignment: .trailing, spacing: 3) {
                if (hasCustomDays || hasTime) && !isEditing {
                    HStack(spacing: 6) {
                        if hasCustomDays {
                            Text(formattedWeekdays(habit.targetDaysOfWeek))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        if let hour = habit.targetHour, let minute = habit.targetMinute {
                            Text(String(format: "%02d:%02d", hour, minute))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                }
                
                Text(habit.title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
            }
            .padding(12)
            
            // 編集モード時の操作UI（左上: 削除 / 右側: 上下移動・並び替えピル）
            if isEditing {
                ZStack {
                    // 左上: 削除ボタン
                    VStack {
                        HStack {
                            Button(action: {
                                HapticManager.shared.impact(style: .rigid)
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                                    draftHabits.removeAll { $0.id == habit.id }
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.red)
                                    .background(Circle().fill(Color.white))
                                    .padding(8)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    
                    // 右側: 安定した並び替えピル（▲ / 順番番号 / ▼）
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Button(action: {
                                if index > 0 {
                                    HapticManager.shared.impact(style: .rigid)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        draftHabits.swapAt(index, index - 1)
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(index > 0 ? .white : .gray.opacity(0.25))
                                    .frame(width: 32, height: 26)
                                    .background(Color.white.opacity(index > 0 ? 0.2 : 0.05))
                                    .cornerRadius(4)
                            }
                            .disabled(index == 0)
                            
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(height: 14)
                            
                            Button(action: {
                                if index < draftHabits.count - 1 {
                                    HapticManager.shared.impact(style: .rigid)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        draftHabits.swapAt(index, index + 1)
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(index < draftHabits.count - 1 ? .white : .gray.opacity(0.25))
                                    .frame(width: 32, height: 26)
                                    .background(Color.white.opacity(index < draftHabits.count - 1 ? 0.2 : 0.05))
                                    .cornerRadius(4)
                            }
                            .disabled(index >= draftHabits.count - 1)
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                        )
                        .padding(.trailing, 10)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDone ? Color.white.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func emptyStateView() -> some View {
        VStack(spacing: 8) {
            Text("登録された習慣がありません")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
            Button(action: {
                HapticManager.shared.impact(style: .light)
                showingAddHabit = true
            }) {
                Text("＋ 最初の習慣を登録する")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private func formattedWeekdays(_ days: [Int]) -> String {
        let map: [Int: String] = [
            1: "日", 2: "月", 3: "火", 4: "水", 5: "木", 6: "金", 7: "土"
        ]
        return days.sorted().compactMap { map[$0] }.joined(separator: "・")
    }
}

// MARK: - 習慣単体の28日ミニヒートマップ（完了カード左側に表示）
struct HabitMiniHeatmapView: View {
    let habit: HabitItem
    private let squareSize: CGFloat = 17
    private let spacing: CGFloat = 3.5
    private let gridWidth: CGFloat = 140
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(squareSize), spacing: spacing), count: 7)
    }
    
    var body: some View {
        let days = last28Days()
        let count = habit.completedDates.filter { Set(days).contains($0) }.count
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("RECORD (28D)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(count)/28")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
            
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(days, id: \.self) { dateStr in
                    let isCompleted = habit.isCompleted(on: dateStr)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(isCompleted ? Color.white : Color.white.opacity(0.2))
                        .frame(width: squareSize, height: squareSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2.5)
                                .stroke(Color.white.opacity(isCompleted ? 0.0 : 0.25), lineWidth: 0.5)
                        )
                }
            }
            .frame(width: gridWidth, alignment: .leading)
        }
        .frame(width: gridWidth, alignment: .leading)
    }
    
    private func last28Days() -> [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        return (0..<28).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return formatter.string(from: date)
        }
    }
}

// MARK: - 習慣新規追加モーダル（3ステップ・ウィザード形式：1.背景画像 ➔ 2.タイトル ➔ 3.曜日・時間・通知）
struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var habitManager = HabitManager.shared
    
    @State private var currentStep: Int = 1 // 1: 画像選択, 2: タイトル入力, 3: 曜日・時間・通知設定
    @State private var title: String = ""
    @State private var selectedImage: String = HabitManager.shared.presetImages.first ?? "Gemini_Generated_Image_1e3dfw1e3dfw1e3d"
    @State private var selectedDays: Set<Int> = [] // 未選択（空）でもそのまま登録可能
    @State private var hasTargetTime: Bool = false // 実行時刻を設定しないことも可能
    @State private var targetTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notifyOption: Int = -1 // 標準表示は「通知オフ」(-1: OFF, 0: 定刻, 5: 5分前, 10: 10分前, 30: 30分前)
    
    let weekdays = [
        (1, "日"), (2, "月"), (3, "火"), (4, "水"), (5, "木"), (6, "金"), (7, "土")
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
    
    // MARK: - STEP 1: 背景画像の選択（重複のないビジュアルカードを文字ラベルなしで一覧表示）
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
                    ForEach(habitManager.presetImages, id: \.self) { imageName in
                        Button(action: {
                            HapticManager.shared.selection()
                            selectedImage = imageName
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                GeometryReader { geo in
                                    if UIImage(named: imageName) != nil {
                                        Image(imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.height)
                                            .clipped()
                                    } else {
                                        Color(white: 0.12)
                                    }
                                }
                                
                                if selectedImage == imageName {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.65))
                                                .frame(width: 16, height: 16)
                                        )
                                        .padding(8)
                                }
                            }
                            .frame(height: 82)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedImage == imageName ? Color.white : Color.white.opacity(0.12), lineWidth: selectedImage == imageName ? 2.5 : 1)
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
                    
                    ZStack(alignment: .bottomTrailing) {
                        GeometryReader { geo in
                            if UIImage(named: selectedImage) != nil {
                                Image(selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            } else {
                                Color(white: 0.1)
                            }
                        }
                        .aspectRatio(21.0 / 9.0, contentMode: .fit)
                        
                        Text(title.isEmpty ? "HABIT TITLE" : title)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(title.isEmpty ? Color(white: 0.6) : .white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                            .padding(12)
                    }
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
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
            }
            .padding(20)
        }
    }
    
    // MARK: - STEP 3: 曜日・実行時間・リマインド通知の設定（すべて任意設定対応）
    private func step3ScheduleView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 曜日選択（0個でも登録可能）
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TARGET DAYS (実行する曜日・任意)")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(white: 0.5))
                        Spacer()
                        Button(action: {
                            HapticManager.shared.selection()
                            if selectedDays.count == 7 {
                                selectedDays.removeAll()
                            } else {
                                selectedDays = Set(1...7)
                            }
                        }) {
                            Text(selectedDays.count == 7 ? "選択解除" : "すべて選択")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(white: 0.65))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(white: 0.12))
                                .cornerRadius(5)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
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
                    
                    Text("※曜日を選択しなくてもそのまま登録できます（曜日指定なし）")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.42))
                }
                
                // 実行時刻とリマインド通知（任意）
                VStack(alignment: .leading, spacing: 10) {
                    Text("SCHEDULE & REMINDER (実行時刻と通知・任意)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(white: 0.5))
                    
                    VStack(spacing: 14) {
                        Toggle(isOn: $hasTargetTime.animation(.easeInOut(duration: 0.2))) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("実行時刻を設定する")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                Text(hasTargetTime ? "指定した時刻をカードに表示します" : "未設定（時刻指定なし）")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                        .tint(.white)
                        .onChange(of: hasTargetTime) { enabled in
                            if !enabled {
                                notifyOption = -1
                            }
                        }
                        
                        if hasTargetTime {
                            Divider().background(Color(white: 0.15))
                            
                            DatePicker("実行時刻", selection: $targetTime, displayedComponents: .hourAndMinute)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        
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
                            .onChange(of: notifyOption) { newValue in
                                if newValue != -1 && !hasTargetTime {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hasTargetTime = true
                                    }
                                }
                            }
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
        return true // STEP 3 は曜日未選択・時刻未設定・通知オフでも保存可能
    }
    
    private func saveNewHabit() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: targetTime)
        let activeNotify: Int? = (hasTargetTime && notifyOption != -1) ? notifyOption : nil
        let newHabit = HabitItem(
            title: title.trimmingCharacters(in: .whitespaces),
            imageName: selectedImage,
            targetDaysOfWeek: Array(selectedDays).sorted(),
            notifyBeforeMinutes: activeNotify,
            targetHour: hasTargetTime ? (components.hour ?? 8) : nil,
            targetMinute: hasTargetTime ? (components.minute ?? 0) : nil
        )
        habitManager.addHabit(newHabit)
        dismiss()
    }
}

