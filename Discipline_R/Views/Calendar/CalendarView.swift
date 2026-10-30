import SwiftUI
import UIKit

struct CalendarView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @ObservedObject var habitManager = HabitManager.shared
    
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var activityRecords: [String: ActivityRecord] = [:]
    
    // スタンプ一覧のアコーディオン開閉状態（デフォルトは折りたたみ）
    @State private var isStampExpanded: Bool = false
    
    // 選択日のヘルスケア指標＆食事ログ（HealthKit）
    @State private var selectedDaySummary: DailyHealthSummary = DailyHealthSummary(dateString: "")
    @State private var dayMeals: [HealthMealRecord] = []
    @State private var isSyncingDayData: Bool = false
    
    private let storageKey = "discipline_activity_records"
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // 日曜始まり
        return cal
    }()
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    private let calendarColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let stampColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    private var selectedDateKey: String {
        dateKeyString(from: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. 月切替ヘッダー (< 2026 / 10 >)
                        HStack {
                            Button(action: {
                                HapticManager.shared.impact(style: .rigid)
                                changeMonth(by: -1)
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            
                            Spacer()
                            
                            Text(monthYearString(from: currentMonth))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .rigid)
                                changeMonth(by: 1)
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 2. 曜日ヘッダー (日〜土)
                        HStack(spacing: 6) {
                            ForEach(weekdays, id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 3. 月間カレンダーグリッド（デフォルトは何も表示せず、選択スタンプのアイコンのみ表示）
                        let monthDays = daysInCurrentMonth()
                        LazyVGrid(columns: calendarColumns, spacing: 8) {
                            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, dateOpt in
                                if let date = dateOpt {
                                    dayCell(for: date)
                                } else {
                                    Color.clear
                                        .frame(height: 58)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 4. STAMPS アコーディオンセクション（デフォルト折りたたみ・Habitとは完全別管理）
                        stampAccordionSection()
                        
                        // 5. DAY OVERVIEW（上部カレンダーで選択した日の各指標を表示）
                        dayDetailSection()
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    HapticManager.shared.impact(style: .rigid)
                    await loadDayDetailData(for: selectedDate)
                }
            }
            .navigationTitle("CALENDAR & STAMPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadRecords()
            healthKit.fetchHistoricalDailySummaries(days: 60)
        }
        .task(id: selectedDateKey) {
            await loadDayDetailData(for: selectedDate)
        }
    }
    
    // MARK: - カレンダー日付セル（デフォルトは数字のみ、スタンプ押下時のみアイコンを表示）
    private func dayCell(for date: Date) -> some View {
        let dateKey = dateKeyString(from: date)
        let record = activityRecords[dateKey]
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let activeIcons = getActiveIcons(for: record)
        
        return Button(action: {
            HapticManager.shared.impact(style: .rigid)
            selectedDate = date
        }) {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected ? .black : (isToday ? .bold : .medium), design: .monospaced))
                    .foregroundColor(isSelected ? .black : (isToday ? .white : .gray))
                    .frame(width: 26, height: 26)
                    .background(
                        Group {
                            if isSelected {
                                Circle().fill(Color.white)
                            } else if isToday {
                                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                            } else {
                                Color.clear
                            }
                        }
                    )
                
                stampIconsGrid(activeIcons: activeIcons, isSelected: isSelected)
                    .frame(height: 18, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.white.opacity(0.04))
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 日付セル内スタンプ表示（1〜3個は1段、4個以上は3×2の2段グリッド表示）
    @ViewBuilder
    private func stampIconsGrid(activeIcons: [String], isSelected: Bool) -> some View {
        let iconColor = isSelected ? Color.white : Color.white.opacity(0.85)
        if activeIcons.isEmpty {
            Color.clear
        } else if activeIcons.count <= 3 {
            HStack(spacing: 3) {
                ForEach(activeIcons, id: \.self) { iconName in
                    Image(systemName: iconName)
                        .font(.system(size: 7))
                        .foregroundColor(iconColor)
                        .frame(width: 9, height: 8)
                }
            }
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { col in
                        Image(systemName: activeIcons[col])
                            .font(.system(size: 7))
                            .foregroundColor(iconColor)
                            .frame(width: 9, height: 8)
                    }
                }
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { col in
                        let index = 3 + col
                        if index < activeIcons.count {
                            Image(systemName: activeIcons[index])
                                .font(.system(size: 7))
                                .foregroundColor(iconColor)
                                .frame(width: 9, height: 8)
                        } else {
                            Color.clear
                                .frame(width: 9, height: 8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - STAMPS アコーディオンセクション（Habitとは別管理）
    private func stampAccordionSection() -> some View {
        VStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.impact(style: .rigid)
                withAnimation(.easeInOut(duration: 0.25)) {
                    isStampExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("STAMPS (DAILY DISCIPLINE)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(isStampExpanded ? "閉じる" : "一覧を展開")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Image(systemName: isStampExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            
            if isStampExpanded {
                let currentRecord = activityRecords[selectedDateKey]
                
                LazyVGrid(columns: stampColumns, spacing: 10) {
                    stampButton(
                        label: "WORKOUT",
                        icon: "dumbbell.fill",
                        isPressed: currentRecord?.isWorkoutCompleted ?? false
                    ) {
                        toggleStamp(for: selectedDateKey) { $0.isWorkoutCompleted.toggle() }
                    }
                    
                    stampButton(
                        label: "RUNNING",
                        icon: "figure.run",
                        isPressed: currentRecord?.isRunningCompleted ?? false
                    ) {
                        toggleStamp(for: selectedDateKey) { $0.isRunningCompleted.toggle() }
                    }
                    
                    stampButton(
                        label: "READING",
                        icon: "book.fill",
                        isPressed: currentRecord?.isReadingCompleted ?? false
                    ) {
                        toggleStamp(for: selectedDateKey) { $0.isReadingCompleted.toggle() }
                    }
                    
                    stampButton(
                        label: "STUDY",
                        icon: "pencil.and.ruler.fill",
                        isPressed: currentRecord?.isStudyCompleted ?? false
                    ) {
                        toggleStamp(for: selectedDateKey) { $0.isStudyCompleted.toggle() }
                    }
                    
                    stampButton(
                        label: "HEALTH",
                        icon: "heart.fill",
                        isPressed: currentRecord?.isHealthCompleted ?? false
                    ) {
                        toggleStamp(for: selectedDateKey) { $0.isHealthCompleted.toggle() }
                    }
                    
                    stampButton(
                        label: "DISCIPLINE",
                        icon: "bolt.fill",
                        isPressed: currentRecord?.isDisciplineCompleted ?? false
                    ) {
                        toggleStamp(for: selectedDateKey) { $0.isDisciplineCompleted.toggle() }
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
        }
    }
    
    private func stampButton(label: String, icon: String, isPressed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(style: .rigid)
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isPressed ? Color.white : Color.white.opacity(0.06))
            .foregroundColor(isPressed ? .black : .white)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(isPressed ? 1.0 : 0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - DAY OVERVIEW（選択日の詳細ヘルスケア指標・PFC・食事ログ・完了習慣）
    private func dayDetailSection() -> some View {
        let liveSummary = calendar.isDateInToday(selectedDate) ? healthKit.summary(for: selectedDate) : selectedDaySummary
        let intake = Int(liveSummary.intakeCalories.rounded())
        let burned = Int(liveSummary.totalBurned.rounded())
        let net = intake - burned
        let pG = liveSummary.protein
        let fG = liveSummary.fat
        let cG = liveSummary.carbs
        let ratios = calculatePFCPercents(protein: pG, fat: fG, carbs: cG)
        let completedHabits = habitManager.habits.filter { $0.isCompleted(on: selectedDateKey) }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DAY OVERVIEW (\(selectedDateKey))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                if isSyncingDayData {
                    Text("SYNCING...")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            // ① カロリー収支 (消費 / 摂取 / NET BALANCE)
            HStack(spacing: 12) {
                metricBox(label: "消費 (BURNED)", value: "\(burned)", unit: "kcal", note: "HealthKit")
                metricBox(label: "摂取 (INTAKE)", value: "\(intake)", unit: "kcal", note: "HealthKit")
                metricBox(label: "NET BALANCE", value: formatSignedBalance(net), unit: "kcal", isHighlighted: net <= 0)
            }
            
            // ② 生体計測 (歩数 / 体重 / 体脂肪率)
            HStack(spacing: 12) {
                metricBox(
                    label: "歩数 (STEPS)",
                    value: "\(liveSummary.steps)",
                    unit: "歩",
                    note: "HealthKit"
                )
                
                metricBox(
                    label: "体重 (WEIGHT)",
                    value: liveSummary.weight > 0 ? String(format: "%.1f", liveSummary.weight) : "-",
                    unit: "kg",
                    note: "HealthKit"
                )
                
                metricBox(
                    label: "体脂肪率 (FAT)",
                    value: liveSummary.bodyFatPercentage > 0 ? String(format: "%.1f", liveSummary.bodyFatPercentage) : "-",
                    unit: "%",
                    note: "HealthKit"
                )
            }
            
            // ③ PFC BALANCE
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PFC BALANCE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Apple Health")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                HStack(spacing: 8) {
                    pfcMiniPill(label: "P", grams: pG, percent: ratios.p)
                    pfcMiniPill(label: "F", grams: fG, percent: ratios.f)
                    pfcMiniPill(label: "C", grams: cG, percent: ratios.c)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
            
            // ④ MEALS（選択日の食事記録一覧）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MEALS (\(dayMeals.count) 記録)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Apple Health")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                if dayMeals.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("この日の食事記録はありません")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.7))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(dayMeals) { meal in
                            HStack {
                                Text(meal.formattedTime)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.white)
                                    .cornerRadius(2)
                                
                                Text(meal.menuName)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(Int(meal.calories.rounded())) kcal")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
            
            // ⑤ COMPLETED HABITS（選択日に完了済みの習慣一覧・参照表示）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("COMPLETED HABITS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(completedHabits.count)/\(habitManager.habits.count) DONE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                if completedHabits.isEmpty {
                    Text("この日の完了した習慣はありません")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(completedHabits) { habit in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                Text(habit.title)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func metricBox(label: String, value: String, unit: String, note: String? = nil, isHighlighted: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)
            Text(verbatim: value)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(isHighlighted ? .white : .white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
            if let note = note {
                Text(note)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func pfcMiniPill(label: String, grams: Double, percent: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
            Text("\(Int(grams.rounded()))g")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(verbatim: "(\(percent)%)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(4)
    }
    
    // MARK: - 選択日のデータ読み込み（HealthKit）
    private func loadDayDetailData(for date: Date) async {
        await MainActor.run {
            self.isSyncingDayData = true
            self.selectedDaySummary = healthKit.summary(for: date)
        }
        
        if calendar.isDateInToday(date) {
            healthKit.fetchAllTodayData()
            let meals = await healthKit.fetchMealRecords(for: date)
            await MainActor.run {
                self.selectedDaySummary = healthKit.summary(for: date)
                self.dayMeals = meals
                self.isSyncingDayData = false
            }
        } else {
            async let summaryTask = healthKit.fetchDaySummary(for: date)
            async let mealsTask = healthKit.fetchMealRecords(for: date)
            let fetchedSummary = await summaryTask
            let fetchedMeals = await mealsTask
            await MainActor.run {
                self.selectedDaySummary = fetchedSummary
                self.dayMeals = fetchedMeals
                self.isSyncingDayData = false
            }
        }
    }
    
    // MARK: - スタンプのトグル＆永続化ロジック（Habitとは完全独立）
    private func toggleStamp(for dateKey: String, mutation: (inout ActivityRecord) -> Void) {
        var rec = activityRecords[dateKey] ?? ActivityRecord(dateString: dateKey)
        mutation(&rec)
        activityRecords[dateKey] = rec
        saveRecords()
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(activityRecords) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: ActivityRecord].self, from: data) {
            self.activityRecords = decoded
        } else {
            self.activityRecords = [:]
        }
    }
    
    private func getActiveIcons(for record: ActivityRecord?) -> [String] {
        guard let record = record else { return [] }
        var icons: [String] = []
        if record.isWorkoutCompleted { icons.append("dumbbell.fill") }
        if record.isRunningCompleted { icons.append("figure.run") }
        if record.isReadingCompleted { icons.append("book.fill") }
        if record.isStudyCompleted { icons.append("pencil.and.ruler.fill") }
        if record.isHealthCompleted { icons.append("heart.fill") }
        if record.isDisciplineCompleted { icons.append("bolt.fill") }
        return icons
    }
    
    // MARK: - カレンダー日付ヘルパー
    private func changeMonth(by amount: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: amount, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy / MM"
        return formatter.string(from: date)
    }
    
    private func dateKeyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func daysInCurrentMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let startOfMonth = monthInterval.start
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        let numberOfDays = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    private func calculatePFCPercents(protein: Double, fat: Double, carbs: Double) -> (p: Int, f: Int, c: Int) {
        let pCal = protein * 4.0
        let fCal = fat * 9.0
        let cCal = carbs * 4.0
        let total = pCal + fCal + cCal
        guard total > 0 else { return (0, 0, 0) }
        let pPct = Int((pCal / total * 100.0).rounded())
        let fPct = Int((fCal / total * 100.0).rounded())
        let cPct = max(0, 100 - pPct - fPct)
        return (pPct, fPct, cPct)
    }
    
    private func formatSignedBalance(_ balance: Int) -> String {
        if balance > 0 {
            return "+\(balance)"
        }
        return "\(balance)"
    }
}
