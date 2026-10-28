import WidgetKit
import SwiftUI

// MARK: - 週間カロリーウィジェット用 1日分データ構造体
struct WidgetDayCalorieItem: Codable {
    let dateString: String   // "yyyy-MM-dd"
    let weekdayLabel: String // "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"
    let dayNumber: Int       // 25, 26, ...
    let intake: Int          // 摂取カロリー (kcal)
    let burned: Int          // 消費カロリー (kcal)
    let isToday: Bool
    let isFuture: Bool
    
    var netBalance: Int { intake - burned }
    var hasData: Bool { !isFuture && (intake > 0 || burned > 0) }
}

// MARK: - App Group 共有データ構造体
struct DisciplineWidgetData {
    let days: [WidgetDayCalorieItem]
    
    var totalWeeklyIntake: Int {
        days.filter { $0.hasData }.reduce(0) { $0 + $1.intake }
    }
    
    var totalWeeklyBurned: Int {
        days.filter { $0.hasData }.reduce(0) { $0 + $1.burned }
    }
    
    var totalWeeklyNet: Int {
        totalWeeklyIntake - totalWeeklyBurned
    }
    
    static let appGroupIDs = [
        "group.com.lldkinn9.Discipline-R",
        "group.com.lldkinn9.DisciplineApp"
    ]
    
    static func loadFromSharedDefaults() -> DisciplineWidgetData {
        let todayStr = Self.dateString(for: Date())
        
        for groupID in appGroupIDs {
            if let defaults = UserDefaults(suiteName: groupID),
               let rawData = defaults.data(forKey: "widget_weekly_calories_v1"),
               let decoded = try? JSONDecoder().decode([WidgetDayCalorieItem].self, from: rawData),
               decoded.count == 7 {
                // 日付が変わっていた場合でも当日のハイライトを正確に更新
                let updated = decoded.map { item -> WidgetDayCalorieItem in
                    let isTodayNow = (item.dateString == todayStr)
                    let isFutureNow = (item.dateString > todayStr)
                    return WidgetDayCalorieItem(
                        dateString: item.dateString,
                        weekdayLabel: item.weekdayLabel,
                        dayNumber: item.dayNumber,
                        intake: item.intake,
                        burned: item.burned,
                        isToday: isTodayNow,
                        isFuture: isFutureNow
                    )
                }
                return DisciplineWidgetData(days: updated)
            }
        }
        return DisciplineWidgetData(days: generateFallbackCurrentWeek(withSampleData: false))
    }
    
    static func placeholderData() -> DisciplineWidgetData {
        return DisciplineWidgetData(days: generateFallbackCurrentWeek(withSampleData: true))
    }
    
    private static func dateString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    
    private static func generateFallbackCurrentWeek(withSampleData: Bool) -> [WidgetDayCalorieItem] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // 日曜始まり (SUN - SAT)
        let startOfToday = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: startOfToday)
        let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfToday) ?? startOfToday
        let labels = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let sampleIntakes = [1525, 1147, 1258, 1210, 0, 0, 0]
        let sampleBurned  = [2083, 2317, 2293, 1906, 0, 0, 0]
        
        return (0..<7).map { offset in
            let d = cal.date(byAdding: .day, value: offset, to: sunday) ?? startOfToday
            let isToday = cal.isDate(d, inSameDayAs: startOfToday)
            let isFuture = d > startOfToday
            let intake = (withSampleData && !isFuture) ? sampleIntakes[offset] : 0
            let burned = (withSampleData && !isFuture) ? sampleBurned[offset] : 0
            return WidgetDayCalorieItem(
                dateString: dateString(for: d),
                weekdayLabel: labels[offset],
                dayNumber: cal.component(.day, from: d),
                intake: intake,
                burned: burned,
                isToday: isToday,
                isFuture: isFuture
            )
        }
    }
}

struct DisciplineEntry: TimelineEntry {
    let date: Date
    let data: DisciplineWidgetData
}

struct DisciplineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DisciplineEntry {
        DisciplineEntry(date: Date(), data: DisciplineWidgetData.placeholderData())
    }

    func getSnapshot(in context: Context, completion: @escaping (DisciplineEntry) -> ()) {
        let data = context.isPreview ? DisciplineWidgetData.placeholderData() : DisciplineWidgetData.loadFromSharedDefaults()
        completion(DisciplineEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentData = DisciplineWidgetData.loadFromSharedDefaults()
        let entry = DisciplineEntry(date: Date(), data: currentData)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View (Medium横長専用・日曜〜土曜 週間カロリー収支＆棒グラフUI)
struct DisciplineWidgetEntryView : View {
    var entry: DisciplineProvider.Entry

    private var maxCalorieInWeek: Double {
        let highest = entry.data.days.map { max($0.intake, $0.burned) }.max() ?? 2500
        return max(Double(highest), 2400.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 上段ヘッダー：左にタイトル、右に週間合計ピル (IN / OUT / NET)
            headerBar
            
            // 下段：日曜(SUN)〜土曜(SAT) の7カラムカード
            HStack(spacing: 4) {
                ForEach(Array(entry.data.days.enumerated()), id: \.offset) { _, day in
                    dayColumnCard(for: day)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .widgetBlackBackground()
    }
    
    // MARK: - 上段ヘッダー
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("DISCIPLINE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(.white)
                Text("WEEKLY CALORIES")
                    .font(.system(size: 6.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color(white: 0.48))
            }
            
            Spacer(minLength: 4)
            
            // 右側：週間合計 IN / OUT / NET カプセル
            HStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 2.5) {
                    Text("IN")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                    Text(formatNumber(entry.data.totalWeeklyIntake))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 2.5) {
                    Text("OUT")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                    Text(formatNumber(entry.data.totalWeeklyBurned))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.65))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 2.5) {
                    Text("NET")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                    Text(formatNet(entry.data.totalWeeklyNet, showZeroAsZero: true))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.88))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.08))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - 各曜日の縦長カード (SUN ~ SAT)
    private func dayColumnCard(for day: WidgetDayCalorieItem) -> some View {
        let maxCal = maxCalorieInWeek
        let barAreaHeight: CGFloat = 32.0
        let inHeight: CGFloat = day.hasData
            ? max(3.0, CGFloat(Double(day.intake) / maxCal) * barAreaHeight)
            : 2.5
        let outHeight: CGFloat = day.hasData
            ? max(3.0, CGFloat(Double(day.burned) / maxCal) * barAreaHeight)
            : 2.5
        
        return VStack(spacing: 0) {
            // 1. 曜日＆日付ヘッダー（当日は白塗りバッジ＋黒文字）
            VStack(spacing: 0.5) {
                Text(day.weekdayLabel)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(
                        day.isToday ? .black : (day.isFuture ? Color(white: 0.38) : .white)
                    )
                Text("\(day.dayNumber)")
                    .font(.system(size: 7.5, weight: day.isToday ? .bold : .medium, design: .monospaced))
                    .foregroundColor(
                        day.isToday ? .black : Color(white: 0.42)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4.5)
                    .fill(day.isToday ? Color.white : Color.clear)
            )
            .padding(.horizontal, 2)
            .padding(.top, 2)
            
            Spacer(minLength: 2)
            
            // 2. 中央：摂取(白) vs 消費(グレー) の2本縦棒グラフ
            HStack(alignment: .bottom, spacing: 2.5) {
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(day.hasData ? Color.white : Color(white: 0.75))
                    .frame(width: 3.2, height: inHeight)
                
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(Color(white: 0.38))
                    .frame(width: 3.2, height: outHeight)
            }
            .frame(height: barAreaHeight, alignment: .bottom)
            .padding(.bottom, 4)
            
            // 3. 下段：3行数値（摂取 / 消費 / 収支）
            VStack(spacing: 1) {
                Text(day.hasData ? formatNumber(day.intake) : "-")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(day.hasData ? .white : Color(white: 0.28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text(day.hasData ? formatNumber(day.burned) : "-")
                    .font(.system(size: 6.5, weight: .regular, design: .monospaced))
                    .foregroundColor(day.hasData ? Color(white: 0.52) : Color(white: 0.25))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text(day.hasData ? formatNet(day.netBalance, showZeroAsZero: false) : "-")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(day.hasData ? .white : Color(white: 0.28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(day.isToday ? Color(white: 0.08) : Color(white: 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    day.isToday ? Color.white.opacity(0.45) : Color.white.opacity(0.08),
                    lineWidth: day.isToday ? 0.9 : 0.5
                )
        )
    }
    
    private func formatNumber(_ val: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: val)) ?? "\(val)"
    }
    
    private func formatNet(_ val: Int, showZeroAsZero: Bool) -> String {
        if val > 0 {
            return "+\(val)"
        } else if val == 0 {
            return showZeroAsZero ? "0" : "0"
        } else {
            return "\(val)"
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBlackBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            self.containerBackground(Color.black, for: .widget)
        } else {
            self.background(Color.black)
        }
    }
}

@main
struct DisciplineWidget: Widget {
    let kind: String = "DisciplineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DisciplineProvider()) { entry in
            DisciplineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Discipline Weekly Calories")
        .description("日曜〜土曜の週間カロリー収支（摂取・消費・差分）と棒グラフを表示します。")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}

extension WidgetConfiguration {
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}
